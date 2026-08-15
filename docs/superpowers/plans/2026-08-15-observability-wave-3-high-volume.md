# Observability Wave 3 High-Volume Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Cilium and Authentik monitoring in an isolated rollout with explicit series-growth and alert-noise gates.

**Architecture:** Use the native Cilium agent/operator ServiceMonitors and the native Authentik server/worker ServiceMonitors. Enable Authentik's bundled PrometheusRule while keeping Hubble disabled and retaining Alertmanager's existing routing.

**Tech Stack:** Flux, Helm 4, Kustomize 5.8, Cilium chart 1.20.0, Authentik chart 2026.5.6, Prometheus Operator, Alertmanager

## Global Constraints

- Waves 1 and 2 must be deployed and their live gates must pass first.
- Do not push without explicit permission because a push triggers Flux reconciliation.
- Before every push, enumerate `origin/main..HEAD`; permission must cover every listed commit, not only this wave.
- Do not enable Hubble, Cilium Envoy, direct application notifications, or new credentials.
- Do not alter Cilium networking, routing, BGP, or policy settings beyond the three monitoring keys in this plan.
- Keep metric collection enabled if only an Authentik alert rule proves noisy; disable or tune the rules independently.
- Stop if total active Prometheus series grow by more than 50 percent or any new alert is unexpectedly firing.

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

### Task 1: Enable Cilium agent and operator monitoring

**Files:**

- Modify: `kubernetes/networking/cilium/cilium/app/helm-values.yaml`
- Test: Cilium chart 1.20.0 render and `kubernetes/networking/cilium/cilium/app/kustomization.yaml`

**Interfaces:**

- Consumes: Cilium agent metrics port 9962 and the already enabled operator metrics port 9963.
- Produces: Cilium agent metrics Service and ServiceMonitor plus the operator ServiceMonitor.

- [ ] **Step 1: Prove the required monitoring values are absent**

```bash
yq -e '.prometheus.enabled == true and .prometheus.serviceMonitor.enabled == true and .operator.prometheus.serviceMonitor.enabled == true' kubernetes/networking/cilium/cilium/app/helm-values.yaml
```

Expected: exit status `1`.

- [ ] **Step 2: Add only the Cilium monitoring values**

Add this top-level block near the existing dashboard settings:

```yaml
prometheus:
  enabled: true
  serviceMonitor:
    enabled: true
```

Extend the existing `operator` block to:

```yaml
operator:
  dashboards:
    enabled: true
  prometheus:
    serviceMonitor:
      enabled: true
  replicas: 1
  rollOutPods: true
```

- [ ] **Step 3: Render the exact chart and verify two ServiceMonitors**

```bash
cilium_service_monitor_count=$(helm template cilium https://helm.cilium.io/cilium-1.20.0.tgz --namespace kube-system --values kubernetes/networking/cilium/cilium/app/helm-values.yaml --set prometheus.serviceMonitor.trustCRDsExist=true | yq -N 'select(.kind == "ServiceMonitor") | .metadata.name' | wc -l)
test "$cilium_service_monitor_count" -eq 2
helm template cilium https://helm.cilium.io/cilium-1.20.0.tgz --namespace kube-system --values kubernetes/networking/cilium/cilium/app/helm-values.yaml --set prometheus.serviceMonitor.trustCRDsExist=true | yq -e 'select(.kind == "ServiceMonitor" and (.metadata.name | test("cilium-agent")))'
helm template cilium https://helm.cilium.io/cilium-1.20.0.tgz --namespace kube-system --values kubernetes/networking/cilium/cilium/app/helm-values.yaml --set prometheus.serviceMonitor.trustCRDsExist=true | yq -e 'select(.kind == "ServiceMonitor" and (.metadata.name | test("cilium-operator")))'
kustomize build kubernetes/networking/cilium/cilium/app >/dev/null
git diff --check
```

Expected: exactly the agent and operator ServiceMonitors render. `trustCRDsExist` is an offline-render override only; do not add it to repository values because the CRDs already exist in the cluster.

- [ ] **Step 4: Confirm the diff is monitoring-only**

```bash
git diff -- kubernetes/networking/cilium/cilium/app/helm-values.yaml
```

Expected: the diff contains only `prometheus.enabled`, `prometheus.serviceMonitor.enabled`, and `operator.prometheus.serviceMonitor.enabled`; Hubble remains false.

- [ ] **Step 5: Commit the Cilium monitoring values**

```bash
git add kubernetes/networking/cilium/cilium/app/helm-values.yaml
git commit -m "feat(cilium): enable Prometheus monitoring"
```

---

### Task 2: Enable Authentik metrics and bundled alert rules

**Files:**

- Modify: `kubernetes/security/authentik/authentik/app/release.yaml`
- Test: Authentik chart 2026.5.6 render and `kubernetes/security/authentik/authentik/app/kustomization.yaml`

**Interfaces:**

- Consumes: Authentik server and worker metrics endpoints on port 9300.
- Produces: two metrics Services, two ServiceMonitors, and Authentik's bundled PrometheusRule.

- [ ] **Step 1: Prove metrics and rules are disabled**

```bash
yq -e '.spec.values.server.metrics.enabled == true and .spec.values.server.metrics.serviceMonitor.enabled == true and .spec.values.worker.metrics.enabled == true and .spec.values.worker.metrics.serviceMonitor.enabled == true and .spec.values.prometheus.rules.enabled == true' kubernetes/security/authentik/authentik/app/release.yaml
```

Expected: exit status `1`.

- [ ] **Step 2: Enable server metrics beneath the existing `server` block**

```yaml
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          interval: 30s
          scrapeTimeout: 3s
```

- [ ] **Step 3: Enable worker metrics beneath the existing `worker` block**

```yaml
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          interval: 30s
          scrapeTimeout: 3s
```

- [ ] **Step 4: Enable Authentik's bundled rules at the root of chart values**

```yaml
    prometheus:
      rules:
        enabled: true
```

- [ ] **Step 5: Render and validate the exact chart**

```bash
helm repo add authentik https://charts.goauthentik.io --force-update
authentik_service_monitor_count=$(helm template authentik authentik/authentik --version 2026.5.6 --namespace security --values <(yq 'explode(.) | .spec.values' kubernetes/security/authentik/authentik/app/release.yaml) | yq -N 'select(.kind == "ServiceMonitor") | .metadata.name' | wc -l)
test "$authentik_service_monitor_count" -eq 2
helm template authentik authentik/authentik --version 2026.5.6 --namespace security --values <(yq 'explode(.) | .spec.values' kubernetes/security/authentik/authentik/app/release.yaml) | yq -e 'select(.kind == "PrometheusRule")'
kustomize build kubernetes/security/authentik/authentik/app >/dev/null
git diff --check
```

Expected: two ServiceMonitors and one PrometheusRule render.

- [ ] **Step 6: Commit Authentik monitoring**

```bash
git add kubernetes/security/authentik/authentik/app/release.yaml
git commit -m "feat(authentik): enable Prometheus monitoring"
```

---

### Task 3: Run the wave 3 deployment gate

**Files:**

- Verify: the two wave 3 commits and live Cilium/Authentik monitoring resources

**Interfaces:**

- Consumes: completed Tasks 1-2, successful wave 2 gate, and explicit permission to push.
- Produces: healthy Cilium and Authentik targets with bounded series growth and no unreviewed new firing alerts.

- [ ] **Step 1: Capture pre-wave series and firing-alert baselines**

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/observability-wave3-prometheus.log 2>&1 &
prom_wave3_pf_pid=$!
trap 'kill "$prom_wave3_pf_pid" 2>/dev/null || true' EXIT
curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=count({__name__=~".+"})' | jq -er '.data.result[0].value[1] | tonumber' >/tmp/observability-wave3-series-before
curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=ALERTS{alertstate="firing"}' | jq -c '[.data.result[].metric.alertname] | unique | sort' >/tmp/observability-wave3-alerts-before.json
```

Expected: both baseline files are created and the series count is positive.

- [ ] **Step 2: Validate and review the complete wave**

```bash
kustomize build kubernetes/networking/cilium/cilium/app >/dev/null
kustomize build kubernetes/security/authentik/authentik/app >/dev/null
git diff --check
git status --short
git log --oneline -2
```

Expected: all checks pass, the worktree is clean, and the last two commits are wave 3.

- [ ] **Step 3: Stop and request explicit permission to push wave 3**

First enumerate the complete push scope:

```bash
git fetch origin main
git log --oneline origin/main..HEAD
```

Request approval for the entire displayed range. After approval only:

```bash
git push origin main
wave3_reconcile_request=$(date +%s)
kubectl annotate gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$wave3_reconcile_request" --overwrite
kubectl wait gitrepository/flux-system -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave3_reconcile_request" --timeout=2m
kubectl annotate kustomization/cilium -n kube-system reconcile.fluxcd.io/requestedAt="$wave3_reconcile_request" --overwrite
kubectl wait kustomization/cilium -n kube-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave3_reconcile_request" --timeout=10m
kubectl wait kustomization/cilium -n kube-system --for=condition=Ready --timeout=10m
kubectl annotate kustomization/authentik -n flux-system reconcile.fluxcd.io/requestedAt="$wave3_reconcile_request" --overwrite
kubectl wait kustomization/authentik -n flux-system --for=jsonpath='{.status.lastHandledReconcileAt}'="$wave3_reconcile_request" --timeout=10m
kubectl wait kustomization/authentik -n flux-system --for=condition=Ready --timeout=10m
kubectl rollout status daemonset/cilium -n kube-system --timeout=10m
kubectl rollout status deployment/cilium-operator -n kube-system --timeout=10m
kubectl rollout status deployment/authentik-server -n security --timeout=10m
kubectl rollout status deployment/authentik-worker -n security --timeout=10m
```

Expected: Flux is Ready and all four workloads complete their rollout.

- [ ] **Step 4: Verify all new targets are healthy**

```bash
curl -fsS 'http://127.0.0.1:19090/api/v1/targets?state=active' >/tmp/observability-wave3-targets.json
for monitor_name in cilium-agent cilium-operator authentik-server authentik-worker; do
  jq -e --arg monitor_name "$monitor_name" 'any(.data.activeTargets[]; (.scrapePool | contains($monitor_name)) and .health == "up")' /tmp/observability-wave3-targets.json || exit 1
done
```

Expected: every integration has a healthy target.

- [ ] **Step 5: Enforce the 50 percent series-growth limit**

```bash
wave3_series_before=$(cat /tmp/observability-wave3-series-before)
wave3_series_after=$(curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=count({__name__=~".+"})' | jq -er '.data.result[0].value[1] | tonumber')
awk -v before="$wave3_series_before" -v after="$wave3_series_after" 'BEGIN { print "before=" before, "after=" after, "growth=" ((after-before)/before)*100 "%"; exit !(after <= before * 1.50) }'
```

Expected: exit status `0`.

- [ ] **Step 6: Verify rules and alert noise**

```bash
curl -fsS 'http://127.0.0.1:19090/api/v1/rules' | jq -e '[.data.groups[].rules[] | select(.health != "ok")] | length == 0'
curl -fsSG 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=ALERTS{alertstate="firing"}' | jq -c '[.data.result[].metric.alertname] | unique | sort' >/tmp/observability-wave3-alerts-after.json
jq -n --slurpfile before /tmp/observability-wave3-alerts-before.json --slurpfile after /tmp/observability-wave3-alerts-after.json '$after[0] - $before[0]'
```

Expected: every rule is healthy. Review the printed list of newly firing alerts; it must be empty or explicitly accepted before wave 4. If only Authentik rules are noisy, revert `prometheus.rules.enabled` while retaining both Authentik monitors.
