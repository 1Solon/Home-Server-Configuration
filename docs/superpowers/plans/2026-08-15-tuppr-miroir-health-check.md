# Tuppr Miroir Health Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the obsolete Ceph health checks in both Tuppr upgrade resources with a cluster-wide Miroir volume readiness gate.

**Architecture:** Keep the existing VolSync synchronization gate and change only the storage-specific health check in each upgrade custom resource. Tuppr will list every cluster-scoped `MiroirVolume` and require its controller-maintained `status.phase` to equal `Ready` before an upgrade proceeds.

**Tech Stack:** Kubernetes YAML, Tuppr `v1alpha1` custom resources, Miroir `v1alpha1` custom resources, CEL, Kustomize 5.8.1

## Global Constraints

- Modify only the two Tuppr upgrade manifests; do not mutate the live cluster.
- Preserve each existing VolSync `ReplicationSource` health check verbatim.
- Use `apiVersion: miroir.home-operations.com/v1alpha1`, `kind: MiroirVolume`, and `status.phase == 'Ready'`.
- Do not add a resource name, namespace, label selector, timeout, migration, secret, or DNS change.
- Keep YAML formatting consistent with the existing files.

---

### Task 1: Replace the retired storage health gates

**Files:**
- Modify: `kubernetes/infra/tuppr/upgrades/talos.yaml:21-27`
- Modify: `kubernetes/infra/tuppr/upgrades/kubernetes.yaml:16-19`

**Interfaces:**
- Consumes: Tuppr's `HealthCheckSpec` fields `apiVersion`, `kind`, and `expr`; Miroir's cluster-scoped `MiroirVolume.status.phase`.
- Produces: A pre-upgrade gate in both resources that passes only when every existing `MiroirVolume` has phase `Ready`.

- [ ] **Step 1: Run the desired-state assertion and verify it fails against the Ceph configuration**

Run:

```bash
for file in kubernetes/infra/tuppr/upgrades/talos.yaml kubernetes/infra/tuppr/upgrades/kubernetes.yaml; do
  rg -q 'apiVersion: miroir\.home-operations\.com/v1alpha1' "$file" &&
    rg -q 'kind: MiroirVolume' "$file" &&
    rg -q "status\.phase == 'Ready'" "$file" &&
    ! rg -q 'ceph\.rook\.io|CephCluster|status\.ceph' "$file"
done
```

Expected: non-zero exit status because both manifests still contain Ceph checks and do not contain Miroir checks.

- [ ] **Step 2: Replace each Ceph block with the minimal Miroir check**

In both files, leave the preceding VolSync block unchanged and make the second health check exactly:

```yaml
        - apiVersion: miroir.home-operations.com/v1alpha1
          kind: MiroirVolume
          expr: |-
              status.phase == 'Ready'
```

- [ ] **Step 3: Re-run the desired-state assertion**

Run:

```bash
for file in kubernetes/infra/tuppr/upgrades/talos.yaml kubernetes/infra/tuppr/upgrades/kubernetes.yaml; do
  rg -q 'apiVersion: miroir\.home-operations\.com/v1alpha1' "$file" &&
    rg -q 'kind: MiroirVolume' "$file" &&
    rg -q "status\.phase == 'Ready'" "$file" &&
    ! rg -q 'ceph\.rook\.io|CephCluster|status\.ceph' "$file"
done
```

Expected: exit status 0.

- [ ] **Step 4: Render the focused Kustomize tree and inspect both health-check lists**

Run:

```bash
kustomize build kubernetes/infra/tuppr/upgrades >/tmp/tuppr-upgrades-rendered.yaml
rg -n -C 4 'kind: (TalosUpgrade|KubernetesUpgrade)|kind: (ReplicationSource|MiroirVolume)|status\.phase' /tmp/tuppr-upgrades-rendered.yaml
```

Expected: Kustomize exits 0; both upgrade resources contain one `ReplicationSource` check and one `MiroirVolume` check with `status.phase == 'Ready'`.

- [ ] **Step 5: Perform repository-level static verification**

Run:

```bash
git diff --check
git diff -- kubernetes/infra/tuppr/upgrades/talos.yaml kubernetes/infra/tuppr/upgrades/kubernetes.yaml
rg -n 'ceph\.rook\.io|kind: CephCluster|status\.ceph' kubernetes/infra/tuppr/upgrades
```

Expected: `git diff --check` exits 0; the diff changes only the second health-check block in each manifest; the final `rg` returns no matches and exits 1.

- [ ] **Step 6: Commit the manifest change**

```bash
git add kubernetes/infra/tuppr/upgrades/talos.yaml kubernetes/infra/tuppr/upgrades/kubernetes.yaml
git commit -m "replaces ceph tuppr health checks with miroir"
```

Expected: one commit containing only the two upgrade manifests.
