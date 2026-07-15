# Stump Phase 1 Evaluation

Stump is running in parallel with Komf, Komga, and Grimmory. The existing applications remain authoritative throughout this evaluation.

## Prerequisites

- [ ] Create an Authentik OAuth2/OpenID Provider and application named `stump`.
- [ ] Set the redirect URI to `https://stump.local.solonsstuff.com/api/v2/auth/oidc/callback`.
- [ ] Allow the `openid`, `email`, and `profile` scopes.
- [ ] Create a 1Password item named `stump` with `CLIENT_ID` and `CLIENT_SECRET` fields from Authentik.
- [ ] Confirm the cluster context before running any live command with `kubectl config current-context`.

## Deployment

- [ ] Reconcile the source with `flux reconcile source git flux-system`.
- [ ] Reconcile Stump with `flux reconcile kustomization stump --with-source`.
- [ ] Confirm readiness with `flux get kustomization stump`.
- [ ] Confirm the pod is running with `kubectl -n books get pods -l app.kubernetes.io/name=stump`.
- [ ] Confirm the route responds with `curl.exe -I https://stump.local.solonsstuff.com`.

## Bootstrap And Authentication

- [ ] Open `https://stump.local.solonsstuff.com` and create the local administrator.
- [ ] Confirm the local administrator owns the server before enabling OIDC registration.
- [ ] Change `STUMP_OIDC_ALLOW_REGISTRATION` to `"true"` in `kubernetes/books/stump/app/release.yaml`, publish the Git change, and reconcile Stump.
- [ ] Sign out and sign in through Authentik.
- [ ] Sign out and verify the local administrator can still sign in.
- [ ] Set a local password on the OIDC test account if that account will be used for OPDS.

## Libraries

- [ ] Create a `Books` library rooted at `/data/books`.
- [ ] Create a `Manga` library rooted at `/data/manga`.
- [ ] Complete an initial scan of both libraries.
- [ ] Confirm the Stump pod mounts both libraries read-only with `kubectl -n books get pod -l app.kubernetes.io/name=stump -o yaml`.
- [ ] Record the initial scan duration and peak memory from the Stump UI and cluster metrics.

## Format Checks

- [ ] Open one existing EPUB book and navigate between chapters.
- [ ] Open one existing PDF and render pages near the start and end.
- [ ] Open one existing CBZ manga volume and navigate between pages.
- [ ] Open one existing CBR manga volume and navigate between pages.
- [ ] Confirm no source file timestamp or content changed during the checks.

## Metadata Checks

- [ ] Configure the Stump metadata providers that are available in version 0.1.5.
- [ ] Fetch metadata for one ebook with known embedded metadata.
- [ ] Fetch metadata for one manga series previously enriched by Komf.
- [ ] Record which providers worked, which fields changed, and whether results are acceptable.
- [ ] Do not require MangaUpdates parity; Stump does not support that provider.

## OPDS Checks

- [ ] Configure an OPDS-capable client with the Stump OPDS feed shown in the Stump UI.
- [ ] Authenticate with a local username and password.
- [ ] Browse both libraries and download one book without changing the Kindle OPDS proxy.
- [ ] Record the exact validated Stump OPDS feed URL for the Phase 2 plan.

## Backup Checks

- [ ] Confirm `kubectl -n books get replicationsource stump` reports a configured source.
- [ ] Trigger the first manual backup with `kubectl -n books patch replicationsource stump --type merge --patch '{"spec":{"trigger":{"manual":"phase-1-evaluation"}}}'`.
- [ ] Confirm the replication completes with `kubectl -n books describe replicationsource stump`.
- [ ] Do not resume the `volsync-restores` Flux Kustomization during this check.

## State Feasibility

- [ ] Work only from API exports, filesystem copies, or restored copies of Komga and Grimmory databases.
- [ ] Record whether each application exposes users, reading progress, favorites, and metadata through a documented API or export.
- [ ] Record stable source identifiers and matching Stump identifiers for each transferable entity.
- [ ] Reject conversion paths that require writes to a live source database or unverifiable writes to Stump.
- [ ] Decide separately whether users, progress, favorites, and metadata are transferable.

## Rollback

If Stump fails evaluation, suspend reconciliation, stop the workload, and remove its route while preserving its PVC and backup resources:

```bash
flux suspend kustomization stump
flux suspend helmrelease stump -n books
kubectl -n books scale deployment stump --replicas=0
kubectl -n books delete httproute stump
```

Confirm the deployment has zero replicas and the route is absent with `kubectl -n books get deployment stump` and `kubectl -n books get httproute stump`. Komf, Komga, Grimmory, Shelfmark, the Kindle OPDS proxy, and Homepage require no rollback because Phase 1 does not modify them. Do not delete the Stump PVC, ReplicationSource, restic Secret, or Garage repository; retain them for investigation or a later retry.

## Phase 2 Gate

Phase 2 planning may start only after all applicable format, authentication, metadata, OPDS, and backup checks pass and the state feasibility findings are recorded. Shelfmark, OPDS proxy, Homepage, and old-workload retirement changes must be designed from the exact endpoints and behavior verified here.
