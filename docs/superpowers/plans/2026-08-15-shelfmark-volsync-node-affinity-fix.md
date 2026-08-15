# Shelfmark VolSync Node-Affinity Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Shelfmark backups and prevent its mover from deadlocking when the application changes nodes.

**Architecture:** Change Shelfmark from VolSync `Direct` copy mode to `Snapshot` mode while retaining its existing Miroir snapshot and node-local cache classes. Test the equivalent setting on the live ReplicationSource, replace only the stale mover Job, and verify that a new snapshot-backed backup completes without disrupting Shelfmark.

**Tech Stack:** Flux Kustomization, Kustomize 5.8.1, VolSync 0.16.0, Miroir 0.11.22, Kubernetes

## Global Constraints

- Modify only Shelfmark's VolSync copy method; preserve its repository, schedule, source PVC, retention, storage class, snapshot class, cache class, and mover labels.
- Do not delete or recreate `shelfmark-config-miroir`.
- Use live patching only to test the declarative repository change; Flux remains authoritative.
- Delete only the stale `books/volsync-src-shelfmark-config` Job after verifying its owner.
- Do not push the repository; pushing triggers Flux reconciliation and requires explicit permission.

---

### Task 1: Change and verify Shelfmark's backup copy mode

**Files:**
- Modify: `kubernetes/books/shelfmark/install.yaml:37`
- Test: desired-state assertions, Kustomize render, and live VolSync/Miroir status checks

**Interfaces:**
- Consumes: `shelfmark-config-miroir`, `miroir-snap`, `miroir-replicated`, `miroir-ephemeral`, and `shelfmark-config-restic`.
- Produces: a snapshot-based `books/shelfmark-config` ReplicationSource whose mover may schedule with its existing cache independently of the Shelfmark application node.

- [ ] **Step 1: Run the desired-state assertion and verify it fails**

```bash
python - <<'PY'
from pathlib import Path

text = Path("kubernetes/books/shelfmark/install.yaml").read_text(encoding="utf-8")
assert "VOLSYNC_COPY_METHOD: Snapshot" in text
assert "VOLSYNC_COPY_METHOD: Direct" not in text
PY
```

Expected: exit status `1` with an assertion failure because Shelfmark still uses `Direct`.

- [ ] **Step 2: Make the minimal declarative change**

In `kubernetes/books/shelfmark/install.yaml`, replace exactly:

```yaml
      VOLSYNC_COPY_METHOD: Direct
```

with:

```yaml
      VOLSYNC_COPY_METHOD: Snapshot
```

- [ ] **Step 3: Re-run the assertion and validate repository rendering**

```bash
python - <<'PY'
from pathlib import Path

text = Path("kubernetes/books/shelfmark/install.yaml").read_text(encoding="utf-8")
assert "VOLSYNC_COPY_METHOD: Snapshot" in text
assert "VOLSYNC_COPY_METHOD: Direct" not in text
PY
kustomize build kubernetes/books >/dev/null
git diff --check
git diff -- kubernetes/books/shelfmark/install.yaml
```

Expected: all commands exit `0`; the diff changes only `Direct` to `Snapshot` in the Shelfmark Flux Kustomization.

- [ ] **Step 4: Apply the equivalent live test configuration and replace the stale mover**

```bash
shelfmark_old_job_uid=$(kubectl -n books get job volsync-src-shelfmark-config \
  -o jsonpath='{.metadata.uid}')
test "$(kubectl -n books get job volsync-src-shelfmark-config \
  -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}')" \
  = 'ReplicationSource/shelfmark-config'
shelfmark_trigger=$(date -u +%Y-%m-%dT%H:%M:%SZ)
kubectl -n books patch replicationsource shelfmark-config --type=merge \
  -p "{\"spec\":{\"restic\":{\"copyMethod\":\"Snapshot\"},\"trigger\":{\"manual\":\"${shelfmark_trigger}\"}}}"
kubectl -n books delete job volsync-src-shelfmark-config --cascade=foreground --wait=true
kubectl -n books wait --for=create job/volsync-src-shelfmark-config --timeout=90s
test "$(kubectl -n books get job volsync-src-shelfmark-config -o jsonpath='{.metadata.uid}')" \
  != "$shelfmark_old_job_uid"
```

Expected: the patch reports `patched`; the exact stale Job is deleted; VolSync creates a new Job with a different UID from the snapshot-based ReplicationSource.

- [ ] **Step 5: Verify the new backup completes and the original symptom is absent**

```bash
shelfmark_previous_sync=$(kubectl -n books get replicationsource shelfmark-config \
  -o jsonpath='{.status.lastSyncTime}')
kubectl -n books wait --for=condition=complete job/volsync-src-shelfmark-config --timeout=10m
kubectl -n books logs job/volsync-src-shelfmark-config --all-containers
kubectl -n books get replicationsource shelfmark-config -o yaml
kubectl -n books get pods,pvc,volumesnapshots.snapshot.storage.k8s.io -o wide | rg 'shelfmark|NAME'
test "$(kubectl -n books get replicationsource shelfmark-config \
  -o jsonpath='{.status.latestMoverStatus.result}')" = 'Successful'
test "$(kubectl -n books get replicationsource shelfmark-config \
  -o jsonpath='{.status.lastSyncTime}')" != "$shelfmark_previous_sync"
test "$(kubectl -n books get pod -l app.kubernetes.io/name=shelfmark \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}')" = 'true'
test "$(kubectl get miroirvolume pvc-8fb13c95-9a18-4670-a8dd-06d53d86a923 \
  -o jsonpath='{.status.phase}')" = 'Ready'
```

Expected: the Job completes within ten minutes; restic saves a snapshot; `latestMoverStatus.result` is `Successful`; `lastSyncTime` advances; Shelfmark remains ready; the source MiroirVolume remains `Ready`; and no mover pod has a `FailedScheduling` event.

- [ ] **Step 6: Review and commit the implementation without pushing**

```bash
git diff --check
git diff -- kubernetes/books/shelfmark/install.yaml
git status --short
git add kubernetes/books/shelfmark/install.yaml
git commit -m "fix(books): snapshot shelfmark volsync backups"
git status --short
```

Expected: one local implementation commit containing only the one-line Shelfmark manifest change. The ignored design/plan records may already exist in their own local commits. Do not push.
