# Research: Kopiur copy-method prevalence

## Summary

Kopiur's **current official default and recommendation are `Snapshot`** when CSI snapshots are available. `Direct` is the documented fallback when CSI snapshots are unavailable or unwanted.

Public usage is too sparse to establish an empirical winner. A KubeSearch-first sample found only **three unique third-party repositories containing Kopiur policies**: one repository explicitly/effectively uses `Snapshot`, that same repository has a `Direct` exception, and two repositories omit `copyMethod`. Omission is not reliable evidence of intent because Kopiur changed the default from `Direct` to `Snapshot` in July 2026.

Therefore, copy method should be selected from storage and consistency requirements rather than popularity. Under the design assumption that Kopiur's Snapshot staging flow is safe with Miroir, the Home-Server pilot should explicitly use **`Snapshot`**, matching Kopiur's current recommendation and 20 of this repository's 22 existing VolSync policies. The two existing Direct workloads should still receive a separate Direct validation before complete cutover.

## Findings

### Official default and recommendation

Kopiur recommends starting with `Snapshot` when the CSI snapshot stack and a matching `VolumeSnapshotClass` are available. It captures a point in time, restores the CSI snapshot to a temporary PVC, and lets the mover read that PVC independently of the application node. `Direct` mounts the live PVC read-only, is not point-in-time, and must co-locate for node-bound or RWO storage.

Sources:

- [Official copy-method documentation](https://kopiur.home-operations.com/copy-methods/)
- [Commit changing the default from Direct to Snapshot](https://github.com/home-operations/kopiur/commit/e1291d057ca8872763d8f4c811f956dd613d4754)

### Historical default

Commit `e1291d0` changed the CRD and Rust defaults from `Direct` to `Snapshot` on 2026-07-04. Its upgrade warning explains that a GitOps object omitting the field can be server-side defaulted differently after reapplication. Consequently, omitted fields cannot be counted as deliberate user choices. On a current fresh object they resolve to `Snapshot`; older persisted objects may have resolved to `Direct`.

### KubeSearch sample

The reproducible discovery source was [KubeSearch's Kopiur Helm-release result](https://kubesearch.dev/hr/ghcr.io-home-operations-charts-kopiur). It listed five rows:

- `deedee-ops/home-ops`
- `kashalls/home-cluster`
- `waifulabs/infrastructure`
- `Pumba98/flux2-gitops`
- `m00nwtchr/homelab-cluster`

The sample was normalized as follows:

- `kashalls/home-cluster` redirects to the same canonical repository and GitHub repository ID as `waifulabs/infrastructure`, so it was deduplicated.
- `Pumba98/flux2-gitops` installs Kopiur but exposes no indexed `SnapshotPolicy`, so it was excluded from the policy denominator.
- Kopiur's own examples, forks, and mirrors were excluded.

| Classification | Unique repositories | Evidence |
|---|---:|---|
| Explicit/effective `Snapshot` | 1 | `m00nwtchr/homelab-cluster` has a generator whose parameter defaults to `Snapshot`. [Manifest](https://github.com/m00nwtchr/homelab-cluster/blob/master/kubernetes/apps/kopiur-system/kopiur/config/kopiurbackup-rgd.yaml) |
| Explicit `Direct` | 1 | The same repository overrides its Immich photos policy to `Direct`. [Manifest](https://github.com/m00nwtchr/homelab-cluster/blob/master/kubernetes/apps/media/immich/app/kopiurbackup.yaml) |
| Omitted | 2 | `deedee-ops/home-ops` and `waifulabs/infrastructure` omit the field. [Deedee policy](https://github.com/deedee-ops/home-ops/blob/master/kubernetes/components/kopiur/snapshotpolicy.yaml) · [Deedee policy 2](https://github.com/deedee-ops/home-ops/blob/master/kubernetes/components/kopiursnap/snapshotpolicy.yaml) · [Waifulabs policy](https://github.com/waifulabs/infrastructure/blob/main/kubernetes/components/kopiur/backup/snapshotpolicy.yaml) |

At the configuration-file level, the sample contains one effective Snapshot generator/default, one Direct override, and three literal policy templates that omit the field. Template expansion prevents these files from being treated as independent installations or users.

## Interpretation for Home-Server

The public sample does **not** support a claim that either explicit mode is most common. It shows primarily that public configurations often rely on defaults. The stronger evidence is Kopiur's current official position: Snapshot is the default and preferred method when CSI snapshots work.

Given the explicit design assumption that the Miroir Snapshot/staging flow is safe:

1. Use `copyMethod: Snapshot` explicitly for the first pilot.
2. Use `volumeSnapshotClassName: miroir-snap` explicitly.
3. Do not rely on CRD defaults, because the default has already changed once.
4. Validate `Direct` separately before migrating `jellyfin-config` and `qbittorrent-config`, which currently use Direct under VolSync.
5. Preserve the repository's mandatory post-restore Miroir validation even though compatibility is accepted as a design assumption.

## Limitations

KubeSearch indexes a curated subset of public GitOps repositories and may lag default branches. It does not cover private repositories, unindexed repositories, non-GitOps installations, rendered-only resources, or actual backup-run counts. The sample is therefore a reproducible convenience sample, not ecosystem telemetry. No public source reveals the admitted value of old live objects whose manifests omit `copyMethod`.
