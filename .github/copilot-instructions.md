# Home Server GitOps Cluster - Copilot Instructions

## Architecture Overview

This is a **GitOps-managed Kubernetes home server** running on Talos Linux with Flux CD. The cluster consists of:
- **5 nodes**: 4x Turing RK1 (ARM64), 1x AMD-7940HS (x86_64)
- **OS**: Talos Linux (immutable, API-configured)
- **GitOps**: Flux CD manages all workloads from this Git repository
- **Storage**: Longhorn for persistent volumes
- **Networking**: Cilium CNI, dual NGINX (internal/external), Cloudflare DNS/DDNS
- **Secrets**: SOPS with AGE encryption for all sensitive data

## Repository Structure

```
kubernetes/
├── apps/          # User-facing applications (Immich, AI, dashboards)
├── media/         # *arr stack (Sonarr, Radarr, Jellyfin, etc.)
├── infrastructure/ # Core platform (Flux, Reflector, Reloader)
├── networking/    # Ingress, DNS, certificates, VPN gateway
├── storage/       # Longhorn, databases (Postgres, Dragonfly)
├── security/      # Authentik, External Secrets operator
├── nodes/         # Node-level workloads (NVIDIA, NFD, system upgrades)
├── observability/ # Monitoring stack (Prometheus, Grafana)
└── cluster-vars.yaml # Global config (IPs, domains, timezone)

talos/
├── talconfig.yaml      # Talos cluster config (talhelper)
├── talsecret.sops.yaml # Encrypted Talos secrets
└── clusterconfig/      # Generated node configs
```

## Deployment Patterns

### Two-Layer Flux Kustomization Pattern
Most components use **nested Flux Kustomizations**:

1. **Parent**: `install.yaml` in category root (e.g., `kubernetes/media/jellyfin/install.yaml`)
   - Flux `Kustomization` pointing to `app/` subdirectory
   - References `sops-age` secret for decryption (when needed)
   - Defines `dependsOn` for orchestration
   - Uses `postBuild.substituteFrom` for `cluster-settings` ConfigMap

2. **Child**: `app/kustomization.yaml` + resources
   - Standard Kustomize referencing actual manifests
   - Contains `release.yaml` (HelmRelease), ConfigMaps, ExternalSecrets

**Example** (`kubernetes/media/jellyfin/install.yaml`):
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: jellyfin
  namespace: flux-system
spec:
  targetNamespace: home-media
  path: "./kubernetes/media/jellyfin/app"
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age  # Required for encrypted secrets
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings  # Contains ${TZ}, ${NGINX_INTERNAL_IP}, etc.
```

### Multi-Component Apps (Immich Pattern)
Complex apps split into multiple Flux Kustomizations in single `install.yaml`:
- `immich-server` (base component)
- `immich-machine-learning` (depends on server)
- `immich-microservices` (depends on server)

Each targets a different subdirectory: `app/server/`, `app/machine-learning/`, etc.

## Key Conventions

### Helm Releases
- **Primary chart**: `bjw-s/app-template` (v3.x for most apps)
- **Schema validation**: Use `# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s/helm-charts/...`
- **Repositories**: Defined in `kubernetes/infrastructure/flux/repositories/`
- **Reloader annotation**: Add `reloader.stakater.com/auto: "true"` to auto-restart on ConfigMap/Secret changes

### Secrets Management
- **All secrets encrypted** with SOPS + AGE (`age13arp4yu8k7s9ck59ryj4vzedkggkp8eph6hq9ukdtcpdvnf8f9uqypjty6`)
- **ExternalSecrets**: Pull from 1Password via `ClusterSecretStore/onepassword-connect`
- **Database credentials**: Use `ClusterSecretStore/crunchy-pgo-secrets` for Postgres user secrets
- **Talos secrets**: Stored in `talos/talsecret.sops.yaml`

### Dependency Orchestration
Use `dependsOn` in Flux Kustomizations for ordering:
```yaml
dependsOn:
  - name: crunchy-postgres-operator
  - name: external-secrets-stores
    namespace: secrets
```

### Variable Substitution
Reference `cluster-vars.yaml` variables in manifests:
- `${TZ}` → `Europe/Dublin`
- `${NGINX_INTERNAL_IP}` → `192.168.1.160`
- `${LOCAL_DOMAIN}` → `local.solonsstuff.com`

All variables available via `cluster-settings` ConfigMap (reflected to other namespaces via Reflector).

## Critical Workflows

### Adding a New Application
1. Create directory structure: `kubernetes/<category>/<app>/app/`
2. Add `install.yaml` (Flux Kustomization) in `kubernetes/<category>/<app>/`
3. Create `app/kustomization.yaml`, `app/release.yaml` (HelmRelease), ConfigMaps
4. Add ExternalSecret if credentials needed (reference ClusterSecretStore)
5. Update parent `kustomization.yaml` (e.g., `kubernetes/media/kustomization.yaml`)
6. If using SOPS: Add `decryption.secretRef.name: sops-age` to `install.yaml`
7. Commit and push (Flux auto-reconciles every 30m or use `flux reconcile kustomization flux-system --with-source`)

### Talos Node Management
```powershell
# Generate configs from talconfig.yaml
cd talos
talhelper genconfig

# Apply to nodes (reverse order: kube5→kube1)
task apply

# Decrypt secrets for local viewing
sops -d talsecret.sops.yaml
```

### Secrets Operations
```powershell
# Encrypt new secret
sops -e --age age13arp4yu8k7... secret.yaml > secret.sops.yaml

# Edit encrypted file
sops secret.sops.yaml

# Decrypt temporarily
sops -d secret.sops.yaml
```

### Flux Reconciliation
```powershell
# Force full reconcile
flux reconcile kustomization flux-system --with-source

# Reconcile specific app
flux reconcile kustomization jellyfin -n flux-system

# Check Flux health
flux get all -A
```

## Common Gotchas

1. **SOPS decryption failures**: Ensure `decryption.secretRef.name: sops-age` in Flux Kustomization
2. **Variable substitution not working**: Check `postBuild.substituteFrom` references `cluster-settings`
3. **HelmRelease suspended**: Renovate PRs may set `suspend: true` - remove before merging
4. **Namespace mismatch**: `install.yaml` `targetNamespace` must match app resources
5. **Prune disabled**: Most Kustomizations have `prune: false` - manual cleanup required
6. **Node arch conflicts**: Tag images correctly for ARM64 vs x86_64 nodes

## Renovate Automation

- **Auto-updates**: Docker images, Helm charts, GitHub Actions
- **Auto-merge**: Enabled for minor/patch updates (3-day age requirement)
- **Grouped updates**: Flux, CoreDNS, Spegel components grouped in single PRs
- **Version pinning**: Images use `tag@sha256:...` format for reproducibility

## External Dependencies

- **1Password**: Secrets source (via `onepassword-connect` ClusterSecretStore)
- **Cloudflare**: DNS, DDNS, external-dns, cert-manager ACME
- **Longhorn**: Backed by `/var/lib/longhorn` on each node (see `talconfig.yaml` extraMounts)
- **Crunchy Postgres Operator**: Multi-cluster Postgres with pgBouncer (`192.168.1.154`)

## Quick Reference

| Component | Location | Purpose |
|-----------|----------|---------|
| Flux core | `infrastructure/flux/` | GitOps engine |
| Helm repos | `infrastructure/flux/repositories/` | HelmRepository CRDs |
| Global vars | `cluster-vars.yaml` | ConfigMap with IPs/domains |
| SOPS key secret | `infrastructure/flux/secrets/` | AGE private key for decryption |
| Database operator | `storage/databases/postgres/` | Crunchy Postgres (4 Kustomizations) |
| Ingress controllers | `networking/nginx/` | Internal + external NGINX |

---

**When making changes**: Always verify Flux syntax with `# yaml-language-server` comments and test locally with `kustomize build` before committing.
