# VolSync archive

VolSync was retired on 2026-08-24 after the Kopiur migration completed. This
tree is intentionally inert: its relative paths only work after the manifests
are restored to their original locations.

For an intentional emergency restore:

1. Restore `storage/` to `kubernetes/storage/volsync/`.
2. Restore both directories under `components/` to `kubernetes/components/`.
3. Restore `flux/repositories/backube.yaml` to
   `kubernetes/infra/flux/repositories/backube.yaml` and add it back to that
   directory's `kustomization.yaml`.
4. Add `volsync` back to `kubernetes/storage/kustomization.yaml`.
5. Follow the VolSync restore safeguards in the repository `AGENTS.md`,
   including annotating the restore namespace before starting a mover and
   removing the annotation immediately after it succeeds.
6. Recreate the selected application's `${APP}-restic` ExternalSecret from the
   archived template using the exact `APP` and `VOLSYNC_REPOSITORY` values from
   commit `31dafe44`, then verify that the resulting Secret exists. Restoring
   the component directory alone does not create per-application credentials.
7. Narrow `storage/restores/app/restores.yaml` to the one intended destination
   before enabling the suspended restore Kustomization. Do not launch the
   aggregate restore set.

Remote Restic data and the shared `volsync-garage` credential record are
retained through at least 2026-11-22. Their deletion requires a separate
explicit decision. The Garage bucket and credential record also back Kopiur
and must remain after the Restic prefixes expire.
