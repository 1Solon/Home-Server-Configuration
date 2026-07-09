# tasks

## Update PR Review Plan

Use this plan to review all open update PRs for this repository one at a time. Treat migrations as an approval-gated action: identify them, explain them, and do not perform them until approval is given.

### Goal

Review each open dependency, container, Helm chart, Talos, Kubernetes, or GitOps update PR; determine whether it requires a migration; apply approved safe patches; and finish with a concise summary of patched work plus the five most interesting or useful new features.

### Constraints

- Do not run cluster-mutating commands unless the migration or validation step explicitly requires it and approval has been granted.
- Do not merge PRs as part of this plan unless merge approval is explicitly given.
- Work one PR at a time so migration risk and validation output stay tied to a single update.
- Preserve unrelated local changes and never revert changes you did not make.
- Prefer manifest validation with `kustomize build kubernetes/<area>` or `kubectl kustomize kubernetes/<area>` for affected Kubernetes trees.

### Step 1: Find Update PRs

1. List open PRs for this repository.
2. Select PRs that update dependencies, containers, Helm charts, Talos, Kubernetes, operators, CRDs, or application versions.
3. Record the PR number, title, branch, affected service or subsystem, and update source.

Useful commands:

```sh
gh pr list --state open --json number,title,author,headRefName,url,labels
gh pr view <pr-number> --json number,title,body,files,commits,headRefName,url
```

### Step 2: Review One PR

For the current PR:

1. Read the PR body, changed files, commit list, and generated update notes.
2. Identify the workload path, for example `kubernetes/media/jellyfin` or `kubernetes/storage/postgres`.
3. Read upstream release notes for the old version to the new version.
4. Check chart, image, operator, and CRD changelogs separately when they are versioned independently.
5. Note any changed configuration keys, default values, environment variables, ports, storage paths, CRDs, permissions, or database behavior.

### Step 3: Decide Whether Migration Is Required

Mark the PR as requiring migration if any of the following are true:

- Upstream release notes mention migration, manual upgrade, breaking change, data migration, schema migration, reindexing, resyncing, or one-way upgrade.
- A database, object store, persistent volume, cache format, media library, index, or on-disk path changes.
- A Helm chart changes CRDs, removes values, renames values, changes selectors, or changes resource ownership.
- An operator update changes managed resource versions or conversion webhooks.
- Authentication, secrets, tokens, SSO callbacks, permissions, or network policy behavior changes.
- The update requires running an admin command, Kubernetes job, shell command, one-time script, backup, restore, or manual UI action.
- Rollback is not cleanly supported after the update.

If none of these apply, mark the PR as `migration not required` and record the evidence, including release note links or changelog excerpts.

### Step 4: Approval Gate For Migrations

If migration is required, stop before performing it and ask for approval with this format:

```md
PR: #<number> <title>
Migration required: yes
Reason: <specific upstream note or manifest change>
Risk: <data loss, downtime, rollback limitation, schema change, or service interruption>
Proposed migration steps:
1. <backup or precheck>
2. <migration action>
3. <validation>
Rollback plan: <what is possible and what is not>
Approve migration? yes/no
```

Do not perform the migration, run migration commands, or patch manifests that depend on the migration until approval is granted.

### Step 5: Patch And Validate The PR

After deciding migration status, and after approval if migration is required:

1. Apply the smallest necessary patch to make the PR safe and consistent with this repository.
2. Update nearby `kustomization.yaml` files only when adding or removing manifests.
3. Validate the affected Kubernetes area with `kustomize build kubernetes/<area>` or `kubectl kustomize kubernetes/<area>`.
4. For Talos changes, run `task gen` and review generated diffs before any apply step.
5. Capture validation commands and results for the final summary.

### Step 6: Repeat For Each PR

Move to the next update PR only after the current PR has one of these outcomes:

- Patched and validated.
- No patch needed and migration not required.
- Waiting for migration approval.
- Skipped with a clear reason.

### Step 7: Final Report

When all update PRs have been reviewed, report:

```md
Patched:
- #<number> <title>: <short description of what changed>

Migration decisions:
- #<number> <title>: migration required/not required; <evidence or approval status>

Validation:
- `<command>`: <result>

Top five useful or interesting new features:
1. <feature and why it matters>
2. <feature and why it matters>
3. <feature and why it matters>
4. <feature and why it matters>
5. <feature and why it matters>

Blocked or skipped:
- #<number> <title>: <reason>
```

Keep the final report short. Use the feature cliff notes for user-facing value, not every patch note from every upstream changelog.
