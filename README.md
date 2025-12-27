<div align="center">

<img src="https://raw.githubusercontent.com/auricom/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_A k8's cluster managed with Talos, Flux and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/Home-Server-Configuration?style=for-the-badge)

</div>

## 📂 Repository structure

The Git repository contains the following directories:

```sh
📁
├──📁 kubernetes            # Main Kubernetes manifests directory
│   ├──📁 ai                # AI/ML applications
│   │   ├──📁 litellm
│   │   ├──📁 openwebui
│   │   └──📁 searxng
│   ├──📁 games             # Game servers
│   │   └──📁 abiotic-factor
│   ├──📁 infra             # Core infrastructure components
│   │   ├──📁 flux
│   │   ├──📁 node-feature-discovery
│   │   ├──📁 nvidia-device-plugin
│   │   ├──📁 reflector
│   │   ├──📁 reloader
│   │   └──📁 tuppr
│   ├──📁 manga             # Manga/comic management
│   │   ├──📁 komf
│   │   ├──📁 komga
│   │   └──📁 suwayomi
│   ├──📁 media             # Media automation (*arr stack)
│   │   ├──📁 cleanuparr
│   │   ├──📁 dispatcharr
│   │   ├──📁 flaresolver
│   │   ├──📁 huntarr
│   │   ├──📁 jellyfin
│   │   ├──📁 jellyseer
│   │   ├──📁 prowlarr
│   │   ├──📁 qbittorrent
│   │   ├──📁 radarr
│   │   ├──📁 recyclarr
│   │   └──📁 sonarr
│   ├──📁 misc              # Miscellaneous applications
│   │   ├──📁 immich
│   │   ├──📁 speedtest-tracker
│   │   └──📁 syncthing
│   ├──📁 networking        # Network services and ingress
│   │   ├──📁 cert-manager
│   │   ├──📁 cilium
│   │   ├──📁 envoy-gateway
│   │   ├──📁 external-dns
│   │   └──📁 tailscale
│   ├──📁 observability     # Monitoring and dashboards
│   │   ├──📁 dashboard
│   │   ├──📁 kube-prometheus-stack
│   │   ├──📁 kube-state-metrics
│   │   ├──📁 metrics-server
│   │   └──📁 node-exporter
│   ├──📁 projects          # Personal projects
│   │   └──📁 colwiki
│   ├──📁 security          # Authentication and secrets
│   │   ├──📁 authentik
│   │   └──📁 secrets
│   └──📁 storage           # Storage solutions
│       ├──📁 databases
│       ├──📁 garage
│       └──📁 longhorn
├──📁 talos                 # Talos Linux configuration
│   ├── talconfig.yaml      # Talos cluster configuration
│   ├── talsecret.sops.yaml # Encrypted Talos secrets
│   └──📁 clusterconfig     # Generated node configurations
└──📁 archive               # Archived/unused configurations
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
| [Ntfy](https://ntfy.sh)                                                    | Simple pub-sub notification service.                    |
| [Speedtest Tracker](https://github.com/alexjustesen/speedtest-tracker)     | Internet speed tracking and monitoring tool.            |
| [Syncthing](https://syncthing.net)                                         | Continuous file synchronization program.                |
| [Shadow Empire PBEM Bot](https://github.com/1Solon/Shadow-Empire-PBEM-Bot) | Discord bot for Shadow Empire play-by-email games.      |
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
| [Dispatcharr](https://github.com/dkoz/dispatcharr)           | Discord notifications for \*arr apps.                    |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr) | Proxy server to bypass Cloudflare protection.            |

### Infrastructure

| Software                                                        | Purpose                                            |
| --------------------------------------------------------------- | -------------------------------------------------- |
| [Flux CD](https://fluxcd.io)                                    | GitOps continuous delivery for Kubernetes.         |
| [Reflector](https://github.com/emberstack/kubernetes-reflector) | Mirrors ConfigMaps and Secrets across namespaces.  |
| [Reloader](https://github.com/stakater/Reloader)                | Triggers pod restarts on ConfigMap/Secret changes. |

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
| [Turing RK1](https://turingpi.com/product/turing-rk1/?attribute_ram=16+GB)                   | 4     | 2TB NVMe     | -              | 16GB | Talos            | Cluster Nodes     |
| [Turing Pi 2](https://turingpi.com/product/turing-pi-2-5/)                                   | 1     | -            | -              | -    | -                | Baseboard and KVM |
| [CWWK AMD-7940HS](https://www.amazon.com/CWWK-NAS-display-network-motherboard/dp/B0D5M2M3Y5) | 1     | 1TB NVMe     | 8TB HDD (2x)   | 32GB | Proxmox          | NAS/Cluster Nodes |
