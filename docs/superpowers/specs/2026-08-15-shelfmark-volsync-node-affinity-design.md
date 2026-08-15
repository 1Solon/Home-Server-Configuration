# Shelfmark VolSync Node-Affinity Fix Design

## Goal

Restore scheduled Shelfmark backups and prevent future application rescheduling from deadlocking the VolSync mover against its node-local Miroir cache.

## Root Cause

Shelfmark uses VolSync's `Direct` copy method. The mover therefore follows the node that currently mounts `shelfmark-config-miroir`. Shelfmark moved from `kube5` to `kube1` during its 2026-08-15 image rollout, but the persistent `volsync-src-shelfmark-config-cache` volume remained a single-replica `miroir-ephemeral` volume pinned to `kube5`. The mover cannot satisfy both node constraints and remains `Pending` before restic starts.

## Considered Approaches

1. **Use `Snapshot` copy mode (selected).** The mover no longer has to colocate with the running Shelfmark pod. It can remain with the existing cache on `kube5`, while Miroir provisions the snapshot-backed source volume for that consumer. This follows the working pattern used by the other Books workloads.
2. **Recreate the cache on Shelfmark's current node.** This unblocks the current run but fails again after a future Shelfmark reschedule.
3. **Use `miroir-replicated` for the cache.** This makes the cache portable but spends replicated application-storage capacity on disposable restic cache data.

## Design

Change only Shelfmark's VolSync substitution in `kubernetes/books/shelfmark/install.yaml` from `VOLSYNC_COPY_METHOD: Direct` to `VOLSYNC_COPY_METHOD: Snapshot`.

Keep the repository, schedule, source PVC, snapshot class, cache class, retention policy, and namespace ownership-preserving mover annotation unchanged. Do not delete or recreate the Shelfmark application PVC.

For live verification, patch only the Shelfmark `ReplicationSource` to the same copy method and remove the stale mover Job so VolSync can construct a fresh snapshot-based run. This manual test state is declaratively represented by the repository edit; no Flux source push is part of this task.

## Failure Handling

If the snapshot-backed mover does not complete, stop and inspect the new ReplicationSource condition, mover pod events/logs, VolumeSnapshot, temporary source PVC, MiroirVolume, and cache PVC before attempting another change. Do not delete Miroir snapshot LVs or application storage.

## Validation

1. Before editing, render the Shelfmark Kustomization and prove it emits `copyMethod: Direct`.
2. After editing, render it again and prove it emits `copyMethod: Snapshot` with the intended Miroir storage and snapshot classes.
3. Apply the equivalent live ReplicationSource test patch and restart only its stale mover Job.
4. Confirm a new VolumeSnapshot becomes ready, the mover pod schedules and completes, `lastSyncTime` advances, and `latestMoverStatus.result` is `Successful`.
5. Confirm Shelfmark remains ready, its source MiroirVolume remains healthy, VolSync becomes idle, and the repository diff is limited to the design record and Shelfmark's copy-method change.

The repository will not be pushed; pushing would authorize Flux to reconcile the cluster and requires separate explicit permission.
