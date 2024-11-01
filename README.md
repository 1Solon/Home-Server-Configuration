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
├──📁 ansible
│   └──📁 playbooks
└──📁 kubernetes
    ├──📁 apps
    │   ├──📁 dashboard
    │   │   └──📁 homarr
    │   ├──📁 label-studio
    │   │   └──📁 label-studio
    │   ├──📁 media
    │   │   ├──📁 decluttarr
    │   │   ├──📁 flaresolver
    │   │   ├──📁 flood
    │   │   ├──📁 jellyfin
    │   │   ├──📁 jellyseer
    │   │   ├──📁 prowlarr
    │   │   ├──📁 qbittorrent
    │   │   ├──📁 radarr
    │   │   ├──📁 recyclarr
    │   │   └──📁 sonarr
    │   ├──📁 muse
    │   │   └──📁 muse
    │   ├──📁 ntfy
    │   │   └──📁 ntfy
    │   ├──📁 pihole
    │   │   └──📁 pihole
    │   ├──📁 semaphore
    │   │   └──📁 semaphore
    │   ├──📁 speedtest
    │   │   └──📁 speedtest
    │   └──📁 vaultwarden
    │       └──📁 vaultwarden
    └──📁 infra
        ├──📁 cert-manager
        │   └──📁 cert-manager
        ├──📁 databases
        │   ├──📁 cloudnative-postgres
        │   └──📁 postgres-operator
        ├──📁 flux
        │   ├──📁 repositories
        │   └──📁 sources
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
        ├──📁 system-upgrade
        │   └──📁 system-upgrade-controller
        └──📁 traefik
            └──📁 traefik
```

## 🖥️ Software

The following apps are installed on the clusters.

| Software                                                                          | Purpose                                                                                  |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [Flux](https://fluxcd.io)                                                         | GitOps Tool managing the cluster                                                         |
| [Longhorn](https://longhorn.io)                                                   | Persistent Block Storage Provisioner                                                     |
| [MetalLB](https://metallb.universe.tf)                                            | Bare metal LoadBalancer                                                                  |
| [Cert-Manager](https://cert-manager.io)                                           | Letsencrypt certificates with Cloudflare DNS                                             |
| [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller) | Automated k3s upgrades                                                                   |
| [Homarr](https://github.com/ajnart/homarr)                                        | Sleek, modern dashboard for managing services                                            |
| [CloudNativePG](https://cloudnative-pg.io)                                        | Cloud-native PostgreSQL cluster operator                                                 |
| [Postgres Operator](https://www.postgresql.org)                                   | Operator for managing PostgreSQL clusters                                                |
| [Decluttarr](https://github.com/ManiMatter/decluttarr)                            | Automated media organization and decluttering tool                                       |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr)                      | Cloudflare and DDoS protection bypass                                                    |
| [Flood](https://github.com/jfurrow/flood)                                         | Web UI for rtorrent and other torrent clients                                            |
| [Jellyfin](https://jellyfin.org)                                                  | Media server                                                                             |
| [Jellyseer](https://github.com/Fallenbagel/jellyseerr)                            | Media discovery and management for Jellyfin                                              |
| [Muse](https://github.com/codetheweb/muse)                                        | Self-hostable discord music bot                                                          |
| [Recyclarr](https://github.com/recyclarr/recyclarr)                               | Notifications and monitoring tool for media services                                     |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)                                  | Indexer manager for media automation                                                     |
| [Qbittorrent](https://www.qbittorrent.org)                                        | Torrent client                                                                           |
| [Radarr](https://radarr.video)                                                    | Automated movie download tool                                                            |
| [Sonarr](https://sonarr.tv)                                                       | Automated TV show download tool                                                          |
| [Ntfy](https://ntfy.sh)                                                           | Push notifications                                                                       |
| [Pihole](https://pi-hole.net)                                                     | Network-wide ad blocker (I am also using this for DNS)                                   |
| [Reflector](https://github.com/werwolfby/reflector)                               | Reflection and proxying of Docker registries                                             |
| [Reloader](https://github.com/stakater/Reloader)                                  | Kubernetes controller to watch changes in ConfigMap and Secrets and trigger Pod restarts |
| [Semaphore](https://semaphoreci.com)                                              | Continuous integration and delivery                                                      |
| [Speedtest](https://github.com/sivel/speedtest-cli)                               | Internet speed testing tool                                                              |
| [Traefik](https://traefik.io)                                                     | Edge router and load balancer                                                            |
| [Pod-gateway](https://github.com/angelnu/pod-gateway)                             | Routes traffic from pods to a gateway (I use it to route to a vpn)                       |
| [Vaultwarden](https://github.com/dani-garcia/vaultwarden)                         | Bitwarden compatible password manager                                                    |
| [Label-Studio](https://labelstud.io/)                                             | Data labeling tool                                                                       |

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
