# Research: Public Miroir implementations (via KubeSearch) vs kube5

Date: 2026 survey. Scope: find public repos running the `miroir` chart
(`oci://ghcr.io/home-operations/charts/miroir`, CRDs `miroir.home-operations.com/v1alpha1`,
provisioner `miroir.home-operations.com`), determine cluster node counts, deep-dive any
**5-node** implementations, and compare against our current setup on cluster `kube5`
(5-node Talos arm64).

## Discovery method

- KubeSearch indexes Miroir: <https://kubesearch.dev/hr/ghcr.io-home-operations-charts-miroir>
  reports **"3 out of 15"** repositories (15 repos have a `miroir` HelmRelease indexed;
  the UI only surfaces the top 3 by stars). KubeSearch's underlying search API is not
  publicly fetchable (`/api/search` returns 404), so the remaining 12 repo names could
  not be enumerated programmatically.
- Secondary discovery channel (GitHub code search via web search + GitHub trees API,
  since unauthenticated GitHub code-search API is 401 and grep.app was rate-limited):
  found two additional implementations not in KubeSearch's top-3: `caycehouse/home-ops`
  and `solanyn/home-ops`.

## Step 1–2: Inventory of Miroir implementations found

| Repo | Chart ver | Nodes | Confidence | Notes |
|---|---|---|---|---|
| [Diaoul/home-ops](https://github.com/Diaoul/home-ops) | 0.11.22 | **5 (3 CP + 2 workers)** | High — explicit node list | Only confirmed 5-node implementation |
| [onedr0p/home-ops](https://github.com/onedr0p/home-ops) | 0.11.22 | 3 | High | 3× ASUS NUC 14 Pro Talos ([docs](https://onedr0p.github.io/home-ops/introduction.html)) |
| [bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops) | 0.11.22 | Unknown (small; 2 Ansible hosts `gladius`, `icarus`; single `MiroirNode` "delta") | Low | Not Talos; Ansible+Terraform managed |
| [solanyn/home-ops](https://github.com/solanyn/home-ops) | n/a | 3 | Medium | 3× Dell Optiplex (1×7050, 2×7060) |
| [caycehouse/home-ops](https://github.com/caycehouse/home-ops) | n/a | 1 | High | Single Dell OptiPlex 5080 Micro |

The other ~10 of the 15 KubeSearch-indexed repos could not be identified without an
authenticated GitHub code-search token — see Gaps.

## Step 3: Deep-dive — Diaoul/home-ops (the only 5-node implementation)

Cluster: 5 nodes defined explicitly in [`talos/topf.yaml`](https://github.com/Diaoul/home-ops/blob/main/talos/topf.yaml)
(`k8s-node-1..3` control-plane, `k8s-node-4..5` worker, Talos v1.13.9, k8s v1.36.4,
topf-rendered machine configs, tuppr-driven Talos upgrades).

### HelmRelease ([kubernetes/apps/miroir-system/miroir/app/helmrelease.yaml](https://github.com/Diaoul/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/app/helmrelease.yaml))

```yaml
values:
  autoEvictAfter: 1h
  drbd:
    alExtents: 6007
    portBase: 7400   # default 7000 collides with host-network Ceph mgr dashboard
  groupSnapshots:
    enabled: true    # <-- kube5 does NOT enable this
  replicaCount: 2
  monitoring:
    dashboards.enabled: true (grafanaOperator, matchLabels dashboards=grafana)
    podMonitor.enabled: true
    prometheusRule.enabled: true
```

Notable: no `driftDetection`, no `install/upgrade.crds: CreateReplace` (CRDs handled
elsewhere), no affinity/nodeSelector overrides, no overcommit/freeSpace/autoTieBreaker
(chart defaults apply), `autoDiskfulAfter` unset.

### MiroirNodeGroup ([config/miroirnodegroup.yaml](https://github.com/Diaoul/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/miroirnodegroup.yaml))

Single group `default`, `nodeSelector: {}` (**all** nodes including workers), one pool:

```yaml
pools:
  - name: default
    lvmthin:
      device: /dev/disk/by-partlabel/r-miroir
```

No loopfile/client pool — no VolSync cache or tie-breaker pool separation.

### StorageClasses ([config/storageclass.yaml](https://github.com/Diaoul/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/storageclass.yaml))

- `miroir-local`: replicas "1", ext4, WaitForFirstConsumer, expansion allowed. **No pool param** (uses `default`).
- `miroir-replicated`: replicas "2", **quorum: freeze**, ext4, WaitForFirstConsumer, expansion allowed.
- Neither is annotated as default class.

### Snapshot classes

- [volumesnapshotclass.yaml](https://github.com/Diaoul/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/volumesnapshotclass.yaml): `miroir`, deletionPolicy Delete (same as kube5's `miroir-snap`).
- [volumegroupsnapshotclass.yaml](https://github.com/Diaoul/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/volumegroupsnapshotclass.yaml): `VolumeGroupSnapshotClass miroir`, Delete — enabled by `groupSnapshots.enabled: true`.

## Reference configs from non-5-node repos (context for the comparison)

- **bjw-s-labs**: per-node `MiroirNode` ("delta", lvmthin `/dev/disk/by-partlabel/r-miroir`) instead of a NodeGroup ([miroirnode.yaml](https://github.com/bjw-s-labs/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/miroirnode.yaml)); HR sets `autoTieBreaker: false` and `agent.resources.limits.memory: 192Mi` ([helmrelease.yaml](https://github.com/bjw-s-labs/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/app/helmrelease.yaml)); replicated SC uses **quorum: last-man-standing** ([storageclass.yaml](https://github.com/bjw-s-labs/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/storageclass.yaml)).
- **solanyn**: NodeGroup pinned to control-plane nodes only ([miroirnodegroup.yaml](https://github.com/solanyn/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/miroirnodegroup.yaml)); HR sets `autoDiskfulAfter: 1h` + `autoEvictAfter: 1h` ([helmrelease.yaml](https://github.com/solanyn/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/app/helmrelease.yaml)); replicated SC is annotated `storageclass.kubernetes.io/is-default-class: "true"` ([storageclass.yaml](https://github.com/solanyn/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/storageclass.yaml)).
- **onedr0p**: minimal HR (`autoEvictAfter: 1h`, `alExtents: 6007`, `replicaCount: 2`, full monitoring, `groupSnapshots.enabled: true`) ([helmrelease.yaml](https://github.com/onedr0p/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/app/helmrelease.yaml)); NodeGroup restricted to control-plane nodes with pool `slow` ([miroirnodegroup.yaml](https://github.com/onedr0p/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/miroirnodegroup.yaml)); two SCs `miroir-slow-local` / `miroir-slow` (replicas 2, quorum freeze) ([storageclass.yaml](https://github.com/onedr0p/home-ops/blob/main/kubernetes/apps/miroir-system/miroir/config/storageclass.yaml)).
- KubeSearch aggregate popularity for this chart (15 repos): `replicaCount: 2` (12×), `drbd.alExtents: 6007` (12×), `autoEvictAfter: 1h` (10×), all three monitoring objects enabled (13–14×), `drbd.portBase: 7000` (4×), `autoTieBreaker: false` (6×), `freeSpaceRatio: 20` (1×), `overcommitRatio: 2` (1×), `global.nodeSelector.arm64` (1×). This confirms kube5's values sit squarely in community mainstream; almost nobody tunes `verify.schedule` or `drbd.resync.minRate` (1×).

## Comparison vs kube5's current setup

| Setting | kube5 | Diaoul (5-node) | Others | Assessment |
|---|---|---|---|---|
| Controller replicaCount | 2 | 2 | 2 everywhere | Equal |
| Controller scheduling | arch=arm64 selector + preferred antiAffinity hostname | none (defaults) | bjw-s: global podAntiAffinity block; solanyn/onedr0p none | **kube5 better/equal** |
| overcommitRatio | 2 | unset (=chart default) | 1× seen at 2 | Equal-ish |
| freeSpaceRatio | 20 | unset | 1× seen at 20 | Equal-ish |
| autoTieBreaker | true | unset (default) | bjw-s: false | **kube5 more deliberate**; with 5 nodes tie-breakers are cheap insurance |
| autoDiskfulAfter | "6h" (since 2026-08-23) | unset | solanyn: 1h | Initially kept unset fearing split-brain masking; revisited — that risk applies to `last-man-standing`, not our `quorum: freeze` classes. Enabled at 6h so settled consumers get local I/O; controller caps volumes at 3 diskful legs, and 6h exceeds VolSync mover runtime so transient mounts never convert. Stray replicas (e.g. after a mover restore runs long) are pruned by hand via `spec.replicas`. |
| autoEvictAfter | 1h | 1h | 1h (10×), solanyn 1h | Equal |
| storageCapacity.enabled | false | unset | — | Equal |
| drbd.portBase | 7200 | 7400 (Ceph collision) | mostly default 7000 | **kube5 fine**; both avoid the 7000 default deliberately |
| drbd.alExtents | 6007 | 6007 | 6007 (12×) | Equal |
| drbd.verify algorithm/schedule | crc32c, schedule unset | unset | schedule 1× | Equal (nobody schedules verify; potential improvement for anyone) |
| monitoring | podMonitor+prometheusRule+dashboards, cross-ns import | same, cross-ns import seen once | same | Equal |
| NodeGroup scope | os=linux selector, pools: client loopfile + data lvmthin (partlabel r-longhorn-csi) | all nodes `{}`, single lvmthin `default` pool | onedr0p/solanyn: CP-only, single pool | **kube5 better**: dedicated loopfile client pool isolates VolSync cache/tie-breakers from the thinpool |
| StorageClass default | miroir-replicated is DEFAULT | none marked default | solanyn marks default | kube5 fine (deliberate) |
| Replicated SC params | replicas 2, pool data, quorum **last-man-standing** (switched from freeze on 2026-08-23 — availability over strict consistency; split-brain runbook lives in AGENTS.md), allowRemoteVolumeAccess true, ext4, WFFC, expansion | replicas 2, quorum freeze, ext4, WFFC, expansion | bjw-s: quorum last-man-standing | Now matches bjw-s's choice deliberately; see AGENTS.md for the manual-resolution trade-off |
| Ephemeral/local SC | miroir-ephemeral replicas 1 pool client | miroir-local replicas 1 (same pool!) | same pattern | **kube5 better** (separates ephemeral IO from replica pool) |
| VolumeSnapshotClass | miroir-snap Delete (default) | miroir Delete | same | Equal |
| groupSnapshots.enabled | not enabled | **true** | onedr0p true, solanyn no | Delta — see verdict |
| Flux hardening | driftDetection + remediation retries 3, crds CreateReplace | plain interval only | varies | **kube5 better** |

## Verdict

**No public 5-node implementation is better than kube5's current setup overall.**
Only one 5-node implementation exists in the surveyed set (Diaoul/home-ops), and its
Miroir config is effectively a strict subset of kube5's: it lacks kube5's dedicated
client/loopfile pool, controller anti-affinity, drift detection, default-class
discipline, and explicit pool targeting. kube5 already does better on: pool separation,
controller scheduling/anti-affinity, Flux drift/remediation hardening, and deliberate
quorum/default-class choices.

Concrete, actionable deltas worth considering:

1. **Enable `groupSnapshots.enabled: true`** (Diaoul and onedr0p both do) and add a
   `VolumeGroupSnapshotClass` (Delete) — enables crash-consistent multi-PVC snapshots,
   useful for apps like databases spanning several volumes. Low risk; requires the
   CRD-side group snapshot support already shipped with snapshot-controller ≥ 8.x.
2. Optionally set an explicit `agent.resources.limits.memory` (bjw-s uses 192Mi) —
   nice-to-have guardrail on arm64 nodes.
3. Consider a `drbd.verify.schedule` (crc32c is already set) — nobody in the surveyed
   set schedules online verification, which is exactly why it would differentiate
   kube5's operational posture; pick an off-peak monthly cadence.
4. ~~Do NOT copy: `autoDiskfulAfter: 1h`~~ **Reversed on 2026-08-23:** enabled at `"6h"` — the divergence concern was specific to `last-man-standing` quorum; our `freeze` classes cannot diverge by design. 6h (not 1h) keeps short-lived VolSync movers from converting. See the comparison-table row for details.
   `autoTieBreaker: false` (bjw-s), ~~`quorum: last-man-standing` (bjw-s)~~ **also reversed on
   2026-08-23:** the cluster switched to last-man-standing after repeated read-only-
   filesystem incidents under freeze; the split-brain runbook is in AGENTS.md,
   CP-only NodeGroups (reduces replica placement domain vs kube5's os=linux across 5 nodes).

## Sources

Kept:
- KubeSearch Miroir page — discovery index (15 repos): https://kubesearch.dev/hr/ghcr.io-home-operations-charts-miroir
- Diaoul topf.yaml — proves 5-node topology: https://github.com/Diaoul/home-ops/blob/main/talos/topf.yaml
- Diaoul/onedr0p/bjw-s-labs/solanyn/caycehouse primary YAMLs (linked inline above)
- onedr0p cluster intro (3 nodes): https://onedr0p.github.io/home-ops/introduction.html
- solanyn README (3 nodes): https://github.com/solanyn/home-ops
- caycehouse README (1 node): https://github.com/caycehouse/home-ops
- Miroir quickstart docs: https://miroir.home-operations.com/quickstart/

Dropped:
- sourceforge "home-operations mirror" tarballs — stale third-party mirror, not primary
- reddit/blog commentary — no primary config value
- kubesearch per-chart Tempo page — only incidental `storageClassName` reference

## Gaps

- The remaining ~10 KubeSearch-indexed Miroir repos could not be enumerated: the UI
  shows only the top 3, and there is no public JSON API; unauthenticated GitHub code
  search API returns 401. With a `GITHUB_TOKEN`, run
  `gh api "search/code?q=MiroirNodeGroup"` and re-check node counts for any new 5-node hits.
- bjw-s-labs' exact Kubernetes node count (k8s nodes vs Ansible hosts) is inferred, not proven.
