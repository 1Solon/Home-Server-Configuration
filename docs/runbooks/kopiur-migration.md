# Kopiur PVC migration

This runbook implements the staged migration defined by [ADR 0001](../adr/0001-adopt-kopiur-for-pvc-backups.md). VolSync remains the production recovery path until every retained workload satisfies the cutover gates. Do not archive VolSync or delete Restic data as part of a workload wave.

## Current state

- Kopiur chart, CRDs, mover images, and `scripts/kopiur` are pinned to `0.10.3`.
- Every retained workload has a six-hour Kopiur schedule, but all schedules are suspended by default.
- `seerr-config-cache` is the only active pilot. It is rebuildable and must be removed from permanent protection after the pilot.
- Each protected namespace uses its own Kopia repository under `volsync/kopiur/<namespace>/` in Garage. The Restic prefixes remain separate and unchanged.
- `kopiur-pilot-restore` is suspended. Its manifest restores the latest pilot snapshot to `seerr-config-cache-kopiur-scratch`.

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
9. Confirm healthy Miroir replicas, idle VolSync and Kopiur movers, no activation-skip flags, and no orphan `miroir-snapshot-*` LVs.

Any corruption, ownership mismatch, failed policy, unhealthy replica, activation-skip flag, or orphan snapshot LV blocks the wave.

## Backup checks

```sh
kubectl get repositories,snapshotpolicies,snapshotschedules,snapshots -A
kubectl get jobs -A -l app.kubernetes.io/managed-by=kopiur
kubectl get miroirvolumes -A
kubectl get replicationsources -A
```

Inspect the selected snapshot before restoring:

```sh
kubectl -n <namespace> describe snapshot <snapshot>
kubectl -n <namespace> get snapshot <snapshot> \
  -o jsonpath='{.status.phase}{" files="}{.status.stats.files}{" bytes="}{.status.stats.sizeBytes}{"\n"}'
```

Snapshot failures are investigated first. A workload may move to `Direct` only after repeated Snapshot failures prevent the six-hour RPO and the consistency tradeoff is accepted for that workload.

## Scratch restore

Edit `kubernetes/storage/kopiur/restores/install.yaml` for one workload and set `spec.suspend: false`. Set `APP`, `KOPIUR_RESTORE_CAPACITY`, and, when needed, `KOPIUR_RESTORE_OFFSET`. Reconcile only after reviewing the selected policy and destination name.

Kopiur `0.10.3` requires an explicit root security context and Linux capabilities for ownership-preserving restores. The restore template records these fields and keeps `skipOwners`, `skipPermissions`, and `skipTimes` false. Do not weaken them without repeating ownership validation. As soon as the scratch PVC is `Bound`, complete the Miroir activation procedure below on every diskful replica. If the one-shot `Restore` has already failed, delete and recreate only the `Restore` after correcting the LV; keep the scratch PVC until validation is complete.

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

VolSync can be archived only when every retained workload has:

- three monthly Kopiur recovery points;
- no stale or failed policy;
- at least two successful restores;
- successful content, ownership, replacement-PVC, startup, and post-cutover backup validation;
- healthy Miroir replicas and clean LVM/snapshot audits.

Archive VolSync manifests with `git mv`. Keep Restic repositories, credentials, and archived restore manifests for another 90 days. Their deletion requires a separate explicit decision.
