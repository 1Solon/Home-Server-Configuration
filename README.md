<div align="center">

<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.svg" alt="Kubernetes logo" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_GitOps-managed Kubernetes cluster running on Talos Linux with Flux CD and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub last commit](https://img.shields.io/github/last-commit/1Solon/Home-Server-Configuration?style=for-the-badge)

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.36.4-blue?style=for-the-badge&logo=kubernetes)
![Talos](https://img.shields.io/badge/talos-v1.13.9-blue?style=for-the-badge&logo=talos)
![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?style=for-the-badge&logo=renovatebot)

</div>

## 🏗️ Architecture Overview

This is a **GitOps-managed Kubernetes home server** with the following stack:

- **Nodes**: 5-node hybrid cluster (4x ARM64, 1x x86_64)
- **OS**: Talos Linux v1.13.9 (immutable, API-configured)
- **Kubernetes**: v1.36.4
- **GitOps**: Flux CD manages all workloads from this repository
- **Storage**: Miroir for persistent volumes, CloudNativePG for PostgreSQL databases, Dragonfly for caching
- **Networking**: Cilium CNI, Envoy Gateway, Cloudflare DNS/DDNS, Tailscale VPN
- **Secrets**: SOPS with AGE encryption + 1Password via External Secrets Operator (mostly this, some former)

## 📂 Repository structure

Selective tree of the current Kubernetes categories and applications; nested implementation directories and most files are omitted. `archive/` contains historical manifests and is not reconciled by Flux.

```text
.
├── archive/                         # Historical, non-reconciled manifests
└── kubernetes/
    ├── ai/
    │   ├── firecrawl/
    │   ├── hermes/
    │   ├── llmkube/
    │   ├── openwebui/
    │   └── searxng/
    ├── books/
    │   ├── audiobookshelf/
    │   ├── bookorbit/
    │   ├── libation/
    │   ├── opds-proxy/
    │   ├── shelfmark/               # Shelfmark Lite image variant
    │   └── suwayomi/
    ├── components/                 # Reusable components consumed indirectly
    │   ├── kopiur/
    │   └── kopiur-standalone/
    ├── games/                      # Namespace only
    ├── infra/
    │   ├── descheduler/
    │   ├── flux/
    │   ├── node-feature-discovery/
    │   ├── nvidia-device-plugin/
    │   ├── reflector/
    │   ├── reloader/
    │   ├── spegel/
    │   └── tuppr/
    ├── media/
    │   ├── autobrr/
    │   ├── bazarr/
    │   ├── cleanuparr/
    │   ├── croc/
    │   ├── flaresolver/
    │   ├── jellyfin/
    │   ├── jellyseer/               # Seerr; historical directory name
    │   ├── prowlarr/
    │   ├── qbittorrent/
    │   ├── radarr/
    │   ├── recyclarr/
    │   └── sonarr/
    ├── misc/
    │   ├── immich/
    │   ├── sure/
    │   ├── syncthing/
    │   ├── tandoor/
    │   └── zerobyte/
    ├── networking/
    │   ├── cert-manager/
    │   ├── cilium/
    │   ├── envoy-gateway/
    │   ├── external-dns/
    │   └── tailscale/
    ├── observability/
    │   ├── exporters/
    │   ├── gatus/
    │   ├── grafana/
    │   ├── homepage/
    │   ├── karma/
    │   ├── kromgo/
    │   ├── kube-prometheus-stack/
    │   ├── metrics-server/
    │   ├── prometheus-adapter/
    │   ├── promxy/
    │   ├── silence-operator/
    │   └── victoria-logs/
    ├── projects/
    │   └── colwiki/                 # OtterWiki
    ├── security/
    │   ├── authentik/
    │   └── secrets/
    └── storage/
        ├── databases/
        │   ├── cloudnative-postgres/
        │   └── dragonfly/
        ├── garage/
        ├── kopiur/
        ├── miroir/
        └── snapshot-controller/
```

## 🖥️ Software

This inventory describes software configured in the repository, not verified live health. It includes principal applications, chart components, and support services, which do not always have their own directories; it is not an exhaustive list of transitive dependencies.

### Applications

| Software | Category | Purpose |
| --- | --- | --- |
| [Audiobookshelf](https://github.com/advplyr/audiobookshelf) | Books | Audiobook and podcast library server. |
| [BookOrbit](https://github.com/bookorbit/bookorbit) | Books | Ebook library management and reading. |
| [Libation](https://github.com/rmcrackan/Libation) | Books | Download and organize an Audible library. |
| [Kindle OPDS Proxy](https://github.com/chrisms150/kindle-opds-proxy) | Books | Kindle-friendly access to OPDS catalogs. |
| [Shelfmark Lite](https://github.com/calibrain/shelfmark) | Books | Book search and download interface using Shelfmark's Lite image variant. |
| [Suwayomi](https://github.com/Suwayomi/Suwayomi-Server) | Books | Manga reader server. |
| [Firecrawl](https://github.com/firecrawl/firecrawl) | AI | Web crawling and extraction for AI-ready content. |
| [Hermes](https://github.com/NousResearch/hermes-agent) | AI | Tool-using AI assistant with persistent memory. |
| [LLMKube](https://github.com/defilantech/LLMKube) | AI | Kubernetes operator for local LLM inference. |
| [Open WebUI](https://github.com/open-webui/open-webui) | AI | Web interface for AI models. |
| [SearXNG](https://github.com/searxng/searxng) | Search | Privacy-respecting metasearch engine. |
| [autobrr](https://github.com/autobrr/autobrr) | Media Automation | Automated release monitoring and download dispatch. |
| [Bazarr](https://github.com/morpheus65535/bazarr) | Media Automation | Subtitle management for movies and TV shows. |
| [Cleanuparr](https://github.com/Cleanuparr/Cleanuparr) | Media Automation | Queue and download cleanup for \*arr apps and download clients. |
| [croc](https://github.com/schollz/croc) | File Transfer | Encrypted file transfer with a self-hosted relay. |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr) | Media Automation | Proxy for handling Cloudflare challenges. |
| [Jellyfin](https://jellyfin.org) | Media | Media server for movies, TV shows, and music. |
| [Seerr](https://github.com/seerr-team/seerr) | Media | Media discovery and request management; manifests remain in `media/jellyseer`. |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr) | Media Automation | Indexer manager and proxy. |
| [qBittorrent](https://www.qbittorrent.org) | Media Automation | BitTorrent client with a web interface. |
| [Radarr](https://radarr.video) | Media Automation | Automated movie download and management. |
| [Recyclarr](https://github.com/recyclarr/recyclarr) | Media Automation | Quality profile and custom format synchronization for \*arr apps. |
| [Sonarr](https://sonarr.tv) | Media Automation | Automated TV show download and management. |
| [Homepage](https://github.com/gethomepage/homepage) | Dashboard | Customizable dashboard for services. |
| [Immich](https://immich.app) | Photos | Self-hosted photo and video backup and management. |
| [OtterWiki](https://github.com/redimp/otterwiki) | Wiki | Git-backed wiki; manifests live in `projects/colwiki`. |
| [Sure](https://github.com/we-promise/sure) | Finance | Personal finance and account tracking. |
| [Syncthing](https://syncthing.net) | Files | Continuous file synchronization. |
| [Tandoor](https://github.com/TandoorRecipes/recipes) | Recipes | Recipe management and meal planning. |
| [Zerobyte](https://github.com/nicotsx/zerobyte) | Backups | Web-based backup management. |

### Infrastructure

| Software | Category | Purpose |
| --- | --- | --- |
| [Flux CD](https://fluxcd.io) | GitOps | Continuous delivery for Kubernetes. |
| [Descheduler](https://github.com/kubernetes-sigs/descheduler) | Node Management | Evicts pods according to policies so they can be rescheduled. |
| [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery) | Node Management | Detects and labels node hardware features. |
| [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin) | Node Management | Exposes NVIDIA GPUs to Kubernetes workloads. |
| [Reflector](https://github.com/emberstack/kubernetes-reflector) | Configuration | Mirrors ConfigMaps and Secrets across namespaces. |
| [Reloader](https://github.com/stakater/Reloader) | Configuration | Triggers workload restarts on ConfigMap and Secret changes. |
| [Spegel](https://github.com/spegel-org/spegel) | Images | Stateless cluster-local OCI registry mirror. |
| [Tuppr](https://github.com/home-operations/tuppr) | Upgrades | Coordinates Talos Linux and Kubernetes upgrades. |
| [Cert-Manager](https://cert-manager.io) | Networking | Automated certificate management. |
| [Cilium](https://cilium.io) | Networking | eBPF-based networking, security, and observability. |
| [Envoy Gateway](https://gateway.envoyproxy.io) | Networking | Kubernetes-native gateway powered by Envoy. |
| [External DNS](https://github.com/kubernetes-sigs/external-dns) | Networking | Synchronizes Kubernetes resources with DNS providers. |
| [Cloudflare DDNS](https://github.com/favonia/cloudflare-ddns) | Networking | Updates Cloudflare DNS records when public IP addresses change. |
| [Tailscale](https://tailscale.com) | Networking | WireGuard-based VPN connectivity. |
| [Authentik](https://goauthentik.io) | Security | Identity provider for SSO and authentication. |
| [External Secrets Operator](https://external-secrets.io) | Security | Synchronizes external secret stores into Kubernetes Secrets. |
| [1Password Connect](https://github.com/1Password/connect) | Security | API access to 1Password vault secrets for integrations. |
| [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg) | Storage | PostgreSQL operator for Kubernetes. |
| [Dragonfly](https://dragonflydb.io) | Storage | Redis/Memcached-compatible in-memory datastore. |
| [Garage](https://garagehq.deuxfleurs.fr) | Storage | Distributed S3-compatible object storage. |
| [Miroir](https://github.com/home-operations/miroir) | Storage | Replicated block storage for Kubernetes. |
| [Kopiur](https://github.com/home-operations/kopiur) | Backups | Kubernetes volume backup and restore orchestration. |
| [CSI Snapshot Controller](https://github.com/kubernetes-csi/external-snapshotter) | Storage | Manages Kubernetes volume snapshot resources. |

### Observability

The kube-prometheus-stack deployment uses the **Prom++** image. Its bundled Grafana is disabled; a separate **Grafana Operator** manages the Grafana instance.

| Software | Purpose |
| --- | --- |
| [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | Monitoring operators, Alertmanager, rules, and bundled metrics exporters. |
| [Prom++](https://github.com/deckhouse/prompp) | Prometheus-compatible metrics collection and storage. |
| [Grafana](https://github.com/grafana/grafana) / [Grafana Operator](https://github.com/grafana/grafana-operator) | Dashboards and visualization with operator-managed configuration. |
| [Grafana MCP](https://github.com/grafana/mcp-grafana) | MCP access to Grafana for AI tools. |
| [VictoriaLogs](https://github.com/VictoriaMetrics/VictoriaLogs) / [collector](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-logs-collector) | Centralized log storage, querying, and cluster log collection. |
| [Gatus](https://github.com/TwiN/gatus) | Endpoint health checks and status reporting. |
| [Karma](https://github.com/prymitive/karma) | Alertmanager dashboard. |
| [Kromgo](https://github.com/home-operations/kromgo) | Exposes selected Prometheus metrics through an HTTP API. |
| [promxy](https://github.com/jacksontj/promxy) | Unified query proxy across Prometheus-compatible backends. |
| [Prometheus Adapter](https://github.com/kubernetes-sigs/prometheus-adapter) | Exposes Prometheus metrics through Kubernetes metrics APIs for autoscaling. |
| [Silence Operator](https://github.com/giantswarm/silence-operator) | Declarative Alertmanager silence management. |
| [Metrics Server](https://github.com/kubernetes-sigs/metrics-server) | Resource usage metrics for Kubernetes. |
| [Kube State Metrics](https://github.com/kubernetes/kube-state-metrics) | Kubernetes object metrics; bundled with kube-prometheus-stack. |
| [Node Exporter](https://github.com/prometheus/node_exporter) | Hardware and OS metrics; bundled with kube-prometheus-stack. |
| [NVIDIA DCGM Exporter](https://github.com/NVIDIA/dcgm-exporter) | NVIDIA GPU telemetry. |
| [smartctl Exporter](https://github.com/prometheus-community/smartctl_exporter) | Disk health and SMART metrics. |
| [Speedtest Exporter](https://github.com/MiguelNdeCarvalho/speedtest-exporter) | Internet connection throughput and latency metrics. |

## 📦 Hardware

| Device                                                                                       | Count | OS Disk Size | Data Disk Size | Ram  | Operating System | Purpose             |
| -------------------------------------------------------------------------------------------- | ----- | ------------ | -------------- | ---- | ---------------- | ------------------- |
| [Turing RK1](https://turingpi.com/product/turing-rk1/?attribute_ram=16+GB)                   | 4     | 2TB NVMe     | -              | 16GB | Talos v1.13.9    | ARM64 Cluster Nodes |
| [Turing Pi 2](https://turingpi.com/product/turing-pi-2-5/)                                   | 1     | -            | -              | -    | -                | Baseboard and KVM   |
| [CWWK AMD-7940HS](https://www.amazon.com/CWWK-NAS-display-network-motherboard/dp/B0D5M2M3Y5) | 1     | 1TB NVMe     | 8TB HDD (2x)   | 32GB | Talos v1.13.9    | x86_64 Cluster Node |
