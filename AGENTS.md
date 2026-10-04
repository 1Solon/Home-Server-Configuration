# Removing / Archiving Old Applications

When asked to remove or archive an old application, move the application's manifests to `archive/` directory using `git mv`.

# Flux and State

This is a Flux backed repository, as such, pushing to the repository will trigger a Flux reconciliation, affecting the cluster. You should never do this without permission.

# Miroir Restores and Storage Changes

Miroir runs chart `0.12.x`. Backups go through kopiur; VolSync is archived and
Rook/Ceph was retired on 2026-08-11 (manifests under `archive/rook-ceph/` —
don't bring them back unless you're deliberately building a new Ceph cluster).

After every restore or storage change, check all of the following:

- Every replica of the affected volumes is healthy and the restored data has
  been checked by hand.
- No backup jobs are still running.
- No restored volume is stuck with LVM's activation-skip flag. This was an
  upstream bug (home-operations/miroir#490) fixed in `0.12.3`; if it ever
  shows up again, clear it on each node that holds a full copy. Work out the
  volume handle and nodes from the PV and `MiroirVolume`, and never run this
  against a `miroir-snapshot-*` LV:

  ```sh
  lvchange --setactivationskip n vg-miroir-<pool>/<volume-handle>
  lvchange --activate y vg-miroir-<pool>/<volume-handle>
  ```

- No leftover `miroir-snapshot-*` LVs on any data node. Only remove one after
  confirming no `MiroirSnapshot` and no `MiroirVolume.spec.source` points at
  it, and remove them one at a time by name — never with a wildcard.

If you ever restore from the archived VolSync backups: annotate the restore
namespace with `volsync.backube/privileged-movers: "true"` only while the
mover runs, and set `spec.restic.cleanupTempPVC: false` on the
ReplicationDestination so the temporary PVC and its snapshot survive until the
final PVC is `Bound` and its contents are verified.

## Replicas and quorum

`miroir-replicated` keeps 3 full copies of every volume and uses
`quorum: freeze` (since 2026-10-04). A volume only accepts writes while at
least 2 of its 3 copies can see each other.

- **One node down:** nothing happens. Writes carry on with the other two
  copies and the missing copy catches up when the node returns.
- **Two nodes down:** any volume with copies on both of them stops accepting
  writes and its filesystem can go read-only. This is on purpose — it's what
  prevents split-brain. Bring a node back rather than forcing the volume;
  pods recover once 2 copies can talk again (restart them if the filesystem
  went read-only).
- **Split-brain should not happen** under `freeze`. If `MiroirVolumeSplitBrain`
  ever fires anyway (for example on a volume still using
  `last-man-standing`), check both copies with `drbdadm status <res>`, decide
  which side's recent writes you can afford to lose, and on THAT node only:

  ```sh
  drbdadm disconnect <res>
  drbdadm connect --discard-my-data <res>
  ```

- Volumes created before 2026-10-04 were made with 2 copies and
  `last-man-standing`. Changing the StorageClass only affects new volumes;
  existing ones are moved over by editing `MiroirVolume.spec.quorumPolicy`
  and `spec.replicas` directly (both can change on a live volume). Check
  `kubectl get miroirvolumes` for any that still have 2 copies or the old
  policy.
- Pods can run on any node. A pod on a node without a copy reads and writes
  over the network (`allowRemoteVolumeAccess`). Miroir won't move a copy to
  follow it: 3 is the most a volume can have, and Miroir never drops a copy
  on its own. To move a copy, edit `spec.replicas` on the `MiroirVolume`.

## Agent skills

### Issue tracker

Issues and specs are tracked in GitHub Issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

This repository uses a single-context domain-doc layout. See `docs/agents/domain.md`.
