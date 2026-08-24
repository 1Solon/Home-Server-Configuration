# Kopiur PVC migration

This runbook records the staged migration defined by [ADR 0001](../adr/0001-adopt-kopiur-for-pvc-backups.md). The migration and VolSync retirement completed on 2026-08-24.

## Current state

- Kopiur chart, CRDs, mover images, and `scripts/kopiur` are pinned to `0.10.3`.
- Every retained workload completed its replacement-PVC cutover on 2026-08-24. Kopiur protects the replacement claims, and all retained Kopiur schedules are active.
- Each retained workload has a pinned pre-cutover snapshot and a successful post-cutover recovery point. The `seerr-config-cache` pilot remains suspended and is not part of permanent protection.
- VolSync manifests and restore templates are archived under `archive/volsync/`. Remote Restic recovery data remains retained through at least 2026-11-22.
- Each protected namespace uses its own Kopia repository under `volsync/kopiur/<namespace>/` in Garage. The Restic prefixes remain separate and unchanged.
- `kopiur-pilot-restore` is the reusable one-workload restore Kustomization. It is suspended; migrations used `scripts/kopiur-miroir` to create exact, Miroir-safe snapshots and restores directly.

## Migration waves

Activate and validate one workload at a time in this order. Do not start the next wave until every workload in the current wave passes the gate below.

1. Pilot: `seerr-config-cache` only. Remove it from permanent protection after the migration process is proven.
2. Pinned single-identity workloads: `audiobookshelf-config`, `bookorbit`, `libation-config`, `shelfmark-config`, `suwayomi`, `autobrr`, `bazarr`, `seerr-config`, `qui`, `seedboxapi-config`, `radarr-config`, `sonarr-config`, `sure`, and `tandoor`.
3. Root, mixed-identity, or otherwise complex workloads: `hermes`, `open-webui-config`, `cleanuparr-config`, `jellyfin-config`, `qbittorrent-config`, `zerobyte`, and `otterwiki`.

## Wave gate

Complete every item for one workload before activating the next workload in its wave:

1. Confirm the namespaced `Repository`, `SnapshotPolicy`, and `SnapshotSchedule` are `Ready`.
2. Set only that workload's `KOPIUR_SUSPEND` substitution to `"false"` and reconcile it.
3. For every snapshot-derived staging PVC, complete the Miroir activation procedure below before the mover consumes it. If the one-shot `Snapshot` has already failed, create a new run after correcting the LV.
4. Confirm a scheduled or manual `Snapshot` reaches `Succeeded`, moved non-zero files/bytes, and reports no permission exclusions.
5. Restore a selected snapshot to a scratch PVC, complete the Miroir activation procedure, and validate content, owners, groups, modes, and application-specific data.
6. Restore to a replacement PVC, complete the Miroir activation procedure, start the application against it, and validate application behavior.
7. Delete the old PVC only after replacement startup and content validation succeed.
8. Confirm a post-cutover Kopiur backup succeeds.
9. Confirm healthy Miroir replicas, idle Kopiur movers, no activation-skip flags, and no orphan `miroir-snapshot-*` LVs.

Any corruption, ownership mismatch, failed policy, unhealthy replica, activation-skip flag, or orphan snapshot LV blocks the wave.

## Backup checks

```sh
kubectl get repositories,snapshotpolicies,snapshotschedules,snapshots -A
kubectl get jobs -A -l app.kubernetes.io/managed-by=kopiur
kubectl get miroirvolumes -A
```

Inspect the selected snapshot before restoring:

```sh
kubectl -n <namespace> describe snapshot <snapshot>
kubectl -n <namespace> get snapshot <snapshot> \
  -o jsonpath='{.status.phase}{" files="}{.status.stats.files}{" bytes="}{.status.stats.sizeBytes}{"\n"}'
```

Snapshot failures are investigated first. A workload may move to `Direct` only after repeated Snapshot failures prevent the six-hour RPO and the consistency tradeoff is accepted for that workload.

Kopiur `0.10.3` can leave a `SnapshotSchedule`'s status at the previous `observedGeneration` when `spec.schedule.suspend` changes, causing Flux health checks to time out even though the new spec is applied. After confirming no mover is active and `onScheduleDelete: Retain`, delete only that `SnapshotSchedule` and reconcile its Flux Kustomization so Flux recreates it at generation 1. Do not delete the policy or any snapshots.

## Scratch restore

Edit `kubernetes/storage/kopiur/restores/install.yaml` for one workload and set `spec.suspend: false`. Set `APP`, `KOPIUR_RESTORE_CAPACITY`, and, when needed, `KOPIUR_RESTORE_OFFSET`. Reconcile only after reviewing the selected policy and destination name.

Kopiur `0.10.3` requires an explicit root security context and Linux capabilities for ownership-preserving restores. The restore template records these fields and keeps `skipOwners`, `skipPermissions`, and `skipTimes` false. Do not weaken them without repeating ownership validation. As soon as the scratch PVC is `Bound`, complete the Miroir activation procedure below on every diskful replica. If the one-shot `Restore` has already failed, delete and recreate only the `Restore` after correcting the LV; keep the scratch PVC until validation is complete.

Kopiur `0.10.3` also requires the mover's namespaced `get` access to base `Restore` objects so a retried Job reuses the snapshot ID already pinned in `status.resolved`; the repository component supplies this upstream [issue #401](https://github.com/home-operations/kopiur/issues/401) workaround. Kopia restores directory mtimes as the newest descendant time rather than the original directory mtime ([issue #2058](https://github.com/kopia/kopia/issues/2058)). Treat file contents, file mtimes, numeric ownership, and modes as authoritative during validation; do not use directory mtime differences alone as evidence of corruption.

After the restore reaches `Succeeded`, mount the scratch PVC in a disposable inspection pod and compare representative content and numeric ownership with the source:

```sh
kubectl -n <namespace> get restore,pvc
kubectl -n <namespace> describe restore <app>-scratch-restore
```

Suspend the restore Kustomization again and delete temporary restore resources only after validation.

## Miroir checks

Every PVC created from a snapshot needs this procedure, including Kopiur's generated staging PVCs and scratch or replacement restore PVCs. As soon as the PVC is `Bound`, derive its PV, volume handle, and diskful replica nodes from Kubernetes and `MiroirVolume`. On every diskful replica, clear activation-skip and activate only that PVC's volume LV before a mover or application consumes it. Never run these commands against `miroir-snapshot-*` LVs:

```sh
lvchange --setactivationskip n vg-miroir-<pool>/<volume-handle>
lvchange --activate y vg-miroir-<pool>/<volume-handle>
```

After deleting temporary restore resources, audit every data node for `miroir-snapshot-*` LVs. Remove an LV only after proving no `MiroirSnapshot` CR or `MiroirVolume.spec.source` references it. Never use a wildcard removal.

## Final cutover

VolSync was archived on 2026-08-24 after explicit operator approval and successful content, ownership, replacement-PVC, startup, post-cutover backup, Miroir, LVM, and snapshot validation. This approval superseded the originally planned three-month overlap.

Keep Restic repositories, credentials, and archived restore manifests through at least 2026-11-22. Their deletion requires a separate explicit decision. The Garage bucket and `volsync-garage` credential record also back Kopiur and must remain after the Restic prefixes expire.
