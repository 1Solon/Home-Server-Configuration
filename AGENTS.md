# Repository Guidelines

## Project Structure & Module Organization

This repository manages a Talos Linux Kubernetes cluster through GitOps. Active workloads live under `kubernetes/`, grouped by domain such as `infra`, `networking`, `storage`, `observability`, `media`, `ai`, `books`, and `manga`. Most applications follow an `install.yaml` entry point plus an `app/` directory containing `release.yaml`, `kustomization.yaml`, and related resources. Shared reusable pieces live in `kubernetes/components/`. Talos inputs are in `talos/`, helper scripts are in `scripts/`, and retired manifests are kept in `archive/`.

## Build, Test, and Development Commands

- `task gen`: run `talhelper genconfig` from `talos/` to regenerate Talos cluster configuration.
- `task apply`: apply generated Talos node configs one node at a time using the safety script.
- `task apply-kube1` through `task apply-kube5`: apply one node only.
- `task reset-ephemeral-for-csi`: drain and reset Talos EPHEMERAL volumes for Longhorn CSI preparation.
- `kustomize build kubernetes/<area>` or `kubectl kustomize kubernetes/<area>`: validate rendered manifests before pushing changes.

Avoid running cluster-mutating tasks unless you are intentionally changing live infrastructure and have cluster access configured.

## Coding Style & Naming Conventions

Use YAML with two-space indentation and LF line endings. Keep resource names lowercase and hyphenated, matching existing paths such as `kubernetes/media/jellyfin/app/release.yaml`. Prefer one concern per file: `namespace.yaml`, `externalsecret.yaml`, `configmap.yaml`, `prometheusrule.yaml`, and `grafanadashboard.yaml` are common patterns. Update the nearest `kustomization.yaml` whenever adding or removing a manifest.

## Testing Guidelines

There is no application test suite. Validation is manifest-oriented: build the affected Kustomize tree, check YAML syntax, and confirm Flux or HelmRelease references resolve. For changes under `talos/`, run `task gen` and review generated diffs before applying.

## Commit & Pull Request Guidelines

Recent history uses short imperative or descriptive commits, often lowercase, for manual changes, for example `fixes opencode healthcheck` or `removes code server from hermes`. Renovate commits use Conventional Commit style such as `feat(container): update image ...`. Keep commits scoped to one service or subsystem. Pull requests should describe the affected workload, validation performed, expected cluster impact, and any required secret or DNS changes.

## Security & Configuration Tips

Do not commit decrypted secrets, local logs, or generated private files. `.gitignore` excludes `*decrypted*`, `language-server-log.txt`, and `bgp.conf`; keep SOPS-encrypted files encrypted in Git. Prefer `ExternalSecret` resources and existing 1Password-backed stores for new secret material.
