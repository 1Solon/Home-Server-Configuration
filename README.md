<div align="center">

<img src="https://raw.githubusercontent.com/auricom/home-ops/main/docs/src/assets/logo.png" align="center" width="144px" height="144px"/>

## Solon's Home Server Config

_A k3's cluster managed with Flux and Renovate_

</div>

<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/1Solon/AS2-AES-Encryption?style=for-the-badge)
![GitHub forks](https://img.shields.io/github/forks/1Solon/AS2-AES-Encryption?style=for-the-badge)

</div>

## 📂 Repository structure

The Git repository contains the following directories:

```sh
📁
├─📁 ansible
│  └─ 📁 playbooks
└──📁 kubernetes
   ├── 📁 cert-manager
   ├── 📁 dashboard
   ├── 📁 databases   # Postgres, CloudNativePG
   ├── 📁 kube-system
   ├── 📁 longhorn
   ├── 📁 media       # Sonarr, Radarr, Jellyfin, etc
   ├── 📁 metallb
   ├── 📁 ntfy
   ├── 📁 pihole
   ├── 📁 reflector
   ├── 📁 reloader
   ├── 📁 semaphore
   ├── 📁 speedtest
   └── 📁 traefik
```

## 🖥️ Software

The following apps are installed on the clusters.

| Software                                                                          | Purpose                                                                                  |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [Flux2](https://fluxcd.io)                                                        | GitOps Tool managing the cluster                                                         |
| [Longhorn](https://longhorn.io)                                                   | Persistent Block Storage Provisioner                                                     |
| [MetalLB](https://metallb.universe.tf)                                            | Bare metal LoadBalancer                                                                  |
| [Cert-Manager](https://cert-manager.io)                                           | Letsencrypt certificates with Cloudflare DNS                                             |
| [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller) | Automated k3s upgrades                                                                   |
| [Homarr](https://github.com/ajnart/homarr)                                        | Sleek, modern dashboard for managing services                                            |
| [CloudNativePG](https://cloudnative-pg.io)                                        | Cloud-native PostgreSQL cluster operator                                                 |
| [Postgres Operator](https://www.postgresql.org)                                   | Operator for managing PostgreSQL clusters                                                |
| [Decluttarr](https://github.com/decluttarr/decluttarr)                            | Automated media organization and decluttering tool                                       |
| [Flaresolverr](https://github.com/FlareSolverr/FlareSolverr)                      | Cloudflare and DDoS protection bypass                                                    |
| [Flood](https://github.com/jfurrow/flood)                                         | Web UI for rtorrent and other torrent clients                                            |
| [Jellyfin](https://jellyfin.org)                                                  | Media server                                                                             |
| [Jellyseer](https://github.com/Fallenbagel/jellyseerr)                            | Media discovery and management for Jellyfin                                              |
| [Notifiarr](https://notifiarr.wiki)                                               | Notifications and monitoring tool for media services                                     |
| [Prowlarr](https://github.com/Prowlarr/Prowlarr)                                  | Indexer manager for media automation                                                     |
| [Qbittorrent](https://www.qbittorrent.org)                                        | Torrent client                                                                           |
| [Radarr](https://radarr.video)                                                    | Automated movie download tool                                                            |
| [Samba](https://www.samba.org)                                                    | File sharing service                                                                     |
| [Sonarr](https://sonarr.tv)                                                       | Automated TV show download tool                                                          |
| [Ntfy](https://ntfy.sh)                                                           | Push notifications                                                                       |
| [Pihole](https://pi-hole.net)                                                     | Network-wide ad blocker (I am also using this for DNS)                                   |
| [Reflector](https://github.com/werwolfby/reflector)                               | Reflection and proxying of Docker registries                                             |
| [Reloader](https://github.com/stakater/Reloader)                                  | Kubernetes controller to watch changes in ConfigMap and Secrets and trigger Pod restarts |
| [Semaphore](https://semaphoreci.com)                                              | Continuous integration and delivery                                                      |
| [Speedtest](https://github.com/sivel/speedtest-cli)                               | Internet speed testing tool                                                              |
| [Traefik](https://traefik.io)                                                     | Edge router and load balancer                                                            |

## 🤖 Automation

[Renovate](https://www.whitesourcesoftware.com/free-developer-tools/renovate) Bot makes sure the components are never outdated.

It creates PullRequests when Helm charts or Docker images have newer versions available and even keeps Flux and k3s up-to-date.

## 📝 Secrets

Flux supports [SOPS](https://github.com/getsops/sops) in particular [AGE](https://github.com/FiloSottile/age), you can encrypt your secrets locally with `age` and then flux will decrypt them when it applies the manifests. All my secrets are encrypted on my local machine and decrypted by Flux when it applies the manifests.

## 🌐 DNS

I'm using Cloudflare for external DNS and have a wildcard A record pointing to my traefik instance. Internally I'm using PiHole for DNS resolution, these are injected into the pods via the `hosts` configmap.

| Device                                                | Count | OS Disk Size | Data Disk Size              | Ram  | Operating System | Purpose          |
| ----------------------------------------------------- | ----- | ------------ | --------------------------- | ---- | ---------------- | ---------------- |
| [Turing RK1](https://www.turingpi.com/turing-rk1/)    | 4     | 2TB NVMe     | 8TB HDD (only one has this) | 16GB | Ubuntu           | Various purposes |
| [Turing Pi 2](https://www.turingpi.com/turing-pi-v2/) | 1     | -            | -                           | -    | -                | Cluster Platform |
