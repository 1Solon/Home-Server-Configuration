# Home Server Config

This is a collection of config and deployments for my home kubernetes cluster, this is a pretty standard K3's cluster running on a couple RK1s.

## How am I syncing this with my cluster?

I'm making use of [flux](https://fluxcd.io/) which is a pretty cool tool that allows you to sync your git repo with your kubernetes cluster. If you have a cluster, and are interested in GitOps, I'd highly recommend checking it out.

## How do I keep my secrets secure?

Flux supports [SOPS](https://github.com/getsops/sops) in particular [AGE](https://github.com/FiloSottile/age), you can encrypt your secrets locally with `age` and then flux will decrypt them when it applies the manifests. It's amazing that it works so well. 

## What's in here?

This server largely runs a bunch of home-media stuff, pihole, torrent and a few other bits and pieces. I'll try to keep this list updated as I add more stuff.

- [Homarr](https://homarr.dev/) - A dashboard for my services.
- [Jellyfin](https://jellyfin.org/) - A media server.
- [Postgres](https://www.postgresql.org/)- A database for my media services, Radarr and Sonarr don't work well natively on clusters.
- [Jellyseer](https://github.com/Fallenbagel/jellyseerr) - A request system for Jellyfin.
- [Notifarr](https://github.com/Notifiarr) - A cluster notification system.
- [Prowlarr](https://prowlarr.com/) - A manager for torrent indexers.
- [Radarr](https://radarr.video/) - A movie request system.
- [Sonarr](https://sonarr.tv/) - A TV request system.
- [Transmission](https://transmissionbt.com/) - A torrent client.
- [Samba](https://github.com/dperson/samba) - A file server.
- [Pihole](https://pi-hole.net/) - A network wide ad blocker and DNS server.

## What is my cluster made from?

I'm using a [Turing Pi 2](https://turingpi.com/product/turing-pi-2/) as the main board of my cluster.

In it's slots, I'm also running four 16gb [Turing RK1](https://turingpi.com/product/turing-rk1/)'s.

## Questions?

If you've any questions, or want to pick my brain about this cluster, feel free to contact me on discord at [1Solon](https://discordapp.com/users/448210429119037450), or open an issue on the GitHub.
