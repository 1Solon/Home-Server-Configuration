# Home Server Config

This is a collection of config and deployments for my home kubernetes cluster, this is a pretty standard K3's cluster running on a couple RK1s.

## How am I syncing this with my cluster?

I'm making use of [flux](https://fluxcd.io/) which is a pretty cool tool that allows you to sync your git repo with your kubernetes cluster. If you have a cluster, and are interested in GitOps, I'd highly recommend checking it out.

## What's in here?

This server largely runs a bunch of home-media stuff, pihole, torrent and a few other bits and pieces. I'll try to keep this list updated as I add more stuff.

- [Homarr](https://homarr.dev/) [Deployment](./clusters/home-cluster/dashboard/) - A dashboard for my services.
- [Jellyfin](https://jellyfin.org/) [Deployment](./clusters/home-cluster/media/jellyfin/) - A media server.
- [Postgres](https://www.postgresql.org/) [Deployment](./clusters/home-cluster/media/postgres/) - A database for my media services, Radarr and Sonarr don't work well natively on clusters.
- [Jellyseer](https://github.com/Fallenbagel/jellyseerr) [Deployment](./clusters/home-cluster/media/jellyseer/) - A request system for Jellyfin.
- [Notifarr](https://github.com/Notifiarr) [Deployment](./clusters/home-cluster/media/notifarr/) - A cluster notification system.
- [Prowlarr](https://prowlarr.com/) [Deployment](./clusters/home-cluster/media/prowlarr/) - A manager for torrent indexers.
- [Radarr](https://radarr.video/) [Deployment](./clusters/home-cluster/media/radarr/) - A movie request system.
- [Sonarr](https://sonarr.tv/) [Deployment](./clusters/home-cluster/media/sonarr/) - A TV request system.
- [Transmission](https://transmissionbt.com/) [Deployment](./clusters/home-cluster/media/transmission/) - A torrent client.
- [Samba](https://github.com/dperson/samba) [Deployment](./clusters/home-cluster/media/samba/) - A file server.
- [Pihole](https://pi-hole.net/) [Deployment](./clusters/home-cluster/network/pihole/) - A network wide ad blocker and DNS server.

## What is my cluster made from?

I'm using a [Turing Pi 2](https://turingpi.com/product/turing-pi-2/) as the main board of my cluster. If you're interested in making a Kubernetes homelab, I'd highly recommend it.

In it's slots, I'm also running four 16gb [Turing RK1](https://turingpi.com/product/turing-rk1/)'s.

## Questions?

If you've any questions, or want to pick my brain about this cluster, feel free to contact me on discord at 1Solon, or open an issue on the GitHub.
