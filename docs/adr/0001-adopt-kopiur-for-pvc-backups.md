---
status: accepted
---

# Adopt Kopiur for PVC backups

Replace VolSync with Kopiur as the cluster's PVC backup and restore operator. Kopiur provides the preferred Kopia-native lifecycle and restore model, but it is alpha, uses an incompatible repository format from the existing Restic repositories, and does not inherently eliminate Miroir's snapshot-staging failure class. The migration will therefore be staged and reversible through retained remote recovery history rather than performed as an in-place cutover.

## Decision

Pin Kopiur chart, CRDs, and CLI to version `0.10.3`. Flux will manage CRDs separately and reconcile them before the controller. Protected applications will use one namespaced Kopia repository per application namespace on Garage, deterministic six-hour schedules, the existing GFS retention contract, ownership-preserving movers, and Kopiur's Snapshot-default behavior. Safety-critical defaults will be recorded explicitly in Git.

Migrate workloads in recovery-complexity waves. Every retained workload must complete backup, scratch restore, content and ownership validation, replacement-PVC restore, application startup validation, a post-cutover backup, and Miroir health checks. Old PVCs will be deleted rather than retained after successful cutover. Application PVCs remain protected even when CloudNativePG owns their PostgreSQL recovery; CloudNativePG database volumes are outside Kopiur's scope. The rebuildable `seerr-config-cache` will be used for testing and then removed from permanent protection.

VolSync and Kopiur will overlap until every retained workload has three monthly Kopiur recovery points, no stale or failed policy, and at least two successful restores. VolSync manifests will then be archived with `git mv`. Restic repositories, credentials, and archived restore manifests will remain available for another 90 days and require a separate explicit decision before deletion.

## Consequences

Kopiur monitoring and an equivalent Tuppr idle/readiness gate are cutover requirements. Snapshot failures are investigated first; repeated failures that prevent the six-hour RPO may justify a workload-specific Direct policy. Any corruption, ownership loss, unhealthy Miroir replica, activation-skip flag, or orphan snapshot LV blocks rollout. Off-site repository replication and broader application-consistency improvements are separate follow-up work.

See [`docs/research/kopiur-vs-volsync-miroir.md`](../research/kopiur-vs-volsync-miroir.md) and [`docs/research/kopiur-copy-method-prevalence.md`](../research/kopiur-copy-method-prevalence.md).
