# Removing / Archiving Old Applications

When asked to remove or archive an old application, move the application's manifests to `archive/` directory using `git mv`.

# Flux and State

This is a Flux backed repository, as such, pushing to the repository will trigger a Flux reconciliation, affecting the cluster. You should never do this without permission.

# Miroir Migration Workarounds

Until the corresponding upstream issues are fixed, migrations and restores on
Miroir `0.11.22` must use all of the following safeguards:

- For an archived VolSync emergency restore, annotate the restore namespace
  with `volsync.backube/privileged-movers: "true"` before starting the mover,
  then remove the annotation immediately after it succeeds.
- Set `spec.restic.cleanupTempPVC: false` on Miroir ReplicationDestinations.
  Keep the temporary destination PVC and its snapshot until the final PVC is
  `Bound` and its contents are verified; deleting the temporary source sooner
  makes the ready snapshot unusable by Miroir.
- After every snapshot- or VolSync-restored PVC is `Ready`, clear LVM's
  activation-skip flag on the restored volume LV on every diskful replica and
  activate it. Derive the volume handle and replica nodes from the PVC/PV and
  `MiroirVolume`; never run this against `miroir-snapshot-*` LVs:

  ```sh
  lvchange --setactivationskip n vg-miroir-<pool>/<volume-handle>
  lvchange --activate y vg-miroir-<pool>/<volume-handle>
  ```

- After deleting temporary restore resources, audit every data node for
  `miroir-snapshot-*` LVs. Remove an LV only after proving that no
  `MiroirSnapshot` CR or `MiroirVolume.spec.source` references it. Never use a
  wildcard removal.
- Ceph rollback was explicitly retired after final restore validation on
  2026-08-11. Rook/Ceph manifests are archived under `archive/rook-ceph/`; do
  not restore them unless rebuilding a new Ceph cluster intentionally.
- Require healthy Miroir replicas, successful content validation, idle backup
  movers, no activation-skip flags, and no orphan `miroir-snapshot-*` LVs after
  every restore or storage change.

## Quorum: last-man-standing

The `miroir-replicated` StorageClass uses `quorum: last-man-standing`
(2026-08-23): a surviving replica keeps accepting writes with no peers in
sight instead of freezing I/O. Consequences every operator must know:

- **Split-brain is possible and stays manual.** If both sides of a volume
  accept writes while partitioned, DRBD detects it on reconnect and refuses
  to connect. The volume shows `MiroirVolumeSplitBrain` (critical). Inspect
  both legs (`drbdadm status <res>` on each node), pick the loser — usually
  the node whose writes are disposable or older — then on the LOSING node:

  ```sh
  drbdadm disconnect <res>
  drbdadm connect --discard-my-data <res>
  ```

  The losing side's writes since the split are gone. Never run this against
  the leg you believe holds the good data.

- After any node outage, check for split-brain volumes before assuming
  resyncs will drain: `kubectl get miroirvolumes -A` for disconnected peers,
  and the `MiroirVolumeSplitBrain` alert.
- Volumes under this policy carry no diskless tie-breaker; single-node loss
  never interrupts writes, but also nothing arbitrates them.

## Agent skills

### Issue tracker

Issues and specs are tracked in GitHub Issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

This repository uses a single-context domain-doc layout. See `docs/agents/domain.md`.
