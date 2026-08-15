# Observability Wave 4 Dashboards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the recommended version-matched dashboards through Grafana Operator after all required metric targets are healthy.

**Architecture:** Use Tuppr's chart-native Grafana Operator integration, ConfigMap references for Cilium's chart-generated JSON, and release- or commit-pinned raw URLs for upstream dashboards. Every resource selects Grafana instances labeled `dashboards: grafana`.

**Tech Stack:** Flux, Kustomize 5.8, Helm 4, Grafana Operator v1beta1 resources, Prometheus datasource `prometheus`

## Global Constraints

- Waves 1-3 must be deployed and all live gates must pass before beginning this plan.
- Do not push without explicit permission because a push triggers Flux reconciliation.
- Before every push, enumerate `origin/main..HEAD`; permission must cover every listed commit, not only this wave.
- Do not add a Grafana sidecar or duplicate upstream JSON into local ConfigMaps.
- Use `allowCrossNamespaceImport: true` and `instanceSelector.matchLabels.dashboards: grafana` on every explicit GrafanaDashboard.
- Use the immutable URLs written in this plan; do not substitute branch-head URLs.
- Do not import Envoy's global rate-limit dashboard because that component is not deployed.
- Exclude Immich, cert-manager, ExternalDNS, Reloader, autobrr, and promxy because no canonical version-matched upstream dashboard was identified.

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

### Task 1: Enable Tuppr's native Grafana Operator dashboard

**Files:**

- Modify: `kubernetes/infra/tuppr/app/release.yaml`

**Interfaces:**

- Consumes: Tuppr's already enabled ServiceMonitor and PrometheusRule.
- Produces: chart-rendered Tuppr GrafanaDashboard selected by `dashboards: grafana`.

- [ ] **Step 1: Prove the dashboard is disabled**

```bash
yq -e '.spec.values.monitoring.dashboards.enabled == true and .spec.values.monitoring.dashboards.grafanaOperator.enabled == true' kubernetes/infra/tuppr/app/release.yaml
```

Expected: exit status `1`.

- [ ] **Step 2: Extend the existing monitoring block**

```yaml
    monitoring:
      serviceMonitor:
        enabled: true
      prometheusRule:
        enabled: true
      dashboards:
        enabled: true
        grafanaOperator:
          enabled: true
          allowCrossNamespaceImport: true
          matchLabels:
            dashboards: grafana
```

- [ ] **Step 3: Render and validate the dashboard**

```bash
helm template tuppr oci://ghcr.io/home-operations/charts/tuppr --version 0.5.0 --namespace kube-system --values <(yq 'explode(.) | .spec.values' kubernetes/infra/tuppr/app/release.yaml) | yq -e 'select(.kind == "GrafanaDashboard" and .spec.instanceSelector.matchLabels.dashboards == "grafana")'
kustomize build kubernetes/infra/tuppr/app >/dev/null
git diff --check
```

Expected: one matching GrafanaDashboard renders while the ServiceMonitor and PrometheusRule remain enabled.

- [ ] **Step 4: Commit the Tuppr dashboard**

```bash
git add kubernetes/infra/tuppr/app/release.yaml
git commit -m "feat(tuppr): enable Grafana dashboard"
```

---

### Task 2: Add External Secrets and DCGM dashboards

**Files:**

- Create: `kubernetes/security/secrets/external-secrets/app/grafanadashboard.yaml`
- Modify: `kubernetes/security/secrets/external-secrets/app/kustomization.yaml`
- Create: `kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/grafanadashboard.yaml`
- Modify: `kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/kustomization.yaml`

**Interfaces:**

- Consumes: the existing External Secrets and DCGM ServiceMonitors.
- Produces: URL-backed dashboards `external-secrets` and `nvidia-dcgm-exporter`.

- [ ] **Step 1: Prove both dashboards are absent**

```bash
test -f kubernetes/security/secrets/external-secrets/app/grafanadashboard.yaml
test -f kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/grafanadashboard.yaml
```

Expected: both commands exit `1`.

- [ ] **Step 2: Create the External Secrets dashboard and add it to its Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: external-secrets
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/external-secrets/external-secrets/v2.9.0/deploy/charts/external-secrets/files/monitoring/grafana-dashboard.json
```

Add `./grafanadashboard.yaml` to the External Secrets Kustomization.

- [ ] **Step 3: Create the DCGM dashboard and add it to its Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: nvidia-dcgm-exporter
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/4.6.0-4.8.3/grafana/dcgm-exporter-dashboard.json
```

Add `./grafanadashboard.yaml` to the DCGM Kustomization.

- [ ] **Step 4: Validate both imports and their URLs**

```bash
curl -fsSL https://raw.githubusercontent.com/external-secrets/external-secrets/v2.9.0/deploy/charts/external-secrets/files/monitoring/grafana-dashboard.json | jq -e '.title == "External Secrets Operator"'
curl -fsSL https://raw.githubusercontent.com/NVIDIA/dcgm-exporter/4.6.0-4.8.3/grafana/dcgm-exporter-dashboard.json | jq -e '.title == "NVIDIA DCGM Exporter Dashboard"'
kustomize build kubernetes/security/secrets/external-secrets/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "external-secrets")'
kustomize build kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "nvidia-dcgm-exporter")'
git diff --check
```

Expected: both upstream files are valid JSON and both resources render.

- [ ] **Step 5: Commit both ready-metrics dashboards**

```bash
git add kubernetes/security/secrets/external-secrets/app/grafanadashboard.yaml kubernetes/security/secrets/external-secrets/app/kustomization.yaml kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/grafanadashboard.yaml kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/kustomization.yaml
git commit -m "feat(grafana): add secrets and GPU dashboards"
```

---

### Task 3: Import the chart-generated Cilium dashboards

**Files:**

- Create: `kubernetes/networking/cilium/cilium/app/grafanadashboard.yaml`
- Modify: `kubernetes/networking/cilium/cilium/app/kustomization.yaml`

**Interfaces:**

- Consumes: ConfigMaps `cilium-dashboard`/`cilium-dashboard.json` and `cilium-operator-dashboard`/`cilium-operator-dashboard.json`.
- Produces: GrafanaDashboard resources `cilium-agent` and `cilium-operator`.

- [ ] **Step 1: Prove the Cilium dashboards are not imported**

```bash
kustomize build kubernetes/networking/cilium/cilium/app | yq -e 'select(.kind == "GrafanaDashboard")'
```

Expected: exit status `1`.

- [ ] **Step 2: Create both ConfigMap-backed dashboard resources**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cilium-agent
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  configMapRef:
    name: cilium-dashboard
    key: cilium-dashboard.json
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: cilium-operator
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  configMapRef:
    name: cilium-operator-dashboard
    key: cilium-operator-dashboard.json
```

Add `./grafanadashboard.yaml` to the Cilium Kustomization.

- [ ] **Step 3: Validate exactly two Cilium imports**

```bash
cilium_dashboard_count=$(kustomize build kubernetes/networking/cilium/cilium/app | yq -N 'select(.kind == "GrafanaDashboard") | .metadata.name' | wc -l)
test "$cilium_dashboard_count" -eq 2
kustomize build kubernetes/networking/cilium/cilium/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "cilium-agent" and .spec.configMapRef.name == "cilium-dashboard")'
kustomize build kubernetes/networking/cilium/cilium/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "cilium-operator" and .spec.configMapRef.name == "cilium-operator-dashboard")'
git diff --check
```

Expected: exactly two resources with the correct ConfigMap references.

- [ ] **Step 4: Commit the Cilium imports**

```bash
git add kubernetes/networking/cilium/cilium/app/grafanadashboard.yaml kubernetes/networking/cilium/cilium/app/kustomization.yaml
git commit -m "feat(cilium): import Grafana dashboards"
```

---

### Task 4: Add Flux dashboards

**Files:**

- Create: `kubernetes/infra/flux/instance/grafanadashboard.yaml`
- Modify: `kubernetes/infra/flux/instance/kustomization.yaml`

**Interfaces:**

- Consumes: `gotk_resource_info` metrics and Flux controller metrics enabled in wave 2.
- Produces: Flux Cluster Stats and Flux Control Plane dashboards pinned to monitoring-example commit `7ab65dc8b90f7a6751d88f18bbb4e1bee33bf334`.

- [ ] **Step 1: Create both Flux dashboards and add the file to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: flux-cluster-stats
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  url: https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/7ab65dc8b90f7a6751d88f18bbb4e1bee33bf334/monitoring/configs/dashboards/cluster.json
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: flux-control-plane
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  url: https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/7ab65dc8b90f7a6751d88f18bbb4e1bee33bf334/monitoring/configs/dashboards/control-plane.json
```

Add `./grafanadashboard.yaml` to the Flux instance Kustomization.

- [ ] **Step 2: Validate the pinned JSON and rendered resources**

```bash
for dashboard_name in cluster control-plane; do curl -fsSL "https://raw.githubusercontent.com/fluxcd/flux2-monitoring-example/7ab65dc8b90f7a6751d88f18bbb4e1bee33bf334/monitoring/configs/dashboards/${dashboard_name}.json" | jq -e '.title | startswith("Flux")' || exit 1; done
flux_dashboard_count=$(kustomize build kubernetes/infra/flux/instance | yq -N 'select(.kind == "GrafanaDashboard") | .metadata.name' | wc -l)
test "$flux_dashboard_count" -eq 2
git diff --check
```

Expected: both pinned documents are valid and exactly two dashboards render.

- [ ] **Step 3: Commit the Flux dashboards**

```bash
git add kubernetes/infra/flux/instance/grafanadashboard.yaml kubernetes/infra/flux/instance/kustomization.yaml
git commit -m "feat(flux): add Grafana dashboards"
```

---

### Task 5: Add the four applicable Envoy dashboards

**Files:**

- Create: `kubernetes/networking/envoy-gateway/config/grafanadashboard.yaml`
- Modify: `kubernetes/networking/envoy-gateway/config/kustomization.yaml`

**Interfaces:**

- Consumes: healthy Envoy Gateway and proxy targets repaired in wave 1.
- Produces: Gateway Global, Proxy Global, Clusters, and Resources dashboards for Envoy Gateway v1.8.3.

- [ ] **Step 1: Create the four URL-backed resources and add the file to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: envoy-gateway-global
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.3/charts/gateway-addons-helm/dashboards/envoy-gateway-global.json
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: envoy-proxy-global
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.3/charts/gateway-addons-helm/dashboards/envoy-proxy-global.json
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: envoy-clusters
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.3/charts/gateway-addons-helm/dashboards/envoy-clusters.json
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: envoy-resources
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  url: https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.3/charts/gateway-addons-helm/dashboards/resources-monitor.gen.json
```

Add `./grafanadashboard.yaml` to the Envoy config Kustomization.

- [ ] **Step 2: Validate all four URLs and resources**

```bash
for dashboard_file in envoy-gateway-global.json envoy-proxy-global.json envoy-clusters.json resources-monitor.gen.json; do curl -fsSL "https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.3/charts/gateway-addons-helm/dashboards/${dashboard_file}" | jq -e '.title | length > 0' || exit 1; done
envoy_dashboard_count=$(kustomize build kubernetes/networking/envoy-gateway/config | yq -N 'select(.kind == "GrafanaDashboard") | .metadata.name' | wc -l)
test "$envoy_dashboard_count" -eq 4
kustomize build kubernetes/networking/envoy-gateway/config | yq -e 'select(.kind == "GrafanaDashboard") | .spec.instanceSelector.matchLabels.dashboards == "grafana" and .spec.allowCrossNamespaceImport == true'
git diff --check
```

Expected: all URLs return dashboard JSON and exactly four resources render. No rate-limit dashboard is present.

- [ ] **Step 3: Commit the Envoy dashboards**

```bash
git add kubernetes/networking/envoy-gateway/config/grafanadashboard.yaml kubernetes/networking/envoy-gateway/config/kustomization.yaml
git commit -m "feat(envoy-gateway): add Grafana dashboards"
```

---

### Task 6: Add Authentik, NFD, and Dragonfly dashboards

**Files:**

- Create: `kubernetes/security/authentik/authentik/app/grafanadashboard.yaml`
- Modify: `kubernetes/security/authentik/authentik/app/kustomization.yaml`
- Create: `kubernetes/infra/node-feature-discovery/node-feature-discovery/app/grafanadashboard.yaml`
- Modify: `kubernetes/infra/node-feature-discovery/node-feature-discovery/app/kustomization.yaml`
- Create: `kubernetes/storage/databases/dragonfly/cluster/grafanadashboard.yaml`
- Modify: `kubernetes/storage/databases/dragonfly/cluster/kustomization.yaml`

**Interfaces:**

- Consumes: healthy Authentik, NFD, and Dragonfly targets from waves 2-3.
- Produces: one URL-backed dashboard for each application with explicit datasource input mappings.

- [ ] **Step 1: Create Authentik's dashboard and add it to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: authentik
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  url: https://raw.githubusercontent.com/goauthentik/authentik/version/2026.5.6/website/static/monitoring/grafana-dashboard.json
```

- [ ] **Step 2: Create NFD's dashboard and add it to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: node-feature-discovery
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
  url: https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.19.0/examples/grafana-dashboard.json
```

- [ ] **Step 3: Create Dragonfly's dashboard and add it to the Kustomization**

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/grafana.integreatly.org/grafanadashboard_v1beta1.json
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: dragonfly
spec:
  allowCrossNamespaceImport: true
  instanceSelector:
    matchLabels:
      dashboards: grafana
  datasources:
    - datasourceName: prometheus
      inputName: DS_PROMETHEUS
    - datasourceName: __expr__
      inputName: DS_EXPRESSION
  url: https://raw.githubusercontent.com/dragonflydb/dragonfly-operator/v1.6.1/monitoring/grafana-dashboard.json
```

- [ ] **Step 4: Validate upstream JSON and all three resources**

```bash
curl -fsSL https://raw.githubusercontent.com/goauthentik/authentik/version/2026.5.6/website/static/monitoring/grafana-dashboard.json | jq -e '.uid == "authentik"'
curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/node-feature-discovery/v0.19.0/examples/grafana-dashboard.json | jq -e '.title == "Node Feature Discovery"'
curl -fsSL https://raw.githubusercontent.com/dragonflydb/dragonfly-operator/v1.6.1/monitoring/grafana-dashboard.json | jq -e '.title == "Dragonfly Dashboard"'
kustomize build kubernetes/security/authentik/authentik/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "authentik")'
kustomize build kubernetes/infra/node-feature-discovery/node-feature-discovery/app | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "node-feature-discovery")'
kustomize build kubernetes/storage/databases/dragonfly/cluster | yq -e 'select(.kind == "GrafanaDashboard" and .metadata.name == "dragonfly" and .spec.datasources[1].datasourceName == "__expr__")'
git diff --check
```

Expected: all upstream files and rendered resources validate.

- [ ] **Step 5: Commit the three dashboards**

```bash
git add kubernetes/security/authentik/authentik/app/grafanadashboard.yaml kubernetes/security/authentik/authentik/app/kustomization.yaml kubernetes/infra/node-feature-discovery/node-feature-discovery/app/grafanadashboard.yaml kubernetes/infra/node-feature-discovery/node-feature-discovery/app/kustomization.yaml kubernetes/storage/databases/dragonfly/cluster/grafanadashboard.yaml kubernetes/storage/databases/dragonfly/cluster/kustomization.yaml
git commit -m "feat(grafana): add application dashboards"
```

---

### Task 7: Run the wave 4 deployment and completion gate

**Files:**

- Verify: all dashboard Kustomizations, GrafanaDashboard statuses, and representative Prometheus metrics

**Interfaces:**

- Consumes: completed Tasks 1-6, successful wave 3 gate, and explicit permission to push.
- Produces: synchronized, data-backed dashboards and completion of the observability expansion.

- [ ] **Step 1: Validate the complete dashboard wave**

```bash
for app_dir in kubernetes/infra/tuppr/app kubernetes/security/secrets/external-secrets/app kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app kubernetes/networking/cilium/cilium/app kubernetes/infra/flux/instance kubernetes/networking/envoy-gateway/config kubernetes/security/authentik/authentik/app kubernetes/infra/node-feature-discovery/node-feature-discovery/app kubernetes/storage/databases/dragonfly/cluster; do kustomize build "$app_dir" >/dev/null || exit 1; done
git diff --check
git status --short
git log --oneline -6
```

Expected: all builds pass, the worktree is clean, and the last six commits are wave 4.

- [ ] **Step 2: Stop and request explicit permission to push wave 4**

First enumerate the complete push scope:

```bash
git fetch origin main
git log --oneline origin/main..HEAD
```

Request approval for the entire displayed range. After approval only:

```bash
git push origin main
wave4_reconcile_request=$(date +%s)
kubectl annotate gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$wave4_reconcile_request" --overwrite
kubectl wait gitrepository/flux-system -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave4_reconcile_request" --timeout=2m
for flux_kustomization in tuppr dcgm-exporter flux-system envoy-gateway-config authentik node-feature-discovery dragonfly-cluster; do
  kubectl annotate kustomization/"$flux_kustomization" -n flux-system reconcile.fluxcd.io/requestedAt="$wave4_reconcile_request" --overwrite
  kubectl wait kustomization/"$flux_kustomization" -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave4_reconcile_request" --timeout=5m
  kubectl wait kustomization/"$flux_kustomization" -n flux-system --for=condition=Ready --timeout=5m
done
kubectl annotate kustomization/cilium -n kube-system reconcile.fluxcd.io/requestedAt="$wave4_reconcile_request" --overwrite
kubectl wait kustomization/cilium -n kube-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave4_reconcile_request" --timeout=5m
kubectl wait kustomization/cilium -n kube-system --for=condition=Ready --timeout=5m
kubectl annotate kustomization/external-secrets -n secrets reconcile.fluxcd.io/requestedAt="$wave4_reconcile_request" --overwrite
kubectl wait kustomization/external-secrets -n secrets --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave4_reconcile_request" --timeout=5m
kubectl wait kustomization/external-secrets -n secrets --for=condition=Ready --timeout=5m
```

- [ ] **Step 3: Require every dashboard to synchronize**

```bash
for dashboard_name in tuppr-dashboard external-secrets nvidia-dcgm-exporter cilium-agent cilium-operator flux-cluster-stats flux-control-plane envoy-gateway-global envoy-proxy-global envoy-clusters envoy-resources authentik node-feature-discovery dragonfly; do
  dashboard_reason=$(kubectl get grafanadashboard -A -o json | jq -r --arg dashboard_name "$dashboard_name" '.items[] | select(.metadata.name == $dashboard_name) | .status.conditions[-1].reason')
  test "$dashboard_reason" = ApplySuccessful || { echo "$dashboard_name: $dashboard_reason"; exit 1; }
done
```

Expected: all 14 dashboards report `ApplySuccessful`.

- [ ] **Step 4: Prove every dashboard family has source metrics**

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/observability-wave4-prometheus.log 2>&1 &
prom_wave4_pf_pid=$!
trap 'kill "$prom_wave4_pf_pid" 2>/dev/null || true' EXIT
dashboard_queries=(
  'count({__name__=~"tuppr_.+"})'
  'count(controller_runtime_reconcile_total{service=~".*external-secrets.*"})'
  'count({__name__=~"DCGM_FI_DEV_.+"})'
  'count({__name__=~"cilium_.+"})'
  'count({__name__=~"gotk_.+"})'
  'count({__name__=~"watchable_.+|envoy_.+"})'
  'count({__name__=~"authentik_.+"})'
  'count({__name__=~"nfd_.+"})'
  'count({__name__=~"dragonfly_.+"})'
)
for dashboard_query in "${dashboard_queries[@]}"; do
  metric_count=$(curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode "query=${dashboard_query}" | jq -er '.data.result[0].value[1] | tonumber')
  test "$metric_count" -gt 0 || { echo "no metrics for ${dashboard_query}"; exit 1; }
done
```

Expected: every dashboard family has at least one current series.

- [ ] **Step 5: Visually verify representative dashboards**

Open Grafana and verify these dashboard titles load without datasource errors or persistent `No data` across their overview panels: `Tuppr`, `External Secrets Operator`, `NVIDIA DCGM Exporter Dashboard`, `Cilium Metrics`, `Cilium Operator`, `Flux Cluster Stats`, `Flux Control Plane`, `Envoy Gateway Global`, `Envoy Global`, `Envoy Clusters`, `Resources Monitor`, `authentik`, `Node Feature Discovery`, and `Dragonfly Dashboard`.

Expected: all titles are present, datasource selectors resolve to `prometheus`, and representative overview panels show data. If one import is invalid, revert only that dashboard commit; do not disable its healthy collector.

- [ ] **Step 6: Audit chart-generated dashboard ConfigMaps**

```bash
for dashboard_ref in 'cilium-dashboard:cilium-dashboard.json' 'cilium-operator-dashboard:cilium-operator-dashboard.json' 'victoria-logs-victorialogs-single-node:victorialogs-single-node.json' 'victoria-logs-vector-k8s-monitoring:vector-k8s-monitoring.json' 'cloudnative-pg-dashboard:cloudnative-pg.json'; do
  dashboard_configmap=${dashboard_ref%%:*}
  dashboard_key=${dashboard_ref#*:}
  kubectl get grafanadashboard -A -o json | jq -e --arg dashboard_configmap "$dashboard_configmap" --arg dashboard_key "$dashboard_key" 'any(.items[]; .spec.configMapRef.name == $dashboard_configmap and .spec.configMapRef.key == $dashboard_key)' || exit 1
done
kubectl get grafanadashboard -A -o json | jq -e '[.items[] | select(.status.conditions[-1].reason != "ApplySuccessful")] | length == 0'
```

Expected: every intentionally retained chart dashboard ConfigMap has a matching GrafanaDashboard reference and no GrafanaDashboard remains invalid.
