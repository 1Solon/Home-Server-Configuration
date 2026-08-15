# Tuppr Miroir Health Check Design

## Goal

Replace the obsolete Rook Ceph health gates in both Tuppr upgrade resources with a storage-health gate that reflects the cluster's current Miroir deployment.

## Findings

The repository no longer deploys Rook Ceph, but both `TalosUpgrade` and `KubernetesUpgrade` still list a `CephCluster` health check. Tuppr therefore attempts to list a retired custom resource before allowing upgrades.

A Kubesearch comparison identified ten other repositories that deploy both Tuppr and Miroir. One already gates upgrades on `MiroirVolume` readiness, four do not use a storage health gate, and five retain stale Ceph checks. The Miroir-specific example uses:

```yaml
- apiVersion: miroir.home-operations.com/v1alpha1
  kind: MiroirVolume
  expr: status.phase == 'Ready'
```

Miroir 0.11.22 defines `status.phase` as `Creating`, `Ready`, `Degraded`, or `Failed`. Its controller computes `Ready` only when every diskful replica is realized, connected when replicated, and reporting a fresh probe. This makes the phase suitable as a pre-upgrade safety gate.

Tuppr evaluates an unnamed health check against every resource of the selected kind. All Miroir volumes must therefore be `Ready`. If no Miroir volumes exist, the check passes, matching Tuppr's existing all-resource behavior.

## Design

In both `kubernetes/infra/tuppr/upgrades/talos.yaml` and `kubernetes/infra/tuppr/upgrades/kubernetes.yaml`:

- Keep the existing VolSync `ReplicationSource` check unchanged.
- Remove the `ceph.rook.io/v1` `CephCluster` check.
- Add a `miroir.home-operations.com/v1alpha1` `MiroirVolume` check.
- Require `status.phase == 'Ready'` for every Miroir volume.

The check remains cluster-wide because `MiroirVolume` is cluster-scoped. No resource name, namespace, selector, or custom timeout is required.

## Failure Behavior

Tuppr will wait when any Miroir volume is `Creating`, `Degraded`, or `Failed`, preventing a Talos node reboot or Kubernetes upgrade from beginning while replicated storage is unhealthy. Existing VolSync synchronization protection remains independent and unchanged.

The change does not modify live cluster state directly. Flux will reconcile it only after the resulting commit is pushed through the normal GitOps workflow.

## Validation

1. Render `kubernetes/infra/tuppr/upgrades` with Kustomize.
2. Render the parent `kubernetes/infra` tree if it is a valid Kustomize entry point.
3. Confirm both rendered upgrade resources contain the VolSync and Miroir checks and contain no `CephCluster` references.
4. Confirm the working diff is limited to the design record and the two Tuppr upgrade manifests.

No migration, secret, DNS, or cluster-mutating command is required.
