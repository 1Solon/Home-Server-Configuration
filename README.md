<div align="center">

<img src="https://raw.githubusercontent.com/auricom/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_GitOps-managed Kubernetes cluster running on Talos Linux with Flux CD and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub last commit](https://img.shields.io/github/last-commit/1Solon/Home-Server-Configuration?style=for-the-badge)

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.35.0-blue?style=for-the-badge&logo=kubernetes)
![Talos](https://img.shields.io/badge/talos-v1.12.1-blue?style=for-the-badge&logo=talos)
![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?style=for-the-badge&logo=renovatebot)

</div>

## 🏗️ Architecture Overview

This is a **GitOps-managed Kubernetes home server** with the following stack:

- **Nodes**: 5-node hybrid cluster (4x ARM64, 1x x86_64)
- **OS**: Talos Linux v1.12.1 (immutable, API-configured)
- **Kubernetes**: v1.35.0
- **GitOps**: Flux CD manages all workloads from this repository
- **Storage**: Longhorn for persistent volumes, Crunchy Postgres for databases, Dragonfly for caching
- **Networking**: Cilium CNI, Envoy Gateway, Cloudflare DNS/DDNS, Tailscale VPN
- **Secrets**: SOPS with AGE encryption + 1Password via External Secrets Operator (mostly this, some former)

## 📂 Repository structure

The Git repository contains the following directories:

```sh
📁
└──📁 kubernetes
    ├──📁 ai
    │   ├──📁 litellm
    │   ├──📁 openwebui
    │   └──📁 searxng
    ├──📁 games
    │   └──📁 abiotic-factor
    ├──📁 infra
    │   ├──📁 flux
    │   │   ├──📁 instance
    │   │   ├──📁 notifications
    │   │   ├──📁 operator
    │   │   ├──📁 receiver
    │   │   ├──📁 repositories
    │   │   └──📁 secrets
    │   ├──📁 node-feature-discovery
    │   │   └──📁 node-feature-discovery
    │   ├──📁 nvidia-device-plugin
    │   │   └──📁 nvidia-device-plugin
    │   ├──📁 reflector
    │   │   └──📁 reflector
    │   ├──📁 reloader
    │   │   └──📁 reloader
    │   ├──📁 spegel
    │   └──📁 tuppr
    │       └──📁 upgrades
    ├──📁 manga
    │   ├──📁 komf
    │   ├──📁 komga
    │   └──📁 suwayomi
    ├──📁 media
    │   ├──📁 cleanuparr
    │   ├──📁 decluttarr
    │   ├──📁 dispatcharr
    │   ├──📁 flaresolver
    │   ├──📁 huntarr
    │   ├──📁 jellyfin
    │   ├──📁 jellyseer
    │   ├──📁 prowlarr
    │   ├──📁 qbittorrent
    │   │   └──📁 ui
    │   ├──📁 radarr
    │   ├──📁 recyclarr
    │   └──📁 sonarr
    ├──📁 misc
    │   ├──📁 immich
    │   ├──📁 speedtest-tracker
    │   │   └──📁 speedtest-tracker
    │   └──📁 syncthing
    │       └──📁 syncthing
    ├──📁 networking
    │   ├──📁 cert-manager
    │   │   └──📁 cert-manager
    │   ├──📁 cilium
    │   │   └──📁 cilium
    │   ├──📁 envoy-gateway
    │   │   └──📁 config
    │   ├──📁 external-dns
    │   │   ├──📁 cloudflare
    │   │   └──📁 cloudflare-ddns
    │   └──📁 tailscale
    │       └──📁 tailscale
    ├──📁 observability
    │   ├──📁 dashboard
    │   │   └──📁 homepage
    │   ├──📁 kube-prometheus-stack
    │   ├──📁 kube-state-metrics
    │   ├──📁 metrics-server
    │   └──📁 node-exporter
    ├──📁 projects
    │   └──📁 colwiki
    ├──📁 security
    │   ├──📁 authentik
    │   │   └──📁 authentik
    │   └──📁 secrets
    │       └──📁 external-secrets
    └──📁 storage
        ├──📁 databases
        │   ├──📁 dragonfly
        │   └──📁 postgres
        ├──📁 garage
        │   └──📁 webui
        └──📁 longhorn
            └──📁 longhorn
```

## 🖥️ Software

| Software                                                                              | Category         | Purpose                                                   |
| ------------------------------------------------------------------------------------- | ---------------- | --------------------------------------------------------- |
| [Authentik](https://goauthentik.io)                                                   | Security         | Identity provider for SSO and authentication.             |
| [Cert-Manager](https://cert-manager.io)                                               | Networking       | Automated certificate management for Kubernetes.          |
| [Cilium](https://cilium.io)                                                           | Networking       | eBPF-based networking, security, and observability.       |
| [Cleanuparr](https://github.com/Just-Insane/cleanuparr)                               | Media Automation | Automated media cleanup tool for \*arr apps.              |
| [Crunchy Postgres Operator](https://github.com/CrunchyData/postgres-operator)         | Storage          | PostgreSQL operator for Kubernetes.                       |
| [Decluttarr](https://github.com/ManiMatter/decluttarr)                                | Media Automation | Removes stalled torrents from qBittorrent.                |
| [Dispatcharr](https://github.com/dkoz/dispatcharr)                                    | Media Automation | Discord notifications for \*arr apps.                     |
| [Dragonfly](https://dragonflydb.io)                                                   | Storage          | Modern in-memory datastore (Redis/Memcached alternative). |
| [Envoy Gateway](https://gateway.envoyproxy.io)                                        | Networking       | Kubernetes-native API gateway powered by Envoy.           |
| [External DNS](https://github.com/kubernetes-sigs/external-dns)                       | Networking       | Synchronizes Kubernetes services with DNS providers.      |
| [External Secrets Operator](https://external-secrets.io)                              | Security         | Integrates external secret stores with Kubernetes.        |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr)                          | Media Automation | Proxy server to bypass Cloudflare protection.             |
| [Flux CD](https://fluxcd.io)                                                          | Infrastructure   | GitOps continuous delivery for Kubernetes.                |
| [Garage](https://garagehq.deuxfleurs.fr)                                              | Storage          | Distributed object storage service (S3-compatible).       |
| [Homepage](https://github.com/gethomepage/homepage)                                   | Applications     | Customizable homepage dashboard for service management.   |
| [Huntarr](https://github.com/Ravencentric/huntarr)                                    | Media Automation | Missing media searcher for Radarr and Sonarr.             |
| [Immich](https://immich.app)                                                          | Applications     | Self-hosted photo and video backup solution.              |
| [Jellyfin](https://jellyfin.org)                                                      | Media Automation | Media server for movies, TV shows, and music.             |
| [Jellyseerr](https://github.com/Fallenbagel/jellyseerr)                               | Media Automation | Media discovery and request management for Jellyfin.      |
| [Komf](https://github.com/Snd-R/komf)                                                 | Applications     | Metadata fetcher for Komga.                               |
| [Komga](https://komga.org)                                                            | Applications     | Media server for comics and manga.                        |
| [Kube Prometheus Stack](https://github.com/prometheus-operator/kube-prometheus-stack) | Observability    | Complete monitoring stack with Prometheus and Grafana.    |
| [Kube State Metrics](https://github.com/kubernetes/kube-state-metrics)                | Observability    | Exposes cluster-level Kubernetes object metrics.          |
| [LiteLLM](https://github.com/BerriAI/litellm)                                         | Applications     | Proxy server for LLM API calls with unified interface.    |
| [Longhorn](https://longhorn.io)                                                       | Storage          | Distributed block storage for Kubernetes.                 |
| [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)                   | Observability    | Cluster-wide aggregator of resource usage data.           |
| [Node Exporter](https://github.com/prometheus/node_exporter)                          | Observability    | Prometheus exporter for hardware and OS metrics.          |
| [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery)   | Node Management  | Detects hardware features available on each node.         |
| [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)                   | Node Management  | Exposes NVIDIA GPUs to Kubernetes.                        |
| [Open WebUI](https://github.com/open-webui/open-webui)                                | Applications     | User-friendly web interface for AI models.                |
| [Otterwiki](https://github.com/redimp/otterwiki)                                      | Applications     | Simple wiki for personal use.                             |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)                                      | Media Automation | Indexer manager/proxy for media automation.               |
| [Qbittorrent](https://www.qbittorrent.org)                                            | Media Automation | BitTorrent client with web interface.                     |
| [Radarr](https://radarr.video)                                                        | Media Automation | Automated movie download and management.                  |
| [Recyclarr](https://github.com/recyclarr/recyclarr)                                   | Media Automation | Quality profiles and custom formats sync for \*arr apps.  |
| [Reflector](https://github.com/emberstack/kubernetes-reflector)                       | Infrastructure   | Mirrors ConfigMaps and Secrets across namespaces.         |
| [Reloader](https://github.com/stakater/Reloader)                                      | Infrastructure   | Triggers pod restarts on ConfigMap/Secret changes.        |
| [SearXNG](https://github.com/searxng/searxng)                                         | Applications     | Privacy-respecting metasearch engine.                     |
| [Sonarr](https://sonarr.tv)                                                           | Media Automation | Automated TV show download and management.                |
| [Spegel](https://github.com/spegel-org/spegel)                                        | Infrastructure   | Stateless cluster-local OCI registry mirror.              |
| [Speedtest Tracker](https://github.com/alexjustesen/speedtest-tracker)                | Applications     | Internet speed tracking and monitoring tool.              |
| [Suwayomi](https://github.com/Suwayomi/Suwayomi-Server)                               | Applications     | Free and open source manga reader server.                 |
| [Syncthing](https://syncthing.net)                                                    | Applications     | Continuous file synchronization program.                  |
| [Tailscale](https://tailscale.com)                                                    | Networking       | Zero-config VPN built on WireGuard.                       |
| [Tuppr](https://github.com/siderolabs/talos-cloud-controller-manager)                 | Node Management  | Talos Linux system upgrade controller.                    |

## 📦 Hardware

| Device                                                                                       | Count | OS Disk Size | Data Disk Size | Ram  | Operating System | Purpose             |
| -------------------------------------------------------------------------------------------- | ----- | ------------ | -------------- | ---- | ---------------- | ------------------- |
| [Turing RK1](https://turingpi.com/product/turing-rk1/?attribute_ram=16+GB)                   | 4     | 2TB NVMe     | -              | 16GB | Talos v1.12.1    | ARM64 Cluster Nodes |
| [Turing Pi 2](https://turingpi.com/product/turing-pi-2-5/)                                   | 1     | -            | -              | -    | -                | Baseboard and KVM   |
| [CWWK AMD-7940HS](https://www.amazon.com/CWWK-NAS-display-network-motherboard/dp/B0D5M2M3Y5) | 1     | 1TB NVMe     | 8TB HDD (2x)   | 32GB | Talos v1.12.1    | x86_64 Cluster Node |
