<div align="center">

<img src="https://raw.githubusercontent.com/auricom/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_GitOps-managed Kubernetes cluster running on Talos Linux with Flux CD and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/Home-Server-Configuration?style=for-the-badge)

</div>

## 🏗️ Architecture Overview

This is a **GitOps-managed Kubernetes home server** with the following stack:

- **Nodes**: 5-node hybrid cluster (4x ARM64, 1x x86_64)
- **OS**: Talos Linux v1.12.1 (immutable, API-configured)
- **Kubernetes**: v1.35.0
- **GitOps**: Flux CD manages all workloads from this repository
- **Storage**: Longhorn for persistent volumes, Crunchy Postgres for databases, Dragonfly for caching
- **Networking**: Cilium CNI, Envoy Gateway, Cloudflare DNS/DDNS, Tailscale VPN
- **Secrets**: SOPS with AGE encryption + 1Password via External Secrets Operator

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

The following apps are installed on the clusters.

### Applications

| Software                                                                   | Purpose                                                 |
| -------------------------------------------------------------------------- | ------------------------------------------------------- |
| [Homepage](https://github.com/gethomepage/homepage)                        | Customizable homepage dashboard for service management. |
| [Immich](https://immich.app)                                               | Self-hosted photo and video backup solution.            |
| [LiteLLM](https://github.com/BerriAI/litellm)                              | Proxy server for LLM API calls with unified interface.  |
| [Open WebUI](https://github.com/open-webui/open-webui)                     | User-friendly web interface for AI models.              |
| [SearXNG](https://github.com/searxng/searxng)                              | Privacy-respecting metasearch engine.                   |
| [Komga](https://komga.org)                                                 | Media server for comics and manga.                      |
| [Komf](https://github.com/Snd-R/komf)                                      | Metadata fetcher for Komga.                             |
| [Suwayomi](https://github.com/Suwayomi/Suwayomi-Server)                    | Free and open source manga reader server.               |
| [Speedtest Tracker](https://github.com/alexjustesen/speedtest-tracker)     | Internet speed tracking and monitoring tool.            |
| [Syncthing](https://syncthing.net)                                         | Continuous file synchronization program.                |
| [Colwiki](https://github.com/1Solon/colwiki)                               | Personal wiki project.                                  |

### Media Automation

| Software                                                     | Purpose                                                  |
| ------------------------------------------------------------ | -------------------------------------------------------- |
| [Jellyfin](https://jellyfin.org)                             | Media server for movies, TV shows, and music.            |
| [Jellyseerr](https://github.com/Fallenbagel/jellyseerr)      | Media discovery and request management for Jellyfin.     |
| [Sonarr](https://sonarr.tv)                                  | Automated TV show download and management.               |
| [Radarr](https://radarr.video)                               | Automated movie download and management.                 |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)             | Indexer manager/proxy for media automation.              |
| [Qbittorrent](https://www.qbittorrent.org)                   | BitTorrent client with web interface.                    |
| [Recyclarr](https://github.com/recyclarr/recyclarr)          | Quality profiles and custom formats sync for \*arr apps. |
| [Huntarr](https://github.com/Ravencentric/huntarr)           | Missing media searcher for Radarr and Sonarr.            |
| [Cleanuparr](https://github.com/Just-Insane/cleanuparr)      | Automated media cleanup tool for \*arr apps.             |
| [Decluttarr](https://github.com/ManiMatter/decluttarr)       | Removes stalled torrents from qBittorrent.               |
| [Dispatcharr](https://github.com/dkoz/dispatcharr)           | Discord notifications for \*arr apps.                    |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr) | Proxy server to bypass Cloudflare protection.            |

### Infrastructure

| Software                                                        | Purpose                                            |
| --------------------------------------------------------------- | -------------------------------------------------- |
| [Flux CD](https://fluxcd.io)                                    | GitOps continuous delivery for Kubernetes.         |
| [Reflector](https://github.com/emberstack/kubernetes-reflector) | Mirrors ConfigMaps and Secrets across namespaces.  |
| [Reloader](https://github.com/stakater/Reloader)                | Triggers pod restarts on ConfigMap/Secret changes. |
| [Spegel](https://github.com/spegel-org/spegel)                  | Stateless cluster-local OCI registry mirror.       |

### Networking

| Software                                                        | Purpose                                              |
| --------------------------------------------------------------- | ---------------------------------------------------- |
| [Cilium](https://cilium.io)                                     | eBPF-based networking, security, and observability.  |
| [Cert-Manager](https://cert-manager.io)                         | Automated certificate management for Kubernetes.     |
| [External DNS](https://github.com/kubernetes-sigs/external-dns) | Synchronizes Kubernetes services with DNS providers. |
| [Tailscale](https://tailscale.com)                              | Zero-config VPN built on WireGuard.                  |
| [Envoy Gateway](https://gateway.envoyproxy.io)                  | Kubernetes-native API gateway powered by Envoy.      |

### Security

| Software                                                 | Purpose                                            |
| -------------------------------------------------------- | -------------------------------------------------- |
| [Authentik](https://goauthentik.io)                      | Identity provider for SSO and authentication.      |
| [External Secrets Operator](https://external-secrets.io) | Integrates external secret stores with Kubernetes. |

### Storage

| Software                                                                      | Purpose                                                   |
| ----------------------------------------------------------------------------- | --------------------------------------------------------- |
| [Longhorn](https://longhorn.io)                                               | Distributed block storage for Kubernetes.                 |
| [Crunchy Postgres Operator](https://github.com/CrunchyData/postgres-operator) | PostgreSQL operator for Kubernetes.                       |
| [Dragonfly](https://dragonflydb.io)                                           | Modern in-memory datastore (Redis/Memcached alternative). |
| [Garage](https://garagehq.deuxfleurs.fr)                                      | Distributed object storage service (S3-compatible).       |

### Observability

| Software                                                                              | Purpose                                                |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| [Kube Prometheus Stack](https://github.com/prometheus-operator/kube-prometheus-stack) | Complete monitoring stack with Prometheus and Grafana. |
| [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)                   | Cluster-wide aggregator of resource usage data.        |
| [Node Exporter](https://github.com/prometheus/node_exporter)                          | Prometheus exporter for hardware and OS metrics.       |
| [Kube State Metrics](https://github.com/kubernetes/kube-state-metrics)                | Exposes cluster-level Kubernetes object metrics.       |

### Node Management

| Software                                                                            | Purpose                                           |
| ----------------------------------------------------------------------------------- | ------------------------------------------------- |
| [Tuppr](https://github.com/siderolabs/talos-cloud-controller-manager)               | Talos Linux system upgrade controller.            |
| [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)                 | Exposes NVIDIA GPUs to Kubernetes.                |
| [Node Feature Discovery](https://github.com/kubernetes-sigs/node-feature-discovery) | Detects hardware features available on each node. |

## 📦 Hardware

| Device                                                                                       | Count | OS Disk Size | Data Disk Size | Ram  | Operating System | Purpose           |
| -------------------------------------------------------------------------------------------- | ----- | ------------ | -------------- | ---- | ---------------- | ----------------- |
| [Turing RK1](https://turingpi.com/product/turing-rk1/?attribute_ram=16+GB)                   | 4     | 2TB NVMe     | -              | 16GB | Talos v1.12.1    | ARM64 Cluster Nodes |
| [Turing Pi 2](https://turingpi.com/product/turing-pi-2-5/)                                   | 1     | -            | -              | -    | -                | Baseboard and KVM |
| [CWWK AMD-7940HS](https://www.amazon.com/CWWK-NAS-display-network-motherboard/dp/B0D5M2M3Y5) | 1     | 1TB NVMe     | 8TB HDD (2x)   | 32GB | Talos v1.12.1    | x86_64 Cluster Node |
