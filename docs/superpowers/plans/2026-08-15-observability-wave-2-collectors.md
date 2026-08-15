# Observability Wave 2 Collectors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the low-risk application metrics integrations identified by the audit and prove that every new monitor resolves healthy targets.

**Architecture:** Prefer chart-native ServiceMonitor or PodMonitor resources. Use app-template 5.0.1 monitor objects for app-template workloads and one explicit PodMonitor for Dragonfly data-plane pods.

**Tech Stack:** Flux, Helm 4, Kustomize 5.8, Prometheus Operator, app-template 5.0.1, Kubernetes

## Global Constraints

- Wave 1 must be deployed and its live gate must pass before beginning this plan.
- Do not push without explicit permission because a push triggers Flux reconciliation.
- Before every push, enumerate `origin/main..HEAD`; permission must cover every listed commit, not only this wave.
- Do not change Alertmanager, Grafana dashboards, credentials, or Secrets in this wave.
- Keep smartctl-exporter's bundled rules, kube-proxy monitoring, and Hubble disabled.
- Use chart-native monitors where available; use `service.identifier` with app-template 5.0.1 rather than deprecated `serviceName`.
- Establish a Prometheus series baseline before push and stop if total active series grow by more than 25 percent.

## Tool Prerequisite

The validation commands require mikefarah `yq` v4.47.2. The current workstation does not have it installed. Keep one shell session open for the plan and prepare a temporary verified binary:

```bash
observability_tools_dir=$(mktemp -d)
case "$(uname -m)" in
  x86_64) observability_yq_arch=amd64 ;;
  aarch64|arm64) observability_yq_arch=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)"; exit 1 ;;
esac
curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.47.2/yq_linux_${observability_yq_arch}" -o "$observability_tools_dir/yq"
chmod +x "$observability_tools_dir/yq"
export PATH="$observability_tools_dir:$PATH"
yq --version
```

Expected: the command reports yq `v4.47.2`. Delete the temporary directory after finishing the plan.

---

### Task 1: Enable ExternalDNS, NFD, and cert-manager monitors

**Files:**

- Modify: `kubernetes/networking/external-dns/cloudflare/app/release.yaml`
- Modify: `kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml`
- Modify: `kubernetes/networking/cert-manager/cert-manager/app/helm/values.yaml`

**Interfaces:**

- Consumes: metrics endpoints already provided by ExternalDNS, Node Feature Discovery, and cert-manager.
- Produces: ExternalDNS and cert-manager ServiceMonitors plus the NFD PodMonitor.

- [ ] **Step 1: Prove all three integrations are disabled**

```bash
yq -e '.spec.values.serviceMonitor.enabled == true' kubernetes/networking/external-dns/cloudflare/app/release.yaml
yq -e '.spec.values.prometheus.enable == true' kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml
yq -e '.prometheus.servicemonitor.enabled == true' kubernetes/networking/cert-manager/cert-manager/app/helm/values.yaml
```

Expected: each command exits `1`.

- [ ] **Step 2: Enable the three chart-native monitors**

Set ExternalDNS to:

```yaml
    serviceMonitor:
      enabled: true
```

Set NFD to:

```yaml
    prometheus:
      enable: true
```

Remove the obsolete NFD comment about Prometheus not running. Append this to cert-manager's values:

```yaml
prometheus:
  servicemonitor:
    enabled: true
```

- [ ] **Step 3: Render and validate all three charts**

```bash
helm template external-dns https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-1.21.1/external-dns-1.21.1.tgz --namespace networking --values <(yq 'explode(.) | .spec.values' kubernetes/networking/external-dns/cloudflare/app/release.yaml) | yq -e 'select(.kind == "ServiceMonitor")'
helm template node-feature-discovery https://github.com/kubernetes-sigs/node-feature-discovery/releases/download/v0.19.0/node-feature-discovery-chart-0.19.0.tgz --namespace kube-system --values <(yq 'explode(.) | .spec.values' kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml) | yq -e 'select(.kind == "PodMonitor")'
helm template cert-manager https://charts.jetstack.io/charts/cert-manager-v1.21.1.tgz --namespace networking --values kubernetes/networking/cert-manager/cert-manager/app/helm/values.yaml | yq -e 'select(.kind == "ServiceMonitor")'
kustomize build kubernetes/networking/external-dns/cloudflare/app >/dev/null
kustomize build kubernetes/infra/node-feature-discovery/node-feature-discovery/app >/dev/null
kustomize build kubernetes/networking/cert-manager/cert-manager/app >/dev/null
git diff --check
```

Expected: every chart renders the expected monitor kind and all builds pass.

- [ ] **Step 4: Commit the native monitor toggles**

```bash
git add kubernetes/networking/external-dns/cloudflare/app/release.yaml kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml kubernetes/networking/cert-manager/cert-manager/app/helm/values.yaml
git commit -m "feat(monitoring): enable core service collectors"
```

---

### Task 2: Monitor Flux Operator and Flux controllers

**Files:**

- Modify: `kubernetes/infra/flux/operator/release.yaml`
- Create: `kubernetes/infra/flux/instance/podmonitor.yaml`
- Modify: `kubernetes/infra/flux/instance/kustomization.yaml`

**Interfaces:**

- Consumes: Flux Operator metrics service and Flux controller `http-prom` ports.
- Produces: chart-rendered Flux Operator ServiceMonitor and explicit PodMonitor `flux-system`.

- [ ] **Step 1: Prove neither monitor is declared**

```bash
yq -e '.spec.values.serviceMonitor.create == true' kubernetes/infra/flux/operator/release.yaml
test -f kubernetes/infra/flux/instance/podmonitor.yaml
```

Expected: both commands exit `1`.

- [ ] **Step 2: Enable the Flux Operator ServiceMonitor**

Add to the HelmRelease spec:

```yaml
  values:
    serviceMonitor:
      create: true
```

- [ ] **Step 3: Add the official Flux controller PodMonitor**

Create `podmonitor.yaml` and add `./podmonitor.yaml` to the instance Kustomization:

```yaml
---
# yaml-language-server: $schema=https://kube-schemas.pages.dev/monitoring.coreos.com/podmonitor_v1.json
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: flux-system
spec:
  namespaceSelector:
    matchNames:
      - flux-system
  selector:
    matchExpressions:
      - key: app
        operator: In
        values:
          - helm-controller
          - source-controller
          - kustomize-controller
          - notification-controller
          - image-automation-controller
          - image-reflector-controller
  podMetricsEndpoints:
    - port: http-prom
```

- [ ] **Step 4: Render and validate both Flux monitors**

```bash
helm template flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator --version 0.58.0 --namespace flux-system --values <(yq 'explode(.) | .spec.values' kubernetes/infra/flux/operator/release.yaml) | yq -e 'select(.kind == "ServiceMonitor")'
kustomize build kubernetes/infra/flux/instance | yq -e 'select(.kind == "PodMonitor" and .metadata.name == "flux-system" and .spec.podMetricsEndpoints[0].port == "http-prom")'
kustomize build kubernetes/infra/flux/operator >/dev/null
git diff --check
```

Expected: both monitor resources render.

- [ ] **Step 5: Commit the Flux monitoring integration**

```bash
git add kubernetes/infra/flux/operator/release.yaml kubernetes/infra/flux/instance/podmonitor.yaml kubernetes/infra/flux/instance/kustomization.yaml
git commit -m "feat(flux): enable controller metrics collection"
```

---

### Task 3: Enable Reloader's PodMonitor

**Files:**

- Modify: `kubernetes/infra/reloader/reloader/app/release.yaml`

**Interfaces:**

- Consumes: Reloader's metrics port.
- Produces: the chart's PodMonitor; the deprecated ServiceMonitor remains disabled.

- [ ] **Step 1: Prove the PodMonitor is disabled**

```bash
yq -e '.spec.values.reloader.podMonitor.enabled == true' kubernetes/infra/reloader/reloader/app/release.yaml
```

Expected: exit status `1`.

- [ ] **Step 2: Add the PodMonitor value beneath `reloader`**

```yaml
    reloader:
      reloadStrategy: annotations
      podMonitor:
        enabled: true
```

- [ ] **Step 3: Render and validate the PodMonitor**

```bash
helm template reloader https://stakater.github.io/stakater-charts/reloader-2.2.16.tgz --namespace kube-system --values <(yq 'explode(.) | .spec.values' kubernetes/infra/reloader/reloader/app/release.yaml) | yq -e 'select(.kind == "PodMonitor")'
kustomize build kubernetes/infra/reloader/reloader/app >/dev/null
git diff --check
```

Expected: the chart renders a PodMonitor.

- [ ] **Step 4: Commit the Reloader monitor**

```bash
git add kubernetes/infra/reloader/reloader/app/release.yaml
git commit -m "feat(reloader): enable PodMonitor"
```

---

### Task 4: Add app-template ServiceMonitors

**Files:**

- Modify: `kubernetes/misc/immich/app/server/release.yaml`
- Modify: `kubernetes/storage/databases/dragonfly/app/release.yaml`
- Modify: `kubernetes/observability/promxy/app/helmrelease.yaml`

**Interfaces:**

- Consumes: app-template services `immich-server` port `metrics`, `dragonfly-operator` port `metrics`, and `promxy` port `http`.
- Produces: one ServiceMonitor per application using app-template 5.0.1 `service.identifier` references.

- [ ] **Step 1: Prove none renders a ServiceMonitor**

```bash
for release_file in kubernetes/misc/immich/app/server/release.yaml kubernetes/storage/databases/dragonfly/app/release.yaml kubernetes/observability/promxy/app/helmrelease.yaml; do
  if helm template test oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.0.1 --values <(yq 'explode(.) | .spec.values' "$release_file") | yq -e 'select(.kind == "ServiceMonitor")'; then exit 1; fi
done
```

Expected: exit status `0` because all three ServiceMonitors are absent.

- [ ] **Step 2: Add the Immich ServiceMonitor and remove its stale commented block**

```yaml
    serviceMonitor:
      app:
        enabled: true
        service:
          identifier: app
        endpoints:
          - port: metrics
            path: /metrics
            interval: 1m
            scrapeTimeout: 10s
```

- [ ] **Step 3: Add the Dragonfly operator ServiceMonitor**

```yaml
    serviceMonitor:
      app:
        enabled: true
        service:
          identifier: app
        endpoints:
          - port: metrics
            path: /metrics
            interval: 30s
```

- [ ] **Step 4: Add the promxy ServiceMonitor**

```yaml
    serviceMonitor:
      app:
        enabled: true
        service:
          identifier: app
        endpoints:
          - port: http
            path: /metrics
            interval: 30s
```

- [ ] **Step 5: Render and validate all three ServiceMonitors**

```bash
helm template immich-server oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.0.1 --namespace misc --values <(yq 'explode(.) | .spec.values' kubernetes/misc/immich/app/server/release.yaml) | yq -e 'select(.kind == "ServiceMonitor" and .spec.endpoints[0].port == "metrics")'
helm template dragonfly-operator oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.0.1 --namespace databases --values <(yq 'explode(.) | .spec.values' kubernetes/storage/databases/dragonfly/app/release.yaml) | yq -e 'select(.kind == "ServiceMonitor" and .spec.endpoints[0].port == "metrics")'
helm template promxy oci://ghcr.io/bjw-s-labs/helm/app-template --version 5.0.1 --namespace observability --values <(yq 'explode(.) | .spec.values' kubernetes/observability/promxy/app/helmrelease.yaml) | yq -e 'select(.kind == "ServiceMonitor" and .spec.endpoints[0].port == "http")'
kustomize build kubernetes/misc/immich/app/server >/dev/null
kustomize build kubernetes/storage/databases/dragonfly/app >/dev/null
kustomize build kubernetes/observability/promxy/app >/dev/null
git diff --check
```

Expected: all three monitors select their intended service ports.

- [ ] **Step 6: Commit the app-template monitors**

```bash
git add kubernetes/misc/immich/app/server/release.yaml kubernetes/storage/databases/dragonfly/app/release.yaml kubernetes/observability/promxy/app/helmrelease.yaml
git commit -m "feat(monitoring): scrape app-template metrics"
```

---

### Task 5: Add the Dragonfly data-plane PodMonitor

**Files:**

- Create: `kubernetes/storage/databases/dragonfly/cluster/podmonitor.yaml`
- Modify: `kubernetes/storage/databases/dragonfly/cluster/kustomization.yaml`

**Interfaces:**

- Consumes: Dragonfly pods labeled `app.kubernetes.io/name: dragonfly` with named port `admin` on 9999.
- Produces: PodMonitor `dragonfly` scraping `/metrics` from every master and replica.

- [ ] **Step 1: Prove the cluster Kustomization has no PodMonitor**

```bash
kustomize build kubernetes/storage/databases/dragonfly/cluster | yq -e 'select(.kind == "PodMonitor")'
```

Expected: exit status `1`.

- [ ] **Step 2: Create the PodMonitor and add it to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://kube-schemas.pages.dev/monitoring.coreos.com/podmonitor_v1.json
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: dragonfly
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: dragonfly
  podTargetLabels:
    - app
    - role
  podMetricsEndpoints:
    - port: admin
      path: /metrics
      interval: 30s
```

Add `./podmonitor.yaml` to `kubernetes/storage/databases/dragonfly/cluster/kustomization.yaml`.

- [ ] **Step 3: Validate the rendered PodMonitor**

```bash
kustomize build kubernetes/storage/databases/dragonfly/cluster | yq -e 'select(.kind == "PodMonitor" and .metadata.name == "dragonfly" and .spec.podMetricsEndpoints[0].port == "admin" and .spec.selector.matchLabels."app.kubernetes.io/name" == "dragonfly")'
git diff --check
```

Expected: the assertion exits `0`.

- [ ] **Step 4: Commit the Dragonfly PodMonitor**

```bash
git add kubernetes/storage/databases/dragonfly/cluster/podmonitor.yaml kubernetes/storage/databases/dragonfly/cluster/kustomization.yaml
git commit -m "feat(dragonfly): monitor database metrics"
```

---

### Task 6: Run the wave 2 deployment gate

**Files:**

- Verify: all changed application directories and live Prometheus targets

**Interfaces:**

- Consumes: completed Tasks 1-5, successful wave 1 gate, and explicit permission to push.
- Produces: healthy low-risk targets and a series-growth result; authorizes wave 3 only if all checks pass.

- [ ] **Step 1: Capture the pre-wave series baseline**

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/observability-wave2-prometheus.log 2>&1 &
prom_wave2_pf_pid=$!
trap 'kill "$prom_wave2_pf_pid" 2>/dev/null || true' EXIT
curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=count({__name__=~".+"})' | jq -er '.data.result[0].value[1] | tonumber' >/tmp/observability-wave2-series-before
test "$(cat /tmp/observability-wave2-series-before)" -gt 0
```

Expected: a positive series count is recorded.

- [ ] **Step 2: Validate and review the complete wave**

```bash
for app_dir in kubernetes/networking/external-dns/cloudflare/app kubernetes/infra/node-feature-discovery/node-feature-discovery/app kubernetes/networking/cert-manager/cert-manager/app kubernetes/infra/flux/operator kubernetes/infra/flux/instance kubernetes/infra/reloader/reloader/app kubernetes/misc/immich/app/server kubernetes/storage/databases/dragonfly/app kubernetes/storage/databases/dragonfly/cluster kubernetes/observability/promxy/app; do kustomize build "$app_dir" >/dev/null || exit 1; done
git diff --check
git status --short
git log --oneline -5
```

Expected: every build passes, the worktree is clean, and the last five commits are the wave 2 changes.

- [ ] **Step 3: Stop and request explicit permission to push wave 2**

First enumerate the complete push scope:

```bash
git fetch origin main
git log --oneline origin/main..HEAD
```

Request approval for the entire displayed range. After approval only:

```bash
git push origin main
wave2_reconcile_request=$(date +%s)
kubectl annotate gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$wave2_reconcile_request" --overwrite
kubectl wait gitrepository/flux-system -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave2_reconcile_request" --timeout=2m
for flux_kustomization in external-dns node-feature-discovery cert-manager flux-system reloader immich-server dragonfly dragonfly-cluster promxy; do
  kubectl annotate kustomization/"$flux_kustomization" -n flux-system reconcile.fluxcd.io/requestedAt="$wave2_reconcile_request" --overwrite
  kubectl wait kustomization/"$flux_kustomization" -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave2_reconcile_request" --timeout=5m
  kubectl wait kustomization/"$flux_kustomization" -n flux-system --for=condition=Ready --timeout=5m
done
```

- [ ] **Step 4: Verify monitor resources and healthy targets**

```bash
kubectl get servicemonitor,podmonitor -A | grep -E 'external-dns|node-feature|cert-manager|flux-operator|flux-system|reloader|immich|dragonfly|promxy'
curl -fsS 'http://127.0.0.1:19090/api/v1/targets?state=active' >/tmp/observability-wave2-targets.json
for monitor_name in external-dns node-feature cert-manager flux-operator flux-system reloader immich dragonfly promxy; do
  jq -e --arg monitor_name "$monitor_name" 'any(.data.activeTargets[]; (.scrapePool | contains($monitor_name)) and .health == "up")' /tmp/observability-wave2-targets.json || exit 1
done
```

Expected: every named integration has at least one healthy target.

- [ ] **Step 5: Enforce the 25 percent series-growth limit**

```bash
wave2_series_before=$(cat /tmp/observability-wave2-series-before)
wave2_series_after=$(curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=count({__name__=~".+"})' | jq -er '.data.result[0].value[1] | tonumber')
awk -v before="$wave2_series_before" -v after="$wave2_series_after" 'BEGIN { print "before=" before, "after=" after, "growth=" ((after-before)/before)*100 "%"; exit !(after <= before * 1.25) }'
```

Expected: exit status `0`. If target health or growth fails, stop before wave 3 and revert the responsible commit or the complete wave 2 range.
