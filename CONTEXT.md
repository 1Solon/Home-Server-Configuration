# Home Server

This repository declaratively defines the applications and infrastructure operated by the home server cluster.

## Observability

**Metrics Production**:
The ability of a workload to expose Prometheus-format metrics, either natively or through an exporter. This does not imply that Prometheus discovers or scrapes them.
_Avoid_: Exporter enabled

**Exporter**:
A dedicated process that obtains telemetry from another system and translates or exposes it as Prometheus metrics. A workload's native metrics endpoint is not an exporter.
_Avoid_: Metrics endpoint, ServiceMonitor

**Scrape Coverage**:
The Prometheus discovery and configuration needed to select and scrape a metrics endpoint. An exposed endpoint without a matching monitor or scrape configuration lacks scrape coverage.
_Avoid_: Exporter, Metrics production

**Dashboard Provisioning**:
Importing a dashboard into the managed Grafana instance through a provisioning mechanism it consumes. Rendering an unconsumed dashboard ConfigMap is not dashboard provisioning.
_Avoid_: Dashboard enabled

**Enabled Observability Integration**:
An observability integration whose declarative resources reconcile successfully and whose live metrics targets or dashboard queries return data. Manifest configuration alone does not establish that an integration is enabled.
_Avoid_: Configured integration

**Eligible Observability Asset**:
A chart-bundled integration or an operationally valuable first-party asset selected for deployment. Example-only dashboards and optional telemetry without a concrete use case are not eligible by default.
_Avoid_: Available integration
