# Hermes Deployment Cleanup Design

## Goal

Modernize the Hermes Kubernetes deployment around capabilities already present in `nousresearch/hermes-agent:v2026.7.20`, while preserving its intended power-user features, integrations, persistent state, internal endpoints, and cluster-wide read-only diagnostics.

The cleanup should make the deployment easier to understand and maintain, remove obsolete plumbing, eliminate known startup noise and races, and retain a straightforward Git rollback path.

## Current-State Findings

The live deployment is healthy: Flux and the HelmRelease are ready, the pod has no restarts, and observed combined usage is approximately 7m CPU and 522 MiB memory. The audit nevertheless found several maintenance issues:

- The pod runs separate gateway and dashboard containers even though the image now includes static S6 services for both and can enable the supervised dashboard with `HERMES_DASHBOARD` ([Dockerfile](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/Dockerfile#L254-L263), [dashboard run script](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/docker/s6-rc.d/dashboard/run#L1-L28)).
- The dashboard's cross-container health polling repeatedly attempts the authenticated detailed-health endpoint without an API key. Upstream marks `GATEWAY_HEALTH_URL` as deprecated and always tries `/health/detailed` before `/health` ([web_server.py](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/hermes_cli/web_server.py#L1374-L1417)).
- Both application containers migrate the same freshly copied schema-v0 config at startup, creating duplicate migrations and persistent backups.
- The top-level `toolsets` key is deprecated and ignored; tool selection now belongs under `platform_toolsets` ([cli-config.yaml.example](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/cli-config.yaml.example#L949-L955)). The current config also names `mcp-grafana` as a toolset even though it is an MCP server.
- A Firecrawl init container installs dependencies into an ephemeral `PYTHONPATH` target. The image now supports optional dependencies in a durable, append-only package target under `/opt/data/lazy-packages`, specifically to avoid shadowing core packages ([Dockerfile](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/Dockerfile#L296-L311), [lazy_deps.py](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/tools/lazy_deps.py#L25-L42)).
- The explicit `PATH` omits the image's `/opt/hermes/bin` wrapper. A live Hermes terminal invocation reported `hermes: command not found`.
- Optional tool downloads assume amd64, are not checksum-verified, and include old pinned versions.
- The Flux Kustomization still depends on `llama` despite using the OpenAI Codex provider.
- AgentMemory removal commands remain in the init script after AgentMemory was archived.
- The large inline RBAC block obscures the application runtime configuration.

## Scope

### In scope

- Pod/container topology
- Config initialization and migration
- Optional dependency handling
- Power-user tool installation
- Environment and volume cleanup
- Probes and resource requests
- Flux dependencies
- RBAC organization without permission changes
- Render, schema, and read-only live validation

### Out of scope

- Removing terminal access or optional power-user tools
- Narrowing the intentional cluster-wide read-only RBAC
- Changing Codex, Authentik, Firecrawl, SearXNG, Grafana MCP, Discord, VolSync, the PVC, hostnames, or service consumers
- Adding a custom Hermes image or image-build pipeline
- Introducing a NetworkPolicy without a complete API-client inventory
- Manually patching live resources
- Pushing changes without explicit permission

## Architecture

Hermes remains one Flux `Kustomization` and one app-template `HelmRelease`. The pod changes from two application containers to one Hermes container with two deterministic init steps.

### Startup sequence

1. **Config init** stages the Git-managed `config.yaml` and `SOUL.md` in temporary storage, migrates the staged config non-interactively with the pinned Hermes image, then installs the result and correct ownership onto the persistent volume.
2. **Tools init** reconciles optional command-line tools under `/opt/data/.local`.
3. **Hermes app** starts `hermes gateway run`; the image's S6 supervisor also starts the dashboard when `HERMES_DASHBOARD=true`.

The image starts as root only so its initialization hook can reconcile volume ownership, then its supervised services drop to the `hermes` user ([Dockerfile](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/Dockerfile#L216-L230)). This behavior remains intact.

### Network endpoints

The single pod exposes two named ports:

- `api`: 8642
- `dashboard`: 9119

The existing API and dashboard Services remain separate and continue selecting the same pod. The existing HTTPRoute continues targeting the dashboard Service. Hostnames and in-cluster service names do not change.

### Persistent data

The Hermes PVC remains mounted at `/opt/data` and continues to hold auth, sessions, memory, workspace, configuration, optional tools, and lazy packages. The existing VolSync component, schedule, source PVC, and repository remain unchanged.

Removed runtime pieces are:

- dashboard sidecar
- Firecrawl package init container
- `python-packages` emptyDir
- dashboard-specific temporary mounts
- `GATEWAY_HEALTH_URL`

## Declarative Configuration

Git remains authoritative for `config.yaml` and `SOUL.md`. Runtime configuration changes made through Hermes may take effect temporarily but are replaced by the Git-managed configuration after a pod restart.

The config init process uses a temporary staging directory so migration backups and intermediate writes do not accumulate on the PVC. Only the final migrated config is copied into place. Migration completes before S6 starts, preventing concurrent gateway/dashboard migration.

`config.yaml` will:

- remove deprecated top-level `toolsets`
- set `platform_toolsets.cli` to `hermes-cli`
- retain the Grafana MCP server; MCP tools are discovered from `mcp_servers` rather than named as a toolset
- retain the current Codex provider/model
- retain memory, compression, approvals, display, privacy, security, and command-allowlist choices
- leave Discord on its upstream default platform toolset

## Environment and Secrets

Keep settings and secret mappings needed for:

- API authentication and CORS
- Authentik OIDC and dashboard public URL
- Discord
- Firecrawl
- OpenRouter-backed vision tools
- SearXNG
- browser operation
- timezone
- Go and Homebrew

Self-hosted OIDC continues to use `HERMES_DASHBOARD_OIDC_ISSUER`, `HERMES_DASHBOARD_OIDC_CLIENT_ID`, and optional client secret, which are the upstream activation inputs ([self-hosted OIDC plugin](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/plugins/dashboard_auth/self_hosted/__init__.py#L789-L828)).

Remove environment values used only by the superseded manual Python install, including `PYTHONPATH` and `PIP_BREAK_SYSTEM_PACKAGES`. Remove the redundant explicit `HOME`; retain explicit `HERMES_HOME=/opt/data` because it documents the PVC contract.

`OPENROUTER_API_KEY` remains in the ExternalSecret because the `vision` toolset uses it even when Codex is the chat provider.

## Optional Dependencies

Remove the Firecrawl init container and rely on Hermes's built-in lazy dependency manager. The image directs optional packages to `/opt/data/lazy-packages`; when that durable target is configured, lazy installs remain allowed without mutating the sealed application venv ([lazy_deps.py](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/tools/lazy_deps.py#L420-L455)).

This removes the ephemeral dependency volume and avoids putting third-party packages before Hermes core packages on `sys.path`.

## Power-User Tools

Retain:

- GitHub CLI
- Go
- Homebrew
- Docker CLI
- local terminal access
- Kubernetes diagnostics

Docker CLI is already included in the Hermes image ([Dockerfile](https://github.com/NousResearch/hermes-agent/blob/3ef6bbd201263d354fd83ec55b3c306ded2eb72a/Dockerfile#L29-L32)), so the deployment will not install or delete a separate Docker binary.

The tools init script will:

- detect amd64 and arm64
- use pinned versions
- verify upstream checksums before extraction
- record or inspect installed versions
- skip downloads when the desired version is already present
- preserve a valid existing installation if a refresh fails
- warn and continue if an optional tool cannot be installed

The container `PATH` retains upstream ordering, including `/opt/hermes/bin` before the venv and user-installed binaries, while adding Go and Homebrew paths. This restores the upstream privilege-dropping Hermes wrapper.

## Manifest Organization and RBAC

Move the ClusterRole and ClusterRoleBinding from Helm values into `app/rbac.yaml`, and add that file to `app/kustomization.yaml`. Keep the service account generated by app-template.

The extracted RBAC must preserve the current effective permission set exactly:

- cluster-wide `get`, `list`, and `watch`
- explicitly enumerated diagnostic resources
- no Kubernetes Secrets
- no create, update, patch, delete, bind, escalate, or impersonate privileges

The Flux Kustomization removes its stale `llama` dependency and retains dependencies on Grafana MCP and VolSync.

## Data Flow and Security

```text
Browser
  -> internal Envoy Gateway
  -> hermes-dashboard Service :9119
  -> Authentik OIDC
  -> supervised Hermes dashboard

API client
  -> hermes-app ClusterIP Service :8642
  -> API_SERVER_KEY authentication
  -> supervised Hermes gateway

Hermes
  -> Codex OAuth / Firecrawl / SearXNG / Grafana MCP
  -> local terminal and PVC
  -> Kubernetes API through explicit read-only RBAC

Hermes PVC
  -> existing VolSync schedule
  -> existing Garage repository
```

The local terminal remains intentionally unsandboxed within the pod. Its Kubernetes access remains constrained by the read-only service account. The API remains ClusterIP-only and key-protected. The dashboard remains internal and OIDC-protected. CORS remains scoped to the Hermes dashboard origin.

No NetworkPolicy is added because existing in-cluster API consumers have not been fully inventoried.

## Health, Failure Handling, and Resources

### Failure handling

- Config staging and migration are fail-closed. Invalid desired configuration prevents Hermes from starting with unintended defaults.
- Optional tool installation is fail-soft. Existing valid tools are retained; unavailable optional tools do not take down Hermes.
- S6 supervises gateway and dashboard child processes.
- Helm install/upgrade remediation, Flux retries, `Recreate` strategy, and the 600-second termination grace period remain.
- VolSync behavior is unchanged.

### Probes

- Add a startup probe that allows initialization and S6 startup time.
- Readiness verifies both the gateway and dashboard listeners.
- Liveness checks gateway health and allows S6 time to recover a child before Kubernetes restarts the pod.

### Resources

Use one resource envelope for the consolidated container:

- CPU request: 250m
- Memory request: 1 GiB
- CPU limit: none
- Memory limit: 4 GiB

This is conservative relative to the observed combined usage while reducing the current total CPU reservation.

## Validation

### Repository validation

Before deployment:

1. Render the Hermes app Kustomization.
2. Render the parent AI Kustomization with Flux substitutions.
3. Validate generated resources against available Kubernetes schemas.
4. Run shell syntax/static checks on init scripts.
5. Exercise staged config migration with the pinned Hermes image.
6. Inspect the rendered Deployment and confirm:
   - one application container
   - deterministic init ordering
   - both named ports
   - expected startup/readiness/liveness probes
   - no dashboard sidecar
   - no Python package emptyDir or `PYTHONPATH`
   - no stale AgentMemory cleanup
7. Inspect rendered Services, HTTPRoute, PVC references, and Flux dependencies.
8. Compare the service account's effective permissions before and after; there must be no RBAC drift.

### Rollout validation

A local commit does not affect the cluster. Do not push without explicit permission.

If a push is authorized and Flux reconciles:

1. Wait for the Flux Kustomization and HelmRelease to report Ready.
2. Confirm one `1/1 Ready` Hermes pod with successful init containers and no restarts.
3. Confirm both Services have endpoints and the HTTPRoute remains accepted.
4. Verify gateway health and the dashboard OIDC redirect.
5. Confirm `hermes`, `gh`, `go`, `brew`, and Docker CLI resolve without modifying state.
6. Inspect logs for config migration races, invalid health-key warnings, dependency failures, and restart loops.
7. Confirm Firecrawl can load through the durable lazy dependency path.
8. Compare post-rollout resource usage and effective RBAC.

## Acceptance Criteria

The cleanup is complete when:

- Flux and Helm report Hermes healthy.
- Hermes runs one application container with S6-supervised gateway and dashboard.
- Existing API and dashboard service addresses remain unchanged.
- Dashboard OIDC, API authentication, Discord, Firecrawl, SearXNG, Grafana MCP, OpenRouter vision, persistent state, and VolSync remain available.
- The Hermes terminal resolves the `hermes` wrapper and retained optional tools.
- Startup logs no longer show concurrent config migration or repeated invalid detailed-health requests.
- Deprecated and stale deployment plumbing is absent.
- Effective RBAC is unchanged and remains read-only/secret-free.
- The change can be rolled back with a normal Git revert and Flux reconciliation.
