<div align="center">

<img src="https://raw.githubusercontent.com/auricom/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_A k3's cluster managed with Flux and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/Home-Server-Configuration?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/Home-Server-Configuration?style=for-the-badge)

</div>

## 📂 Repository structure

The Git repository contains the following directories:

```sh
📁
└──📁 kubernetes
    ├──📁 apps
    │   ├──📁 adguard
    │   │   └──📁 adguard
    │   ├──📁 authentik
    │   │   └──📁 authentik
    │   ├──📁 dashboard
    │   │   ├──📁 homarr
    │   │   └──📁 homepage
    │   ├──📁 media
    │   │   ├──📁 decluttarr
    │   │   ├──📁 flaresolver
    │   │   ├──📁 jellyfin
    │   │   ├──📁 jellyseer
    │   │   ├──📁 prowlarr
    │   │   ├──📁 qbittorrent
    │   │   ├──📁 radarr
    │   │   ├──📁 recyclarr
    │   │   └──📁 sonarr
    │   ├──📁 ntfy
    │   │   └──📁 ntfy
    │   └──📁 speedtest-tracker
    │       └──📁 speedtest-tracker
    └──📁 infra
        ├──📁 cert-manager
        │   └──📁 cert-manager
        ├──📁 databases
        │   ├──📁 dragonfly
        │   └──📁 postgres
        ├──📁 external-dns
        │   ├──📁 cloudflare
        │   └──📁 cloudflare-ddns
        ├──📁 flux
        │   ├──📁 repositories
        │   ├──📁 sources
        │   └──📁 vars
        ├──📁 longhorn
        │   └──📁 longhorn
        ├──📁 metallb
        │   └──📁 metallb
        ├──📁 pod-gateway
        │   └──📁 pod-gateway
        ├──📁 reflector
        │   └──📁 reflector
        ├──📁 reloader
        │   └──📁 reloader
        ├──📁 secrets
        │   └──📁 external-secrets
        └──📁 traefik
            └──📁 traefik
```

## 🖥️ Software

The following apps are installed on the clusters.

| Software                                                                            | Purpose                                                             |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [Authentik](https://goauthentik.io)                                                 | Modern identity provider for authentication and access management.  |
| [Homarr](https://github.com/ajnart/homarr)                                          | Sleek, modern dashboard for managing services.                      |
| [Homepage](https://github.com/gethomepage/homepage)                                 | Customizable homepage dashboard for service management.             |
| [Decluttarr](https://github.com/ManiMatter/decluttarr)                              | Automated media organization and decluttering tool.                 |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr)                        | Bypasses Cloudflare and DDoS protections.                           |
| [Jellyfin](https://jellyfin.org)                                                    | Media server.                                                       |
| [Jellyseer](https://github.com/Fallenbagel/jellyseerr)                              | Media discovery and management for Jellyfin.                        |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)                                    | Indexer manager for media automation.                               |
| [Qbittorrent](https://www.qbittorrent.org)                                          | Torrent client.                                                     |
| [Radarr](https://radarr.video)                                                      | Automated movie download tool.                                      |
| [Recyclarr](https://github.com/recyclarr/recyclarr)                                 | Notifications and monitoring tool for media services.               |
| [Sonarr](https://sonarr.tv)                                                         | Automated TV show download tool.                                    |
| [Ntfy](https://ntfy.sh)                                                             | Push notifications.                                                 |
| [Adguard](https://github.com/AdguardTeam/AdGuardHome)                               | Network-wide ad blocker and DNS service.                            |
| [Speedtest Tracker](https://github.com/sivel/speedtest-tracker)                     | Internet speed tracking tool.                                       |
| [Flux](https://fluxcd.io)                                                           | GitOps tool managing the cluster.                                   |
| [Cert-Manager](https://cert-manager.io)                                             | Manages Let's Encrypt certificates with Cloudflare DNS integration. |
| [Cloudflare DDNS](https://github.com/wouterdebie/cloudflare-ddns)                   | Dynamic DNS updater for Cloudflare.                                 |
| [Dragonfly](https://dragonflydb.io)                                                 | High-performance in-memory datastore.                               |
| [Crunchy PG Operator](https://github.com/CrunchyData/postgres-operator)             | Operator for managing PostgreSQL clusters.                          |
| [External DNS](https://github.com/kubernetes-sigs/external-dns)                     | Automates DNS record management for Kubernetes resources.           |
| [Longhorn](https://longhorn.io)                                                     | Persistent block storage provisioner.                               |
| [MetalLB](https://metallb.universe.tf)                                              | Bare metal load balancer.                                           |
| [Pod-gateway](https://github.com/angelnu/pod-gateway)                               | Routes traffic from pods to a gateway for VPN access.               |
| [Reflector](https://github.com/werwolfby/reflector)                                 | Proxies and mirrors Docker registries.                              |
| [Reloader](https://github.com/stakater/Reloader)                                    | Watches changes in ConfigMaps and Secrets to trigger pod restarts.  |
| [External Secrets](https://github.com/external-secrets/kubernetes-external-secrets) | Integrates external secret management systems into Kubernetes.      |
| [Traefik](https://traefik.io)                                                       | Edge router and load balancer.                                      |

## 📦 Hardware

| Device                                                                                       | Count | OS Disk Size | Data Disk Size | Ram  | Operating System | Purpose           |
| -------------------------------------------------------------------------------------------- | ----- | ------------ | -------------- | ---- | ---------------- | ----------------- |
| [Turing RK1](https://turingpi.com/product/turing-rk1/?attribute_ram=16+GB)                   | 4     | 2TB NVMe     | -              | 16GB | Ubuntu           | Cluster Nodes     |
| [Turing Pi 2](https://turingpi.com/product/turing-pi-2-5/)                                   | 1     | -            | -              | -    | -                | Baseboard and KVM |
| [CWWK AMD-7940HS](https://www.amazon.com/CWWK-NAS-display-network-motherboard/dp/B0D5M2M3Y5) | 1     | 1TB NVMe     | 8TB HDD (2x)   | 32GB | Proxmox          | NAS/Cluster Nodes |

## 🤖 Automation

[Renovate](https://www.whitesourcesoftware.com/free-developer-tools/renovate) Bot makes sure the components are never outdated.

It creates PullRequests when Helm charts or Docker images have newer versions available and even keeps Flux and k3s up-to-date.

## 📝 Secrets

Flux supports [SOPS](https://github.com/getsops/sops) in particular [AGE](https://github.com/FiloSottile/age), you can encrypt your secrets locally with `age` and then flux will decrypt them when it applies the manifests. All my secrets are encrypted on my local machine and decrypted by Flux when it applies the manifests.

## 🌐 DNS

I'm using Cloudflare for external DNS and have a wildcard A record pointing to my traefik instance. Internally I'm using PiHole for DNS resolution, these are injected into the pods via the `hosts` configmap.
