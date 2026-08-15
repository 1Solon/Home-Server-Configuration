# Tuppr Alertmanager Alerting Design

**Date:** 2026-08-15

## Goal

Report actionable Tuppr upgrade and controller problems through the cluster's
existing Prometheus and Alertmanager pipeline. Alertmanager will continue to
deliver notifications to Discord using its existing receiver and credentials.

## Design

Enable the `PrometheusRule` bundled with the deployed Tuppr 0.5.0 Helm chart by
setting `monitoring.prometheusRule.enabled: true` in the Tuppr `HelmRelease`.
The existing Tuppr `ServiceMonitor` remains enabled so Prometheus can scrape the
metrics used by those rules.

Keep Tuppr's direct `notification` integration disabled. This avoids creating a
second Discord secret, converting the Discord webhook into Apprise syntax, or
bypassing Alertmanager's routing, grouping, inhibition, and resolved-message
handling.

The resulting data flow is:

```text
Tuppr metrics -> PrometheusRule evaluation -> Alertmanager -> existing Discord receiver
```

No Alertmanager receiver, Discord credential, or 1Password item changes are
needed.

## Alert Coverage

The bundled rules cover:

- failed Talos nodes and failed Talos upgrade resources;
- stuck Talos upgrades;
- failed or stuck Kubernetes upgrades;
- upgrades blocked on dependencies or suspension;
- upgrade jobs running longer than expected;
- a missing Tuppr operator; and
- repeated upgrade failures.

These are state-based operational alerts, not informational notifications for
every upgrade start. Warning and critical alerts will follow the existing
Alertmanager route to Discord, and resolved notifications will use the existing
receiver setting.

## Failure Handling

If Prometheus cannot scrape Tuppr, the bundled `TupprOperatorAbsent` alert fires
after five minutes. If Alertmanager or Discord delivery is impaired, existing
monitoring behavior applies; Tuppr itself does not gain a separate notification
path or credential dependency.

## Verification

Render the Tuppr Helm chart at version 0.5.0 with the repository values and
verify that it produces both the existing `ServiceMonitor` and the bundled
`PrometheusRule`. Validate the repository Kustomization and inspect the diff to
confirm that no direct-notification settings, secrets, or Alertmanager receiver
configuration were added or changed.
