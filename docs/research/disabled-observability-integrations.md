# Disabled Prometheus and Grafana integrations

_Audit date: 2026-08-21_

_Corrections from live validation: Immich used obsolete `IMMICH_METRICS_INCLUDE` instead of `IMMICH_TELEMETRY_INCLUDE`; Garage protects `/metrics` with the declaratively supplied `GARAGE_METRICS_TOKEN`; and VolSync had an undeclared live ServiceMonitor that its current Helm reconciliation does not recreate._

## Executive summary

This audit followed every active Kustomize resource from `kubernetes/kustomization.yaml`, followed the active Flux `Kustomization.spec.path` targets, and inspected all resulting Helm releases and relevant raw workloads. `archive/` and unreferenced directories were excluded.

I found **15 Prometheus integration gaps** (including native metrics endpoints that are exposed but not selected by a `ServiceMonitor`/`PodMonitor`) and **11 Grafana dashboard provisioning gaps**. The clearest fixes are Node Feature Discovery, ExternalDNS, Immich, Authentik, Flux Operator/controllers, and the broken/orphaned dashboard provisioning for Cilium, Spegel, and CloudNativePG.

Severity here is operational impact, not a security rating:

- **High**: important cluster/storage/network component has no useful scrape path, or a dashboard is configured but cannot be imported.
- **Medium**: application metrics/dashboard exists and would materially improve diagnosis.
- **Low**: optional or narrow-scope telemetry.

### Positive findings

| ID | Severity | Application | Prometheus gap | Grafana gap | Repository evidence |
|---|---|---|---|---|---|
| P1 / D1 | High | Cilium 1.20.1 | Agent metrics and its ServiceMonitor remain at chart defaults (`false`); operator metrics default on but its ServiceMonitor remains off. Hubble is disabled. | Agent and operator dashboards are set `enabled: true`, but the chart renders sidecar-labelled ConfigMaps. This repository runs Grafana Operator with no dashboard sidecar and has no `GrafanaDashboard` referring to the Cilium ConfigMaps, so they are rendered but not imported. | `kubernetes/networking/cilium/cilium/app/helm-values.yaml:23-28,48-50`; Grafana has only its application container at `kubernetes/observability/grafana/instance/app/grafana.yaml:25-67`. |
| P2 | High | Node Feature Discovery 0.19.0 | The chart's PodMonitor switch is explicitly disabled. | — | `kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml:9-12,39-40`. |
| P3 | Medium | ExternalDNS 1.21.1 | The chart's ServiceMonitor is explicitly disabled. | — | `kubernetes/networking/external-dns/cloudflare/app/release.yaml:9-12,50-51`. |
| P4 | High | Immich server v3.1.0 | Metrics Production is misconfigured with the obsolete `IMMICH_METRICS_INCLUDE` variable instead of `IMMICH_TELEMETRY_INCLUDE`; port 8081 is exposed, but the app-template ServiceMonitor block is also commented out. Live validation reproduced a connection refusal on the configured metrics endpoint. | No first-party Grafana dashboard was present at the pinned tag. | `kubernetes/misc/immich/app/server/release.yaml:36-43,93-108`. |
| P5 / D2 | High | Dragonfly operator v1.6.1 and Dragonfly v1.40.1 | The operator binds and exposes `:8080` metrics but defines no monitor. The Dragonfly CR also has no monitoring resource. | The first-party operator release contains both a ServiceMonitor template and a Grafana dashboard; neither is installed because this deployment uses generic app-template. | `kubernetes/storage/databases/dragonfly/app/release.yaml:33-40,86-92`; `kubernetes/storage/databases/dragonfly/cluster/cluster.yaml:3-24`. |
| P6 | High | Garage v2.3.0 | Garage's admin endpoint is exposed on 3903 and its first-party Prometheus dashboard is already declared, but no ServiceMonitor scrapes `/metrics`. The existing `GARAGE_METRICS_TOKEN` means the monitor must send bearer authorization; unauthenticated scraping returns HTTP 403. | Enabled: the Garage dashboard is declared; this row is a metrics-only gap. | `kubernetes/storage/garage/app/release.yaml:52-60,109-115`; token declaration at `kubernetes/storage/garage/app/externalsecret.yaml:14-16`; dashboard at `kubernetes/observability/kube-prometheus-stack/app/grafanadashboard.yaml:139-155`. |
| P7 / D3 | Medium | promxy 0.0.96 | The only Service exposes port 8082; no ServiceMonitor is rendered even though promxy registers `/metrics`. | The pinned first-party source contains `grafana.dashboard`, but it is not referenced by the active Kustomization. | `kubernetes/observability/promxy/app/helmrelease.yaml:29-35,55-59`; `kubernetes/observability/promxy/app/kustomization.yaml:5-10`. |
| P8 | Medium | Kromgo v0.10.0 | The health Service port 8080 serves `/metrics` in the pinned source, but there is no ServiceMonitor. | — | `kubernetes/observability/kromgo/app/helmrelease.yaml:29-38,80-86`. |
| P9 / D4 | High | Flux Operator 0.58.1 and Flux controllers 2.9.4 | The operator chart defaults `serviceMonitor.create` to false and the release supplies no override. The Flux controller metrics endpoints likewise have no active monitor. | The pinned Flux Operator source ships two Flux performance dashboards, neither installed here. | `kubernetes/infra/flux/operator/release.yaml:13-34`; `kubernetes/infra/flux/instance/instance.yaml:8-29`; active kube-prometheus dashboards contain no Flux dashboard (`kubernetes/observability/kube-prometheus-stack/app/grafanadashboard.yaml`). |
| P10 | Medium | Stakater Reloader chart 2.2.16 | Both chart monitor choices default off; this release only sets the reload strategy. | — | `kubernetes/infra/reloader/reloader/app/release.yaml:10-16,28-31`. |
| P11 | High | Authentik chart 2026.8.0 | Both server and worker expose first-party metrics capability, but each metrics Service and ServiceMonitor defaults off and neither is overridden. | No bundled first-party dashboard was found in the pinned Helm source. | `kubernetes/security/authentik/authentik/app/release.yaml:19-22,35-90`. |
| P12 | Medium | VolSync 0.16.0 | The metrics endpoint is deliberately made unauthenticated, but there is no declarative ServiceMonitor in this repository. Wave 3 validation found an undeclared live ServiceMonitor; deleting it and reconciling the current Helm release did not recreate it, confirming that the resource must be adopted declaratively. | — | `kubernetes/storage/volsync/volsync/app/release.yaml:9-12,25-30`. |
| P13 | Medium | cert-manager v1.21.1 | Metrics are enabled by chart default, but both PodMonitor and ServiceMonitor default off. The local values only configure CRDs/replicas/DNS and do not override either monitor. Prometheus Operator does not scrape annotation-only targets without a scrape configuration. | — | `kubernetes/networking/cert-manager/cert-manager/app/release.yaml:9-16`; `kubernetes/networking/cert-manager/cert-manager/app/helm/values.yaml:1-6`; no additional annotation scrape job is configured in `kubernetes/observability/kube-prometheus-stack/app/helmrelease.yaml:115-153`. |
| P14 | Low | Tailscale Connector / operator 1.102.3 | Tailscale supports opt-in proxy metrics and can create its own ServiceMonitor through a `ProxyClass`; this Connector has neither a ProxyClass nor metrics configuration. This is proxy telemetry, **not** operator self-metrics. | — | `kubernetes/networking/tailscale/tailscale/config/subnet-router.yaml:2-12`. |
| P15 | Low | CSI snapshot-controller v8.5.0 image / v8.6.0 manifests | The controller supports a Prometheus HTTP endpoint, but the upstream deployment used here does not pass `--http-endpoint` and no monitor is added locally. | — | `kubernetes/storage/snapshot-controller/install.yaml:6-11,33-59`. |
| D5 | High | CloudNativePG chart 0.29.0 | Metrics are enabled for operator and clusters. | Dashboard creation is enabled, but the chart renders ConfigMap `cnpg-grafana-dashboard` key `cnp.json`; the local `GrafanaDashboard` points to `cloudnative-pg-dashboard` key `cloudnative-pg.json`, so the import reference cannot resolve. | `kubernetes/storage/databases/cloudnative-postgres/app/release.yaml:27-34`; `kubernetes/storage/databases/cloudnative-postgres/cluster/grafanadashboard.yaml:3-17`. |
| D6 | High | Spegel 0.7.4 | ServiceMonitor is enabled. | Dashboard is enabled without changing the chart's default `mode: Sidecar`; the render is a `spegel-dashboard` ConfigMap, while this Grafana deployment has no sidecar and no matching `GrafanaDashboard` CR. | `kubernetes/infra/spegel/app/release.yaml:26-34`; Grafana deployment evidence as in D1. |
| D7 | Medium | Tuppr 0.5.0 | ServiceMonitor and PrometheusRule are enabled. | The same chart has a bundled dashboard and Grafana Operator mode, but `monitoring.dashboards.enabled` remains omitted/default false. | `kubernetes/infra/tuppr/app/release.yaml:37-43`. |
| D8 | Medium | External Secrets 2.9.0 | All three ServiceMonitors are enabled. | The chart-bundled dashboard remains default-disabled because no `grafanaDashboard` override is present. | `kubernetes/security/secrets/external-secrets/app/release.yaml:27-45`. |
| D9 | Medium | NVIDIA DCGM Exporter chart 4.8.3 | ServiceMonitor is enabled. | NVIDIA ships a first-party DCGM Grafana dashboard, but the active app Kustomization contains only the release. | `kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/release.yaml:9-12,28-31`; `kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/kustomization.yaml:3-6`. |
| D10 | Medium | Envoy Gateway v1.9.0 | Both Envoy proxy and gateway metrics are wired by local PodMonitor/ServiceMonitor resources. | Envoy Gateway's first-party addons chart supplies several dashboards, but the active config only installs `envoy.yaml` and `observability.yaml`. | `kubernetes/networking/envoy-gateway/config/observability.yaml:3-38`; `kubernetes/networking/envoy-gateway/config/kustomization.yaml:3-7`. |
| D11 | Low | Gatus v5.36.0 | Metrics and a ServiceMonitor are enabled. | The first-party Gatus example dashboard is not installed; the two active local dashboards are UPS-specific (`ups-aggregate` and `ups-status`), not the project dashboard. | `kubernetes/observability/gatus/app/resources/config.yaml:1-4`; `kubernetes/observability/gatus/app/helmrelease.yaml:136-141`; `kubernetes/observability/gatus/app/grafanadashboard.yaml:3-33`. |

> Numbering has 15 Prometheus gaps (`P1`–`P15`) and 11 dashboard observations (`D1`–`D11`). D1 and D6 are especially important: their Helm values say “enabled,” but the selected provisioning mode is not consumed, so the dashboards are still not installed in Grafana.

## Primary-source verification

The following are version-matched first-party sources used for the findings above. Chart defaults were also checked directly with `helm show values` for the pinned versions.

- **NFD 0.19.0:** the chart describes `prometheus.enable` as creation of the PodMonitor and defaults it to false: [values.yaml lines 1250-1258](https://github.com/kubernetes-sigs/node-feature-discovery/blob/45d276ed9d3f0f67fb642aa78969721df3034451/deployment/helm/node-feature-discovery/values.yaml#L1250-L1258).
- **Cilium 1.20.1:** agent metrics and monitor defaults are false ([lines 2653-2662](https://github.com/cilium/cilium/blob/7d68cfb394f2960e10aa72e76d0d51e66c1b2ebc/install/kubernetes/cilium/values.yaml#L2653-L2662)); operator metrics default on but its monitor off ([lines 3396-3406](https://github.com/cilium/cilium/blob/7d68cfb394f2960e10aa72e76d0d51e66c1b2ebc/install/kubernetes/cilium/values.yaml#L3396-L3406)); dashboard output is documented as sidecar-based ([lines 2708-2717](https://github.com/cilium/cilium/blob/7d68cfb394f2960e10aa72e76d0d51e66c1b2ebc/install/kubernetes/cilium/values.yaml#L2708-L2717)).
- **ExternalDNS chart 1.21.1:** ServiceMonitor default false: [values.yaml lines 173-181](https://github.com/kubernetes-sigs/external-dns/blob/9f26451346774099a8b3e3e5cc46a53bf2fd1461/charts/external-dns/values.yaml#L173-L181).
- **cert-manager v1.21.1:** metrics default on, both operator monitors default off: [values.yaml lines 647-706](https://github.com/cert-manager/cert-manager/blob/24e33194fb39488eff2bbf10c6dc640f407cad44/deploy/charts/cert-manager/values.yaml#L647-L706).
- **Immich v3.1.0:** first-party monitoring documentation requires `IMMICH_TELEMETRY_INCLUDE` to enable Metrics Production and documents API metrics on port 8081: [monitoring.md](https://github.com/immich-app/immich/blob/8aa95c67470a02a8ddedf03c2e52963af33065ff/docs/docs/features/monitoring.md).
- **Dragonfly operator v1.6.1:** first-party chart has a [ServiceMonitor template](https://github.com/dragonflydb/dragonfly-operator/blob/b28637d78d828f80a3b3fd76acaa2dd6e3c28603/charts/dragonfly-operator/templates/servicemonitor.yaml), [GrafanaDashboard template](https://github.com/dragonflydb/dragonfly-operator/blob/b28637d78d828f80a3b3fd76acaa2dd6e3c28603/charts/dragonfly-operator/templates/grafanadashboards.yaml), and [dashboard JSON](https://github.com/dragonflydb/dragonfly-operator/blob/b28637d78d828f80a3b3fd76acaa2dd6e3c28603/charts/dragonfly-operator/dashboards/grafana-dashboard.json).
- **Garage v2.3.0:** first-party [monitoring documentation](https://garagehq.deuxfleurs.fr/documentation/cookbook/monitoring/) documents `/metrics` on the admin listener and bearer authorization when `metrics_token` is configured. Telemetry assets include the [Prometheus Grafana dashboard](https://github.com/Deuxfleurs-org/garage/blob/7b119c0b4fa58ab3cb6d5db435fe52d990f6a7aa/script/telemetry/grafana-garage-dashboard-prometheus.json) and metrics implementation, for example [system_metrics.rs](https://github.com/Deuxfleurs-org/garage/blob/7b119c0b4fa58ab3cb6d5db435fe52d990f6a7aa/src/rpc/system_metrics.rs).
- **promxy 0.0.96:** the pinned source registers Prometheus handling in [cmd/promxy/main.go](https://github.com/jacksontj/promxy/blob/b39a64dc03436e2a43e8d7b11c5363a2ab23ba20/cmd/promxy/main.go) and includes [grafana.dashboard](https://github.com/jacksontj/promxy/blob/b39a64dc03436e2a43e8d7b11c5363a2ab23ba20/grafana.dashboard).
- **Kromgo v0.10.0:** its first-party server wires `/metrics` to `promhttp.Handler`: [server.go](https://github.com/kashalls/kromgo/blob/60f84f338c012b063b34fa534070ca51c08fb204/cmd/kromgo/init/server/server.go).
- **Flux Operator 0.58.1:** the pinned chart artifact is [`oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator:0.58.1`](https://github.com/controlplaneio-fluxcd/charts/pkgs/container/charts%2Fflux-operator); its `serviceMonitor.create` default is false. The version-matched operator source supplies [Flux performance](https://github.com/controlplaneio-fluxcd/flux-operator/blob/b3b36020aca1f8d2172c76949c0bcb6bbf688dde/config/monitoring/dashboards/flux-performance.json) and [Kubernetes API performance](https://github.com/controlplaneio-fluxcd/flux-operator/blob/b3b36020aca1f8d2172c76949c0bcb6bbf688dde/config/monitoring/dashboards/flux-k8s-api-performance.json) dashboards.
- **Reloader chart 2.2.16 / app v1.4.7:** ServiceMonitor and PodMonitor both default false: [values.yaml lines 211-264](https://github.com/stakater/Reloader/blob/ca0a22e87b5db052bf6273ed464b137614b24625/deployments/kubernetes/chart/reloader/values.yaml#L211-L264).
- **Authentik chart 2026.8.0:** server metrics Service/monitor defaults are false ([lines 541-560](https://github.com/goauthentik/helm/blob/4b4cf01d6248d985441d29d727c9f26c88d9b8ca/charts/authentik/values.yaml#L541-L560)); worker equivalents are also false ([lines 936-955](https://github.com/goauthentik/helm/blob/4b4cf01d6248d985441d29d727c9f26c88d9b8ca/charts/authentik/values.yaml#L936-L955)).
- **VolSync v0.16.0:** first-party metrics documentation states that VolSync exports Prometheus metrics and shows the endpoint and monitor setup: [metrics documentation](https://github.com/backube/volsync/blob/22b97b0717c74f328853d92877151392ff5ecb42/docs/usage/metrics/index.rst#L1-L94).
- **Tailscale 1.102.3:** proxy metrics and generated ServiceMonitor are guarded by `ProxyClass.spec.metrics.enable` and `serviceMonitor.enable`: [metrics_resources.go](https://github.com/tailscale/tailscale/blob/53a0d659afa51835dd7a9283873cca44261454f8/cmd/k8s-operator/metrics_resources.go#L87-L150).
- **CSI snapshot-controller:** first-party controller source exposes the opt-in HTTP metrics endpoint: [snapshot-controller main.go at the manifest tag](https://github.com/kubernetes-csi/external-snapshotter/blob/v8.6.0/cmd/snapshot-controller/main.go); the deployed manifest omits the flag: [upstream setup manifest](https://github.com/kubernetes-csi/external-snapshotter/blob/v8.6.0/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml).
- **CloudNativePG chart 0.29.0:** chart default names are documented in its [values.yaml](https://github.com/cloudnative-pg/charts/blob/cloudnative-pg-v0.29.0/charts/cloudnative-pg/values.yaml); a version-matched `helm template` rendered `cnpg-grafana-dashboard` / `cnp.json`.
- **Spegel 0.7.4:** dashboard default mode is `Sidecar`, not Grafana Operator: [values.yaml lines 129-145](https://github.com/spegel-org/spegel/blob/79779e2683ef80a588da97c18423bc45a9415369/charts/spegel/values.yaml#L129-L145).
- **Tuppr 0.5.0:** bundled dashboard and Grafana Operator switches both default false: [values.yaml lines 234-255](https://github.com/home-operations/tuppr/blob/6da4415f140bfee9b17667b532b45e09f50fabf6/charts/tuppr/values.yaml#L234-L255).
- **External Secrets chart 2.9.0:** chart-bundled dashboard default false: [values.yaml lines 371-387](https://github.com/external-secrets/external-secrets/blob/cc5bfbc2234ace9cb0caff4ea89c435cf517b27b/deploy/charts/external-secrets/values.yaml#L371-L387); the JSON is first-party: [grafana-dashboard.json](https://github.com/external-secrets/external-secrets/blob/cc5bfbc2234ace9cb0caff4ea89c435cf517b27b/deploy/charts/external-secrets/files/monitoring/grafana-dashboard.json).
- **NVIDIA DCGM Exporter chart 4.8.3 / exporter 4.6.0:** first-party dashboard: [dcgm-exporter-dashboard.json](https://github.com/NVIDIA/dcgm-exporter/blob/181290c399d46a9b905e083d0204348be63cb436/grafana/dcgm-exporter-dashboard.json).
- **Envoy Gateway v1.9.0:** first-party Grafana integration is supplied by its addons chart, including [Envoy Gateway](https://github.com/envoyproxy/gateway/blob/39763b1c07ec30a5526fe70434a2cfe4181de642/charts/gateway-addons-helm/dashboards/envoy-gateway-global.json) and [Envoy proxy](https://github.com/envoyproxy/gateway/blob/39763b1c07ec30a5526fe70434a2cfe4181de642/charts/gateway-addons-helm/dashboards/envoy-proxy-global.json) dashboards.
- **Gatus v5.36.0:** first-party example dashboard: [gatus.json](https://github.com/TwiN/gatus/blob/ed1107b41a30e22047eecfb6dbc3be5e39829d5a/.examples/docker-compose-grafana-prometheus/grafana/provisioning/dashboards/gatus.json).

## Complete active coverage

“None identified” means the version-matched chart/project did not expose a first-party Prometheus exporter/monitor switch or bundled/first-party Grafana dashboard during this audit. It does **not** mean that no third-party exporter or community Grafana.com dashboard exists. Community-only dashboards and unrelated web UI “dashboards” were intentionally excluded.

| Area | Active app/component (pin) | Result | Active manifest |
|---|---|---|---|
| AI | Hermes Agent v2026.8.18 | None identified | `kubernetes/ai/hermes/app/release.yaml` |
| AI | LLMKube 0.9.19 | Metrics, ServiceMonitor, inference PodMonitor, rules, and first-party dashboard enabled | `kubernetes/ai/llmkube/app/release.yaml`; `grafanadashboard.yaml` |
| AI | Open WebUI v0.11.0 | No Prometheus-native exporter/dashboard identified (OTel is a different integration) | `kubernetes/ai/openwebui/app/release.yaml` |
| AI | SearXNG build 2025.5.17 | None identified | `kubernetes/ai/searxng/app/release.yaml` |
| Books | Audiobookshelf 2.36.0 | None identified | `kubernetes/books/audiobookshelf/app/release.yaml` |
| Books | BookOrbit 2.6.0 | None identified | `kubernetes/books/bookorbit/app/release.yaml` |
| Books | Libation 13.7.10 | None identified | `kubernetes/books/libation/app/release.yaml` |
| Books | Kindle OPDS proxy 0.1.0 | None identified | `kubernetes/books/opds-proxy/app/release.yaml` |
| Books | Shelfmark Lite 1.3.10 | None identified | `kubernetes/books/shelfmark/app/release.yaml` |
| Books | Suwayomi 2.3.2333 | None identified | `kubernetes/books/suwayomi/app/release.yaml` |
| Infra | Flux Operator 0.58.1 + Flux 2.9.4 | **P9, D4** | `kubernetes/infra/flux/operator/release.yaml`; `instance/instance.yaml` |
| Infra | Descheduler 0.36.0 | ServiceMonitor enabled; no first-party dashboard found | `kubernetes/infra/descheduler/app/release.yaml` |
| Infra | Node Feature Discovery 0.19.0 | **P2** | `kubernetes/infra/node-feature-discovery/node-feature-discovery/app/release.yaml` |
| Infra | NVIDIA device plugin 0.20.0 | No exporter in device-plugin chart; dedicated DCGM exporter is deployed | `kubernetes/infra/nvidia-device-plugin/nvidia-device-plugin/app/release.yaml` |
| Infra | DCGM Exporter chart 4.8.3 | Metrics enabled; **D9** | `kubernetes/infra/nvidia-device-plugin/dcgm-exporter/app/release.yaml` |
| Infra | Reflector 10.0.65 | None identified | `kubernetes/infra/reflector/reflector/app/release.yaml` |
| Infra | Reloader 2.2.16 | **P10** | `kubernetes/infra/reloader/reloader/app/release.yaml` |
| Infra | Spegel 0.7.4 | Metrics enabled; **D6** | `kubernetes/infra/spegel/app/release.yaml` |
| Infra | Tuppr 0.5.0 | Metrics/rules enabled; **D7** | `kubernetes/infra/tuppr/app/release.yaml` |
| Media | Autobrr 1.84.0 | Native metrics ServiceMonitor enabled; no first-party Grafana dashboard found | `kubernetes/media/autobrr/app/release.yaml` |
| Media | Bazarr 1.6.0 | Only third-party exporters identified; excluded | `kubernetes/media/bazarr/app/release.yaml` |
| Media | Cleanuparr 2.10.5 | None identified | `kubernetes/media/cleanuparr/app/release.yaml` |
| Media | Croc 11.2.4 | None identified | `kubernetes/media/croc/app/release.yaml` |
| Media | FlareSolverr (raw workload) | None identified | `kubernetes/media/flaresolver/app/` |
| Media | Jellyfin 10.11.11 | Prometheus support is plugin/community, not bundled first-party server integration; excluded | `kubernetes/media/jellyfin/app/release.yaml` |
| Media | Seerr 3.4.1 | None identified | `kubernetes/media/jellyseer/app/release.yaml` |
| Media | Prowlarr 2.6.1 | Only third-party exporters identified; excluded | `kubernetes/media/prowlarr/app/release.yaml` |
| Media | qBittorrent 5.2.3 + Qui 1.26.0 | Only third-party exporters identified; excluded | `kubernetes/media/qbittorrent/app/release.yaml`; `ui/release.yaml` |
| Media | Radarr 6.4.1 | Only third-party exporters identified; excluded | `kubernetes/media/radarr/app/release.yaml` |
| Media | Recyclarr 8.7.1 | None identified | `kubernetes/media/recyclarr/app/release.yaml` |
| Media | Sonarr 4.0.19 | Only third-party exporters identified; excluded | `kubernetes/media/sonarr/app/release.yaml` |
| Misc | Immich 3.1.0 (server, microservices, ML) | **P4** | `kubernetes/misc/immich/app/*/release.yaml` |
| Misc | Sure 0.7.4-alpha.1 + Redis 8.10.1 | No bundled exporter/dashboard; Redis exporter would be separate/third-party | `kubernetes/misc/sure/sure/app/release.yaml`; `redis.yaml` |
| Misc | Syncthing 2.1.3 | No daemon Prometheus integration/dashboard identified | `kubernetes/misc/syncthing/syncthing/app/release.yaml` |
| Misc | Tandoor 2.6.13 | None identified | `kubernetes/misc/tandoor/tandoor/app/release.yaml` |
| Misc | Zerobyte 0.41.0 | None identified | `kubernetes/misc/zerobyte/zerobyte/app/release.yaml` |
| Networking | cert-manager v1.21.1 | **P13** | `kubernetes/networking/cert-manager/cert-manager/app/release.yaml` |
| Networking | Cilium 1.20.1 | **P1, D1** | `kubernetes/networking/cilium/cilium/app/` |
| Networking | Envoy Gateway v1.9.0 | Metrics enabled; **D10** | `kubernetes/networking/envoy-gateway/app/release.yaml`; `config/observability.yaml` |
| Networking | ExternalDNS 1.21.1 | **P3** | `kubernetes/networking/external-dns/cloudflare/app/release.yaml` |
| Networking | Cloudflare DDNS 1.17.0 | None identified | `kubernetes/networking/external-dns/cloudflare-ddns/app/release.yaml` |
| Networking | Tailscale operator 1.102.3 + Connector | **P14** (proxy telemetry only) | `kubernetes/networking/tailscale/tailscale/` |
| Observability | smartctl exporter chart 0.17.1 | ServiceMonitor and dashboard enabled | `kubernetes/observability/exporters/smartctl-exporter/app/` |
| Observability | speedtest exporter 3.5.4 | Static ServiceMonitor, rule, and dashboard enabled | `kubernetes/observability/exporters/speedtest-exporter/app/` |
| Observability | Gatus 5.36.0 | Metrics/rules enabled; **D11** | `kubernetes/observability/gatus/app/` |
| Observability | Grafana Operator 5.24.0 + Grafana instance | Operator ServiceMonitor/dashboard enabled; Grafana static ServiceMonitor present | `kubernetes/observability/grafana/operator/app/`; `instance/app/` |
| Observability | Grafana MCP | No first-party Prometheus/dashboard integration identified | `kubernetes/observability/grafana/mcp/app/helmrelease.yaml` |
| Observability | Homepage 2.0.0 | None identified | `kubernetes/observability/homepage/app/release.yaml` |
| Observability | Karma 0.132 | Native `/metrics` ServiceMonitor enabled; no first-party dashboard found | `kubernetes/observability/karma/app/helmrelease.yaml` |
| Observability | Kromgo 0.10.0 | **P8** | `kubernetes/observability/kromgo/app/helmrelease.yaml` |
| Observability | kube-prometheus-stack 88.5.2 | Core monitoring and chart dashboards enabled through Grafana Operator integration | `kubernetes/observability/kube-prometheus-stack/app/` |
| Observability | metrics-server 3.14.0 | Metrics and ServiceMonitor enabled | `kubernetes/observability/metrics-server/app/helmrelease.yaml` |
| Observability | prometheus-adapter 5.3.0 | No chart monitor/dashboard toggle; secure apiserver self-metrics were not counted as a packaged disabled integration | `kubernetes/observability/prometheus-adapter/app/` |
| Observability | promxy 0.0.96 | **P7, D3** | `kubernetes/observability/promxy/app/` |
| Observability | Silence Operator 0.20.1 | PodMonitor enabled by chart default | `kubernetes/observability/silence-operator/app/helmrelease.yaml` |
| Observability | VictoriaLogs single 0.13.9 | ServiceMonitor and dashboards enabled | `kubernetes/observability/victoria-logs/app/helmrelease.yaml` |
| Observability | VictoriaLogs collector 0.3.7 | PodMonitor enabled | `kubernetes/observability/victoria-logs/collector/helmrelease.yaml` |
| Projects | OtterWiki 2.23.0 | None identified | `kubernetes/projects/colwiki/app/release.yaml` |
| Security | Authentik 2026.8.0 | **P11** | `kubernetes/security/authentik/authentik/app/release.yaml` |
| Security | External Secrets 2.9.0 | Metrics enabled; **D8** | `kubernetes/security/secrets/external-secrets/app/release.yaml` |
| Security | 1Password Connect 1.8.2 | No first-party Prometheus/dashboard integration identified | `kubernetes/security/secrets/external-secrets/stores/onepassword/release.yaml` |
| Storage | CloudNativePG operator 0.29.0 + two clusters | Metrics enabled; **D5** | `kubernetes/storage/databases/cloudnative-postgres/` |
| Storage | Dragonfly operator 1.6.1 + Dragonfly 1.40.1 | **P5, D2** | `kubernetes/storage/databases/dragonfly/` |
| Storage | Garage 2.3.0 + Garage Web UI 1.1.0 | **P6**; dashboard already declared | `kubernetes/storage/garage/` |
| Storage | Miroir 0.11.22 | PodMonitor, rules, and Grafana Operator dashboards enabled | `kubernetes/storage/miroir/miroir/app/release.yaml` |
| Storage | CSI snapshot-controller | **P15** | `kubernetes/storage/snapshot-controller/install.yaml` |
| Storage | VolSync 0.16.0 | **P12** | `kubernetes/storage/volsync/volsync/app/release.yaml` |

## Methodology and interpretation

1. Started at `kubernetes/kustomization.yaml` and recursively followed local `resources` entries.
2. Parsed active Flux `Kustomization` objects and followed each local `spec.path`. This captures app directories that are reconciled separately rather than directly composed by the root Kustomization.
3. Parsed every active `HelmRelease`, resolved `chart.spec.version` or the referenced `OCIRepository.spec.ref.tag`, and recorded app-template image tags.
4. Inspected local values, generated-monitor declarations, static `ServiceMonitor`/`PodMonitor` objects, `GrafanaDashboard` objects, and Grafana's deployment shape.
5. Compared non-generic chart values against the exact pinned chart (`helm show values`). For app-template deployments, inspected the pinned first-party application tag/source for metrics endpoints and first-party dashboards.
6. Rendered the exact CloudNativePG, Spegel, and Cilium charts to verify resource type/name/key and provisioning mode. This is how D1, D5, and D6 were distinguished from merely disabled values.
7. Counted a dashboard only when bundled by the pinned chart or stored/documented by the first-party project. A Grafana.com/community dashboard alone was not used as evidence that an app “provides” one.
8. Counted an exporter/metrics gap when the app/chart exposes a native Prometheus endpoint or operator monitor integration and no active scrape resource/config selects it. “Endpoint enabled” and “ServiceMonitor enabled” are deliberately separate states.

### Important caveats

- This is a declarative repository audit, not a live-cluster target-health check. It can prove what Flux should render, but not whether every current Prometheus target is `UP` or every Grafana import reconciled successfully.
- Dashboard D1/D6 conclusions assume the declarative Grafana pod shown in `grafana.yaml` is authoritative. It has no sidecar; if an out-of-band sidecar is injected live, Flux drift should be investigated.
- The snapshot-controller manifest tag is v8.6.0 while the local patch pins the controller image to v8.5.0. P15 is valid for both lines, but that version skew is separately worth reviewing.
- App-template 5.1.0 is a generic workload chart. Its ability to create a ServiceMonitor does not by itself mean every hosted app has Prometheus metrics; first-party app evidence was required before recording a gap.

## Suggested implementation order

1. Fix scrape coverage for P1-P5 and P9/P11/P13.
2. Convert Cilium and Spegel dashboards to `GrafanaOperator` mode (with `dashboards: grafana` selector and cross-namespace import), and correct the CloudNativePG ConfigMap name/key.
3. Enable chart-native dashboards for Tuppr and External Secrets.
4. Add first-party dashboard CRs for Dragonfly, DCGM, Envoy Gateway, Flux, promxy, and optionally Gatus.
5. Add monitors for Garage, Kromgo, VolSync, and the remaining low-priority integrations, then verify targets and dashboard queries in the live cluster.
