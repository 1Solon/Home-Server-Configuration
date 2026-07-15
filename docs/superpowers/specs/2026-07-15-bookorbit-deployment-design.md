# BookOrbit Deployment Replacement Design

## Goal

Replace the Stump evaluation deployment with BookOrbit while preserving the existing books ecosystem. BookOrbit will run as an internal-only Kubernetes workload, use the existing highly available PostgreSQL infrastructure, mount the books and manga NAS shares with write access, persist app-managed state with VolSync protection, and support local administration plus Authentik OIDC.

## Decisions

- Deploy BookOrbit 2.2.0 with every container image pinned to an immutable digest.
- Publish `https://bookorbit.${LOCAL_DOMAIN}` through `envoy-internal` only.
- Use the existing `pgvector17-rw.databases.svc.cluster.local` PostgreSQL 17 cluster with a dedicated `bookorbit` database and role.
- Mount both NAS libraries writable.
- Remove all Stump manifests, its restore entry, and its obsolete evaluation document.
- Do not migrate Stump application state.
- Leave Grimmory, Komga, Komf, Shelfmark, and OPDS Proxy unchanged.
- Retain old Stump Garage backup objects as unmanaged archival data; do not actively delete them.

## Architecture

The deployment follows the existing books-domain pattern:

- `kubernetes/books/bookorbit/install.yaml`: Flux `Kustomization`, VolSync component wiring, substitutions, reconciliation settings, and backup schedule.
- `kubernetes/books/bookorbit/app/kustomization.yaml`: assembles the app resources.
- `kubernetes/books/bookorbit/app/release.yaml`: bjw-s `app-template` HelmRelease for the application, initialization containers, service, route, probes, resources, security contexts, and persistence.
- `kubernetes/books/bookorbit/app/externalsecret.yaml`: renders app and database-init credentials from 1Password.
- `kubernetes/books/bookorbit/app/pvc.yaml`: defines the app-data PVC.

`kubernetes/books/kustomization.yaml` will reference BookOrbit instead of Stump. The HelmRelease uses the repository's current `app-template` chart version `5.0.1`.

## Database Initialization

BookOrbit uses the shared `pgvector17` CloudNativePG cluster rather than a bundled PostgreSQL sidecar or a new cluster. This provides existing HA, monitoring, and database backup behavior without adding an app-scoped database lifecycle.

Initialization is sequential and idempotent:

1. A pinned `ghcr.io/home-operations/postgres-init` init container creates the `bookorbit` role and database if absent.
2. A pinned PostgreSQL client init container connects as the existing CloudNativePG superuser and runs:
   - `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
   - `CREATE EXTENSION IF NOT EXISTS pg_trgm;`
   - `CREATE EXTENSION IF NOT EXISTS unaccent;`
   - `CREATE EXTENSION IF NOT EXISTS vector;`
3. BookOrbit starts only after both initialization containers succeed.
4. BookOrbit runs its own schema migrations from its upstream entrypoint.

Database or extension initialization failure blocks application startup. No fallback database is configured.

## Secrets

A new 1Password item named `bookorbit` must contain:

- `BOOKORBIT_POSTGRES_PASSWORD`
- `BOOKORBIT_JWT_SECRET`
- `BOOKORBIT_SETUP_BOOTSTRAP_TOKEN`

The ExternalSecret also extracts the existing `cloudnative-pg` item for database-superuser initialization. The generated Kubernetes Secret supplies:

- BookOrbit database host, port, user, database, and password.
- `JWT_SECRET` and `SETUP_BOOTSTRAP_TOKEN`.
- `INIT_POSTGRES_DBNAME`, `INIT_POSTGRES_HOST`, `INIT_POSTGRES_USER`, and `INIT_POSTGRES_PASS` for database creation.
- Existing CloudNativePG superuser credentials for database and extension initialization.

Secrets remain in 1Password and the generated Kubernetes Secret; no credential values are committed.

## Runtime Configuration

The BookOrbit container uses:

- `APP_URL=https://bookorbit.${LOCAL_DOMAIN}`
- `CLIENT_URL=https://bookorbit.${LOCAL_DOMAIN}`
- `PORT=3000`
- `POSTGRES_HOST=pgvector17-rw.databases.svc.cluster.local`
- `POSTGRES_PORT=5432`
- `POSTGRES_USER=bookorbit`
- `POSTGRES_DB=bookorbit`
- `PUID=1000`
- `PGID=1000`
- `BOOKORBIT_FIX_PERMISSIONS=false`
- `NODE_MAX_OLD_SPACE_SIZE=auto`
- `LIBRARY_BROWSE_ROOT=/libraries`
- `BOOK_DOCK_PATH=/data/book-dock`
- cluster `TZ`

The pod runs as UID/GID `1000:1000` with `fsGroup: 1000`, a runtime-default seccomp profile, no privilege escalation, all Linux capabilities dropped, and a read-only root filesystem. Disabling BookOrbit's ownership repair is intentional: Kubernetes owns the writable PVC through `fsGroup`, so the upstream root-and-capability startup path is unnecessary.

The application exposes port 3000. Startup, readiness, and liveness probes call `/api/v1/health`. Resource sizing starts at:

- Requests: `100m` CPU and `1Gi` memory.
- Limits: `2Gi` memory.

The container-aware Node heap remains within the memory limit.

## Storage

- `bookorbit` PVC: `10Gi`, `ReadWriteOnce`, `ceph-block`, mounted at `/data`.
- `tmp` `emptyDir`: mounted at `/tmp`.
- Books NFS export: `/mnt/STORAGE-01/Media-Storage/books`, mounted writable at `/libraries/books`.
- Manga NFS export: `/mnt/STORAGE-01/Media-Storage/manga`, mounted writable at `/libraries/manga`.

BookOrbit may upload, rename, write metadata, and finalize Book Dock imports in these libraries. The folder picker is restricted to `/libraries` so other container paths are not offered as library roots.

The Flux Kustomization uses the existing VolSync component with:

- Repository: `s3:http://garage.garage.svc.cluster.local:3900/volsync/books/bookorbit`
- Source PVC: `bookorbit`
- Schedule: `37 */6 * * *`

PostgreSQL data remains protected by the shared CloudNativePG backup configuration rather than VolSync.

## Routing and Authentication

The app-template route attaches to `networking/envoy-internal`, section `https`, with hostname `bookorbit.${LOCAL_DOMAIN}`. This hostname is also the canonical BookOrbit URL.

Initial setup uses the setup bootstrap token to create a local administrator. After bootstrap:

1. Create an Authentik OAuth2/OpenID provider and application named `bookorbit`.
2. Register `https://bookorbit.${LOCAL_DOMAIN}/oauth2-callback` as the exact redirect URI.
3. Allow `openid profile email` scopes.
4. In BookOrbit, add and test the Authentik provider under **Settings → OIDC / SSO**.
5. Enable automatic user provisioning and local account linking.
6. Retain the local administrator as a recovery login.

The old Authentik `stump` application/provider and 1Password `stump` item are deleted manually only after BookOrbit OIDC and local login are verified. They are not repository-managed resources.

## Stump Retirement

The cutover removes:

- `kubernetes/books/stump/` and all contained resources.
- The Stump `ReplicationDestination` and restore PVC block from `kubernetes/storage/volsync/restores/app/restores.yaml`.
- `docs/stump-phase-1-evaluation.md`.
- The Stump entry from `kubernetes/books/kustomization.yaml`.

Flux pruning retires Stump's in-cluster HelmRelease, route, PVC, ExternalSecret-generated Secret, and VolSync resources after the parent configuration changes. Old Garage repository objects are not actively removed.

No Stump users, progress, favorites, metadata, or configuration are migrated. BookOrbit builds fresh application state by scanning the existing NAS libraries. BookOrbit's supported Grimmory migration workflow is outside this replacement and may be evaluated separately after the deployment is stable.

## Failure Handling

- ExternalSecret failure prevents required credentials from reaching initialization or the app.
- Database-role/database creation failure blocks the first init container.
- Missing PostgreSQL extension support or extension creation failure blocks the second init container.
- BookOrbit migration or startup failure prevents readiness.
- Failed Helm installs retry three times; failed upgrades clean up and roll back according to the existing app-template release convention.
- Health probe failures keep the service from routing traffic to an unhealthy pod.
- No partial fallback, embedded database, or alternate hostname is provided.

## Validation

### Repository validation

- Render `kubernetes/books/bookorbit/app` with Kustomize.
- Render `kubernetes/books` with Kustomize.
- Render or validate the HelmRelease values against the pinned bjw-s `app-template` chart.
- Confirm all container images include immutable digests.
- Confirm no Stump references remain under `kubernetes/` or `docs/`.

### Post-reconcile smoke test

1. Confirm both database init containers complete and the BookOrbit pod becomes Ready.
2. Require a successful response from `https://bookorbit.${LOCAL_DOMAIN}/api/v1/health`.
3. Complete bootstrap with the setup token and create the local administrator.
4. Add `/libraries/books` and `/libraries/manga` and complete initial scans.
5. Open representative EPUB, PDF, and CBZ files.
6. Perform one controlled upload or metadata write to prove NAS write access.
7. Configure Authentik and verify both OIDC login and retained local-admin login.
8. Trigger and verify one VolSync replication.
9. Confirm Stump workload, route, PVC, Secret, VolSync, and restore objects are absent.

## Operator Prerequisites

Before reconciliation:

- Create the `bookorbit` 1Password item with the three required fields.
- Confirm the NAS exports permit UID/GID `1000:1000` to write.
- Confirm the shared `pgvector17` image exposes the four required extension control files.

Before enabling OIDC:

- Create the Authentik provider/application with the exact callback URI.

## Upstream References

- BookOrbit repository and release: https://github.com/bookorbit/bookorbit
- Installation and environment contract: https://bookorbit.app/installation/
- OIDC setup and callback contract: https://bookorbit.app/oidc/
- Migration capabilities and supported sources: https://bookorbit.app/migration/
