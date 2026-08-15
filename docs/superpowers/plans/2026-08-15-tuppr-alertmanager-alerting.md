# Tuppr Alertmanager Alerting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Tuppr's bundled operational alerts so Prometheus forwards them to the existing Alertmanager and Discord receiver.

**Architecture:** The Tuppr Helm chart already exposes metrics through its enabled `ServiceMonitor` and contains a disabled `PrometheusRule`. Enable that chart resource in the existing `HelmRelease`; do not enable Tuppr's direct Apprise notifier or add notification credentials.

**Tech Stack:** Flux HelmRelease, Helm 3, Tuppr chart 0.5.0, Prometheus Operator, Alertmanager, Kustomize

## Global Constraints

- Keep Tuppr's direct `notification` integration disabled.
- Reuse the existing Prometheus, Alertmanager, and Discord receiver path without changing credentials, Secrets, ExternalSecrets, or receiver configuration.
- Preserve the enabled Tuppr `ServiceMonitor`.
- Do not push the repository; pushing triggers Flux reconciliation and requires explicit permission.

---

### Task 1: Enable and verify the bundled Tuppr alert rules

**Files:**

- Modify: `kubernetes/infra/tuppr/app/release.yaml`
- Test: Helm render and Kustomize build commands against `kubernetes/infra/tuppr/app/release.yaml`

**Interfaces:**

- Consumes: Tuppr chart 0.5.0 metrics, the existing Prometheus Operator, and the existing Alertmanager route.
- Produces: A `PrometheusRule` named `tuppr` in `kube-system`; no new Secret or direct notification configuration.

- [ ] **Step 1: Run the render assertion and verify the desired resource is currently absent**

```bash
helm template tuppr oci://ghcr.io/home-operations/charts/tuppr \
  --version 0.5.0 \
  --namespace kube-system \
  --values <(awk '/^  values:/{found=1; next} found {sub(/^    /, ""); print}' \
    kubernetes/infra/tuppr/app/release.yaml) \
  | awk '$1 == "kind:" && $2 == "PrometheusRule" { found=1 } END { exit !found }'
```

Expected: exit status `1`, because the repository values do not yet render a `PrometheusRule`.

- [ ] **Step 2: Enable the bundled PrometheusRule**

Update the existing monitoring values in `kubernetes/infra/tuppr/app/release.yaml` to exactly:

```yaml
    monitoring:
      serviceMonitor:
        enabled: true
      prometheusRule:
        enabled: true
```

- [ ] **Step 3: Render the chart and verify both monitoring resources are present**

```bash
helm template tuppr oci://ghcr.io/home-operations/charts/tuppr \
  --version 0.5.0 \
  --namespace kube-system \
  --values <(awk '/^  values:/{found=1; next} found {sub(/^    /, ""); print}' \
    kubernetes/infra/tuppr/app/release.yaml) \
  | awk '
      $1 == "kind:" && $2 == "ServiceMonitor" { service_monitor=1 }
      $1 == "kind:" && $2 == "PrometheusRule" { prometheus_rule=1 }
      END { exit !(service_monitor && prometheus_rule) }
    '
```

Expected: exit status `0`.

- [ ] **Step 4: Validate the Kustomization and review the complete implementation diff**

```bash
kustomize build kubernetes/infra/tuppr/app >/dev/null
git diff --check
git diff -- kubernetes/infra/tuppr/app/release.yaml
```

Expected: both validation commands exit `0`; the displayed diff contains only `monitoring.prometheusRule.enabled: true` and does not add `notification`, Secret, ExternalSecret, or Alertmanager changes.

- [ ] **Step 5: Commit the implementation**

```bash
git add kubernetes/infra/tuppr/app/release.yaml
git commit -m "feat(tuppr): enable Alertmanager alerts"
```

Expected: one implementation commit containing only the Tuppr `HelmRelease` change. Do not push it.
