# Hermes Deployment Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate Hermes into one S6-supervised container, remove obsolete initialization and sidecar plumbing, and preserve its endpoints, integrations, storage, optional tools, and effective read-only Kubernetes access.

**Architecture:** Two ordered init containers first install a migrated Git-managed configuration and then reconcile optional CLI tools. One Hermes container runs `hermes gateway run`; `HERMES_DASHBOARD=true` activates the image's supervised dashboard on the same pod. RBAC moves into native manifests without changing permissions.

**Tech Stack:** Flux, Kustomize, HelmRelease, bjw-s app-template 5.0.1, Kubernetes RBAC, Hermes Agent v2026.7.20, S6, Bash, Python/PyYAML, Helm, kubeconform, Docker.

## Global Constraints

- Keep `nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a`.
- Keep the API Service, dashboard Service, HTTPRoute, hostnames, PVC, and secret mappings.
- Preserve Codex, Authentik OIDC, Discord, Firecrawl, SearXNG, Grafana MCP, OpenRouter vision support, and VolSync.
- Keep `Recreate`, the 600-second termination grace period, Helm remediation, and the `4Gi` memory limit.
- Set application requests to `cpu: 250m` and `memory: 1Gi`; do not add a CPU limit.
- Keep effective RBAC identical, read-only, and free of Kubernetes Secret access.
- Keep Git authoritative for `config.yaml` and `SOUL.md`.
- Do not add a custom image or NetworkPolicy.
- Do not patch/apply live resources, reconcile Flux, push commits, or otherwise deploy without explicit permission.
- Preserve unrelated worktree changes; every commit in this plan remains local until deployment is authorized.

## File Structure

- Modify `kubernetes/ai/hermes/app/resources/config.yaml`: current-schema, Git-managed Hermes behavior.
- Create `kubernetes/ai/hermes/app/rbac.yaml`: native ClusterRole and ClusterRoleBinding with the existing permissions.
- Modify `kubernetes/ai/hermes/app/kustomization.yaml`: include native RBAC and retain generated config resources.
- Modify `kubernetes/ai/hermes/install.yaml`: remove only the stale Llama dependency.
- Modify `kubernetes/ai/hermes/app/release.yaml`: ordered init containers, verified optional tools, one S6 runtime container, probes, services, mounts, and resources.

---

### Task 1: Capture baselines and clean Hermes configuration

**Files:**
- Modify: `kubernetes/ai/hermes/app/resources/config.yaml`

**Interfaces:**
- Consumes: the pinned Hermes image and current live/read-only cluster access.
- Produces: a current declarative config whose CLI platform uses only the `hermes-cli` preset; `.tmp/hermes-cleanup/baseline-render.yaml` and `.tmp/hermes-cleanup/baseline-rbac.json` for later permission comparison.

- [ ] **Step 1: Verify the worktree and required local tools**

```bash
git status --short
python - <<'PY'
import yaml
print("PyYAML", yaml.__version__)
PY
helm version --short
kustomize version
kubeconform -v
docker version --format '{{.Client.Version}}'
```

Expected: no unexpected worktree paths; PyYAML, Helm, Kustomize, kubeconform, and Docker report versions. Stop and preserve any unrelated changes rather than resetting them.

Keep generated evidence out of Git with a local-only exclude:

```bash
grep -qxF '.tmp/' .git/info/exclude || printf '\n.tmp/\n' >> .git/info/exclude
mkdir -p .tmp/hermes-cleanup
```

Expected: `.tmp/` is ignored only in this clone; no tracked file changes.

- [ ] **Step 2: Capture the source, chart, and read-only live baselines**

```bash
kustomize build kubernetes/ai/hermes/app > .tmp/hermes-cleanup/baseline-source.yaml
python - <<'PY' | helm template hermes oci://ghcr.io/bjw-s-labs/helm/app-template \
  --version 5.0.1 --namespace ai -f - > .tmp/hermes-cleanup/baseline-render.yaml
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
print(yaml.safe_dump(release["spec"]["values"], sort_keys=False))
PY
python - <<'PY'
import json, yaml

def canonical(rules):
    keys = ("apiGroups", "resources", "resourceNames", "nonResourceURLs", "verbs")
    return sorted(
        tuple(tuple(sorted(rule.get(key, []))) for key in keys)
        for rule in rules
    )

docs = [d for d in yaml.safe_load_all(open(".tmp/hermes-cleanup/baseline-render.yaml", encoding="utf-8")) if isinstance(d, dict)]
role = next(d for d in docs if d.get("kind") == "ClusterRole" and d["metadata"]["name"] == "hermes")
json.dump(canonical(role["rules"]), open(".tmp/hermes-cleanup/baseline-rbac.json", "w", encoding="utf-8"), indent=2)
print("baseline rules:", len(role["rules"]))
PY
kubectl -n flux-system get kustomization hermes
kubectl -n ai get helmrelease hermes
kubectl -n ai get pod,service,httproute,pvc -l app.kubernetes.io/name=hermes
kubectl auth can-i --as=system:serviceaccount:ai:hermes --list > .tmp/hermes-cleanup/baseline-can-i.txt
```

Expected: Helm renders three init containers and two regular containers; the baseline ClusterRole has the current rule set; Flux and Helm report Ready. These commands only read the cluster.

- [ ] **Step 3: Run a failing assertion for the desired config shape**

```bash
python - <<'PY'
import yaml
cfg = yaml.safe_load(open("kubernetes/ai/hermes/app/resources/config.yaml", encoding="utf-8"))
assert "toolsets" not in cfg, "deprecated top-level toolsets still exists"
assert cfg["platform_toolsets"]["cli"] == ["hermes-cli"]
print("Hermes config shape is current")
PY
```

Expected: FAIL on the deprecated `toolsets` block and/or the extra CLI toolsets.

- [ ] **Step 4: Replace `config.yaml` with the approved current configuration**

```yaml
---
model:
  provider: openai-codex
  default: gpt-5.6-sol
web:
  backend: firecrawl
dashboard:
  theme: mono
  font: jetbrains-mono
mcp_servers:
  grafana:
    url: http://mcp-grafana.observability.svc.cluster.local:8000/mcp
    timeout: 60
    connect_timeout: 30
terminal:
  backend: local
  cwd: /opt/data/workspace
  timeout: 180
  persistent_shell: true
memory:
  auto_migrate: true
  auto_summarize:
    threshold: 50
approvals:
  destructive_slash_confirm: false
compression:
  enabled: true
  codex_gpt55_autoraise: false
  codex_gpt55_autoraise_notice: false
display:
  streaming: true
  tool_progress: true
  show_reasoning: true
  skin: mono
agent:
  reasoning_effort: high
streaming:
  enabled: true
security:
  redact_secrets: true
command_allowlist:
  - script execution via -e/-c flag
privacy:
  redact_pii: true
platform_toolsets:
  cli:
    - hermes-cli
_config_version: 33
```

- [ ] **Step 5: Re-run the assertion and validate migration with the pinned image**

```bash
python - <<'PY'
import yaml
cfg = yaml.safe_load(open("kubernetes/ai/hermes/app/resources/config.yaml", encoding="utf-8"))
assert "toolsets" not in cfg
assert cfg["platform_toolsets"] == {"cli": ["hermes-cli"]}
assert cfg["mcp_servers"]["grafana"]["url"].endswith("/mcp")
assert cfg["_config_version"] == 33
print("Hermes config shape is current")
PY
docker run --rm --entrypoint /bin/bash \
  -v "$PWD/kubernetes/ai/hermes/app/resources/config.yaml:/desired/config.yaml:ro" \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  -c 'set -euo pipefail; mkdir -p /staging; cp /desired/config.yaml /staging/config.yaml; touch /staging/.env; HERMES_HOME=/staging HOME=/staging /opt/hermes/.venv/bin/python - <<"PY"
from hermes_cli.config import migrate_config
migrate_config(interactive=False, quiet=False)
import yaml
data = yaml.safe_load(open("/staging/config.yaml", encoding="utf-8"))
assert data["_config_version"] == 33
assert data["platform_toolsets"]["cli"] == ["hermes-cli"]
print("staged migration valid")
PY'
kustomize build kubernetes/ai/hermes/app | kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

Expected: both Python checks print success; the container exits zero without prompting; kubeconform reports three valid resources and zero invalid/errors.

- [ ] **Step 6: Commit the configuration cleanup**

```bash
git add kubernetes/ai/hermes/app/resources/config.yaml
git commit -m "fix(hermes): update declarative toolsets"
```

Expected: one local commit containing only `config.yaml`.

---

### Task 2: Extract RBAC and remove the stale Flux dependency

**Files:**
- Create: `kubernetes/ai/hermes/app/rbac.yaml`
- Modify: `kubernetes/ai/hermes/app/kustomization.yaml`
- Modify: `kubernetes/ai/hermes/app/release.yaml`
- Modify: `kubernetes/ai/hermes/install.yaml`

**Interfaces:**
- Consumes: `.tmp/hermes-cleanup/baseline-render.yaml` and `.tmp/hermes-cleanup/baseline-rbac.json` from Task 1.
- Produces: `ClusterRole/hermes-read-all`, `ClusterRoleBinding/hermes-read-all`, unchanged effective rules, and Flux dependencies on only Grafana MCP and VolSync.

- [ ] **Step 1: Run failing structural assertions**

```bash
python - <<'PY'
from pathlib import Path
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
install = yaml.safe_load(open("kubernetes/ai/hermes/install.yaml", encoding="utf-8"))
kustomization = yaml.safe_load(open("kubernetes/ai/hermes/app/kustomization.yaml", encoding="utf-8"))
assert Path("kubernetes/ai/hermes/app/rbac.yaml").exists(), "rbac.yaml is missing"
assert "rbac" not in release["spec"]["values"], "RBAC remains inline"
assert "./rbac.yaml" in kustomization["resources"]
assert "llama" not in {item["name"] for item in install["spec"]["dependsOn"]}
PY
```

Expected: FAIL because `rbac.yaml` is missing and RBAC is still inline.

- [ ] **Step 2: Generate native RBAC from the captured chart baseline**

```bash
python - <<'PY'
from pathlib import Path
import yaml

docs = [d for d in yaml.safe_load_all(open(".tmp/hermes-cleanup/baseline-render.yaml", encoding="utf-8")) if isinstance(d, dict)]
old_role = next(d for d in docs if d.get("kind") == "ClusterRole" and d["metadata"]["name"] == "hermes")
output = [
    {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "ClusterRole",
        "metadata": {"name": "hermes-read-all"},
        "rules": old_role["rules"],
    },
    {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "ClusterRoleBinding",
        "metadata": {"name": "hermes-read-all"},
        "roleRef": {
            "apiGroup": "rbac.authorization.k8s.io",
            "kind": "ClusterRole",
            "name": "hermes-read-all",
        },
        "subjects": [{"kind": "ServiceAccount", "name": "hermes", "namespace": "ai"}],
    },
]
text = yaml.safe_dump_all(output, explicit_start=True, sort_keys=False)
Path("kubernetes/ai/hermes/app/rbac.yaml").write_text(text, encoding="utf-8")
PY
```

Expected: `rbac.yaml` contains one ClusterRole and one ClusterRoleBinding; the rules are copied exactly from the pre-change chart render.

- [ ] **Step 3: Register native RBAC and remove only inline RBAC**

Replace `kubernetes/ai/hermes/app/kustomization.yaml` with:

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./externalsecret.yaml
  - ./rbac.yaml
  - ./release.yaml
configMapGenerator:
  - name: hermes-config
    files:
      - ./resources/config.yaml
      - ./resources/SOUL.md
generatorOptions:
  disableNameSuffixHash: true
```

Delete the complete `values.rbac` mapping from `release.yaml`. Leave the end of `values` as:

```yaml
    serviceAccount:
      hermes: {}
```

Do not remove `controllers.hermes.serviceAccount.identifier: *app`.

- [ ] **Step 4: Remove only the Llama dependency**

Replace the `dependsOn` block in `kubernetes/ai/hermes/install.yaml` with:

```yaml
  dependsOn:
    - name: grafana-mcp
    - name: volsync
      namespace: flux-system
```

Keep every VolSync substitution unchanged.

- [ ] **Step 5: Re-run structural and permission-equivalence tests**

```bash
python - <<'PY'
from pathlib import Path
import json, yaml

def canonical(rules):
    keys = ("apiGroups", "resources", "resourceNames", "nonResourceURLs", "verbs")
    return sorted(tuple(tuple(sorted(rule.get(key, []))) for key in keys) for rule in rules)

release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
install = yaml.safe_load(open("kubernetes/ai/hermes/install.yaml", encoding="utf-8"))
kustomization = yaml.safe_load(open("kubernetes/ai/hermes/app/kustomization.yaml", encoding="utf-8"))
rbac_docs = list(yaml.safe_load_all(open("kubernetes/ai/hermes/app/rbac.yaml", encoding="utf-8")))
role = next(d for d in rbac_docs if d["kind"] == "ClusterRole")
baseline = json.load(open(".tmp/hermes-cleanup/baseline-rbac.json", encoding="utf-8"))
assert "rbac" not in release["spec"]["values"]
assert "./rbac.yaml" in kustomization["resources"]
assert {item["name"] for item in install["spec"]["dependsOn"]} == {"grafana-mcp", "volsync"}
assert canonical(role["rules"]) == [tuple(tuple(x) for x in rule) for rule in baseline]
assert all(set(rule["verbs"]) == {"get", "list", "watch"} for rule in role["rules"])
assert all("secrets" not in rule.get("resources", []) for rule in role["rules"])
print("RBAC is permission-equivalent and secret-free")
PY
kustomize build kubernetes/ai/hermes/app | kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
```

Expected: the Python check prints success; kubeconform reports five valid resources, zero invalid, and zero errors.

- [ ] **Step 6: Commit the RBAC and dependency cleanup**

```bash
git add kubernetes/ai/hermes/app/rbac.yaml \
  kubernetes/ai/hermes/app/kustomization.yaml \
  kubernetes/ai/hermes/app/release.yaml \
  kubernetes/ai/hermes/install.yaml
git commit -m "refactor(hermes): extract read-only cluster RBAC"
```

Expected: one local commit containing native RBAC, its Kustomize registration, removal of inline chart RBAC, and removal of the Llama dependency.

---

### Task 3: Make configuration initialization deterministic and fail-closed

**Files:**
- Modify: `kubernetes/ai/hermes/app/release.yaml`

**Interfaces:**
- Consumes: ConfigMap files `config.yaml` and `SOUL.md`, PVC `/opt/data`, and pinned Hermes migration API `migrate_config(interactive=False, quiet=False)`.
- Produces: migrated files `/opt/data/config.yaml` and `/opt/data/SOUL.md`, mode `0600`, owner/group `10000:10000`; preserved `/opt/data/.env`; deterministic `init-config` → `install-tools` ordering.

- [ ] **Step 1: Run a failing source assertion for deterministic initialization**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
inits = release["spec"]["values"]["controllers"]["hermes"]["initContainers"]
script = "\n".join(inits["init-config"]["command"])
assert inits["init-config"]["image"]["repository"] == "nousresearch/hermes-agent"
assert inits["install-tools"]["dependsOn"] == "init-config"
assert "migrate_config(interactive=False" in script
assert "AGENTMEMORY" not in script
assert "/staging" in script and "/desired" in script
PY
```

Expected: FAIL because `init-config` still uses Alpine and no explicit dependency or staged migration exists.

- [ ] **Step 2: Replace `init-config` with the pinned-image staged migration**

Use this complete init-container block. The tag anchor is defined here and reused by later Hermes containers:

```yaml
          init-config:
            image:
              repository: nousresearch/hermes-agent
              tag: &hermesTag v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a
            command:
              - /bin/bash
              - -c
              - |
                set -euo pipefail
                umask 077

                rm -rf /staging/* /staging/.[!.]* /staging/..?* 2>/dev/null || true
                cp /desired/config.yaml /staging/config.yaml
                cp /desired/SOUL.md /staging/SOUL.md
                touch /staging/.env

                HERMES_HOME=/staging HOME=/staging /opt/hermes/.venv/bin/python - <<'PY'
                from hermes_cli.config import migrate_config
                migrate_config(interactive=False, quiet=False)
                PY

                /opt/hermes/.venv/bin/python - <<'PY'
                from pathlib import Path
                import yaml
                path = Path("/staging/config.yaml")
                data = yaml.safe_load(path.read_text(encoding="utf-8"))
                if not isinstance(data, dict):
                    raise SystemExit("migrated config is not a YAML mapping")
                if data.get("_config_version") != 33:
                    raise SystemExit("migrated config version is not 33")
                PY

                install -d -o 10000 -g 10000 -m 0750 /opt/data/workspace
                install -o 10000 -g 10000 -m 0600 /staging/config.yaml /opt/data/.config.yaml.new
                install -o 10000 -g 10000 -m 0600 /staging/SOUL.md /opt/data/.SOUL.md.new
                mv -f /opt/data/.config.yaml.new /opt/data/config.yaml
                mv -f /opt/data/.SOUL.md.new /opt/data/SOUL.md
                if [ -e /opt/data/.env ]; then
                  chown 0:0 /opt/data/.env
                  chmod 0600 /opt/data/.env
                  chown 10000:10000 /opt/data/.env
                else
                  install -o 10000 -g 10000 -m 0600 /dev/null /opt/data/.env
                fi
            securityContext:
              runAsUser: 0
              runAsGroup: 0
              runAsNonRoot: false
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop:
                  - ALL
                add:
                  - CHOWN
```

Do not retain `rm -rf /opt/data/plugins/agentmemory` or the `AGENTMEMORY_SECRET` edit.

- [ ] **Step 3: Make tool initialization depend on config initialization**

Add this field directly below `install-tools:` and before its image:

```yaml
            dependsOn: init-config
```

app-template 5.0.1 accepts either a string or list here; use the string because there is one dependency.

- [ ] **Step 4: Replace the ConfigMap mounts and add staging storage**

Replace the `config-file` persistence item with:

```yaml
      config-file:
        type: configMap
        name: hermes-config
        advancedMounts:
          hermes:
            init-config:
              - path: /desired/config.yaml
                subPath: config.yaml
                readOnly: true
              - path: /desired/SOUL.md
                subPath: SOUL.md
                readOnly: true
```

Add this adjacent persistence item:

```yaml
      config-staging:
        type: emptyDir
        advancedMounts:
          hermes:
            init-config:
              - path: /staging
```

Add an `init-config` subpath to the existing `tmpfs` advanced mounts:

```yaml
            init-config:
              - path: /tmp
                subPath: init-config
```

Keep the PVC mounted at `/opt/data` for `init-config`.

- [ ] **Step 5: Re-run source assertions and render the chart**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
values = release["spec"]["values"]
inits = values["controllers"]["hermes"]["initContainers"]
script = "\n".join(inits["init-config"]["command"])
assert inits["init-config"]["image"]["repository"] == "nousresearch/hermes-agent"
assert inits["install-tools"]["dependsOn"] == "init-config"
assert "migrate_config(interactive=False" in script
assert "AGENTMEMORY" not in script
assert values["persistence"]["config-staging"]["type"] == "emptyDir"
print("staged config init is deterministic")
PY
python - <<'PY' | helm template hermes oci://ghcr.io/bjw-s-labs/helm/app-template \
  --version 5.0.1 --namespace ai -f - > .tmp/hermes-cleanup/config-init-render.yaml
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
print(yaml.safe_dump(release["spec"]["values"], sort_keys=False))
PY
python - <<'PY'
import yaml
docs = [d for d in yaml.safe_load_all(open(".tmp/hermes-cleanup/config-init-render.yaml", encoding="utf-8")) if isinstance(d, dict)]
deployment = next(d for d in docs if d.get("kind") == "Deployment")
names = [c["name"] for c in deployment["spec"]["template"]["spec"]["initContainers"]]
assert names.index("init-config") < names.index("install-tools")
print("rendered init order:", names)
PY
```

Expected: source assertion succeeds; Helm schema validation succeeds; rendered `init-config` precedes `install-tools`.

- [ ] **Step 6: Extract and statically check the init script**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
script = release["spec"]["values"]["controllers"]["hermes"]["initContainers"]["init-config"]["command"][-1]
open(".tmp/hermes-cleanup/init-config.sh", "w", newline="\n", encoding="utf-8").write(script)
PY
bash -n .tmp/hermes-cleanup/init-config.sh
docker run --rm -i koalaman/shellcheck-alpine:v0.10.0 --shell=bash - \
  < .tmp/hermes-cleanup/init-config.sh
```

Expected: Bash syntax passes; ShellCheck reports no errors. Review warnings before proceeding rather than suppressing them globally.

- [ ] **Step 7: Commit deterministic config initialization**

```bash
git add kubernetes/ai/hermes/app/release.yaml
git commit -m "fix(hermes): migrate declarative config before startup"
```

Expected: one local commit containing staged migration, mounts, and explicit init ordering.

---

### Task 4: Reconcile verified multi-architecture optional tools

**Files:**
- Modify: `kubernetes/ai/hermes/app/release.yaml`

**Interfaces:**
- Consumes: writable PVC `/opt/data`, temporary `/tmp`, system `curl`, `tar`, `sha256sum`, and `git` from the pinned image.
- Produces: GitHub CLI 2.96.0, Go 1.26.5, and Homebrew 6.0.12 under `/opt/data/.local`; supports amd64 and arm64; leaves valid existing tools untouched on failure.

- [ ] **Step 1: Run a failing assertion for approved pins and safety behavior**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
init = release["spec"]["values"]["controllers"]["hermes"]["initContainers"]["install-tools"]
script = init["command"][-1]
for expected in (
    "GH_VERSION=2.96.0",
    "GO_VERSION=1.26.5",
    "BREW_VERSION=6.0.12",
    "x86_64)",
    "aarch64|arm64)",
    "sha256sum -c",
    "b48c7994b5f0eed7bef532efa63cb4e4f763887a",
):
    assert expected in script, expected
assert "/opt/data/.local/bin/hermes" not in script
assert "/opt/data/.local/bin/docker" not in script
PY
```

Expected: FAIL because the current script has old amd64-only downloads and deletes Hermes/Docker wrappers.

- [ ] **Step 2: Replace `install-tools` with the complete fail-soft reconciler**

```yaml
          install-tools:
            dependsOn: init-config
            image:
              repository: nousresearch/hermes-agent
              tag: *hermesTag
            command:
              - /bin/bash
              - -c
              - |
                set -uo pipefail
                umask 022

                GH_VERSION=2.96.0
                GO_VERSION=1.26.5
                BREW_VERSION=6.0.12
                BREW_COMMIT=b48c7994b5f0eed7bef532efa63cb4e4f763887a
                LOCAL=/opt/data/.local
                BIN="$LOCAL/bin"
                mkdir -p "$BIN"

                warn() { printf 'install-tools: warning: %s\n' "$*" >&2; }

                case "$(uname -m)" in
                  x86_64)
                    ARCH=amd64
                    GH_SHA=83d5c2ccad5498f58bf6368acb1ab32588cf43ab3a4b1c301bf36328b1c8bd60
                    GO_SHA=5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053
                    ;;
                  aarch64|arm64)
                    ARCH=arm64
                    GH_SHA=06f86ec7103d41993b76cd78072f43595c34aaa56506d971d9860e67140bf909
                    GO_SHA=fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49
                    ;;
                  *)
                    warn "unsupported architecture $(uname -m); leaving optional tools unchanged"
                    exit 0
                    ;;
                esac

                download_verified() {
                  url=$1
                  sha=$2
                  destination=$3
                  if ! curl -fsSL --retry 3 --retry-delay 2 "$url" -o "$destination"; then
                    warn "download failed: $url"
                    return 1
                  fi
                  if ! printf '%s  %s\n' "$sha" "$destination" | sha256sum -c -; then
                    warn "checksum failed: $destination"
                    rm -f "$destination"
                    return 1
                  fi
                }

                install_gh() {
                  if [ -x "$BIN/gh" ] && "$BIN/gh" --version 2>/dev/null | head -n1 | grep -q "gh version $GH_VERSION"; then
                    printf 'install-tools: gh %s already installed\n' "$GH_VERSION"
                    return 0
                  fi
                  archive="/tmp/gh_${GH_VERSION}_${ARCH}.tar.gz"
                  stage="/tmp/gh-${GH_VERSION}"
                  rm -rf "$stage" "$archive"
                  mkdir -p "$stage"
                  download_verified "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz" "$GH_SHA" "$archive" || return 1
                  tar -xzf "$archive" -C "$stage" || return 1
                  candidate="$stage/gh_${GH_VERSION}_linux_${ARCH}/bin/gh"
                  "$candidate" --version >/dev/null 2>&1 || return 1
                  install -m 0755 "$candidate" "$BIN/.gh.new" || return 1
                  mv -f "$BIN/.gh.new" "$BIN/gh" || return 1
                  chown 10000:10000 "$BIN/gh" || return 1
                  printf 'install-tools: installed gh %s\n' "$GH_VERSION"
                }

                install_go() {
                  if [ -x "$LOCAL/go/bin/go" ] && "$LOCAL/go/bin/go" version 2>/dev/null | grep -q "go${GO_VERSION}"; then
                    printf 'install-tools: go %s already installed\n' "$GO_VERSION"
                    return 0
                  fi
                  archive="/tmp/go${GO_VERSION}.${ARCH}.tar.gz"
                  stage="$LOCAL/.go.new"
                  previous="$LOCAL/.go.previous"
                  rm -rf "$stage" "$archive"
                  download_verified "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" "$GO_SHA" "$archive" || return 1
                  mkdir -p "$stage"
                  tar -xzf "$archive" -C "$stage" --strip-components=1 || { rm -rf "$stage"; return 1; }
                  "$stage/bin/go" version 2>/dev/null | grep -q "go${GO_VERSION}" || { rm -rf "$stage"; return 1; }
                  chown -R 10000:10000 "$stage" || { rm -rf "$stage"; return 1; }
                  rm -rf "$previous"
                  if [ -d "$LOCAL/go" ] && ! mv "$LOCAL/go" "$previous"; then
                    rm -rf "$stage"
                    return 1
                  fi
                  if mv "$stage" "$LOCAL/go"; then
                    rm -rf "$previous"
                    printf 'install-tools: installed go %s\n' "$GO_VERSION"
                    return 0
                  fi
                  [ ! -d "$previous" ] || mv "$previous" "$LOCAL/go"
                  return 1
                }

                install_brew() {
                  if [ -x "$LOCAL/homebrew/bin/brew" ] && [ "$(git -C "$LOCAL/homebrew" rev-parse HEAD 2>/dev/null || true)" = "$BREW_COMMIT" ]; then
                    printf 'install-tools: Homebrew %s already installed\n' "$BREW_VERSION"
                    return 0
                  fi
                  stage="$LOCAL/.homebrew.new"
                  previous="$LOCAL/.homebrew.previous"
                  rm -rf "$stage"
                  mkdir -p "$stage"
                  git -C "$stage" init -q || { rm -rf "$stage"; return 1; }
                  git -C "$stage" remote add origin https://github.com/Homebrew/brew.git || { rm -rf "$stage"; return 1; }
                  git -C "$stage" fetch -q --depth 1 origin "$BREW_COMMIT" || { rm -rf "$stage"; return 1; }
                  git -C "$stage" checkout -q --detach FETCH_HEAD || { rm -rf "$stage"; return 1; }
                  [ "$(git -C "$stage" rev-parse HEAD)" = "$BREW_COMMIT" ] || { rm -rf "$stage"; return 1; }
                  HOMEBREW_PREFIX="$stage" "$stage/bin/brew" --version 2>/dev/null | head -n1 | grep -q "Homebrew $BREW_VERSION" || { rm -rf "$stage"; return 1; }
                  chown -R 10000:10000 "$stage" || { rm -rf "$stage"; return 1; }
                  rm -rf "$previous"
                  if [ -d "$LOCAL/homebrew" ] && ! mv "$LOCAL/homebrew" "$previous"; then
                    rm -rf "$stage"
                    return 1
                  fi
                  if mv "$stage" "$LOCAL/homebrew"; then
                    rm -rf "$previous"
                    printf 'install-tools: installed Homebrew %s\n' "$BREW_VERSION"
                    return 0
                  fi
                  [ ! -d "$previous" ] || mv "$previous" "$LOCAL/homebrew"
                  return 1
                }

                install_gh || warn "gh reconciliation failed; preserving any existing installation"
                install_go || warn "Go reconciliation failed; preserving any existing installation"
                install_brew || warn "Homebrew reconciliation failed; preserving any existing installation"
                exit 0
```

The GitHub CLI checksums come from the official `gh_2.96.0_checksums.txt`; Go checksums come from `https://go.dev/dl/?mode=json`; Homebrew is pinned and verified by immutable Git commit `b48c7994b5f0eed7bef532efa63cb4e4f763887a` for release 6.0.12.

- [ ] **Step 3: Run source and shell checks**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
script = release["spec"]["values"]["controllers"]["hermes"]["initContainers"]["install-tools"]["command"][-1]
for expected in ("GH_VERSION=2.96.0", "GO_VERSION=1.26.5", "BREW_VERSION=6.0.12", "sha256sum -c", "x86_64)", "aarch64|arm64)"):
    assert expected in script
assert "/opt/data/.local/bin/hermes" not in script
assert "/opt/data/.local/bin/docker" not in script
open(".tmp/hermes-cleanup/install-tools.sh", "w", newline="\n", encoding="utf-8").write(script)
print("tool reconciler source checks passed")
PY
bash -n .tmp/hermes-cleanup/install-tools.sh
docker run --rm -i koalaman/shellcheck-alpine:v0.10.0 --shell=bash - \
  < .tmp/hermes-cleanup/install-tools.sh
```

Expected: source assertions and Bash syntax pass; ShellCheck reports no errors.

- [ ] **Step 4: Run first-install and idempotency tests on a disposable volume**

```bash
docker volume rm hermes-tools-test 2>/dev/null || true
docker volume create hermes-tools-test
docker run --rm --entrypoint /bin/bash \
  -v "$PWD/.tmp/hermes-cleanup/install-tools.sh:/test/install-tools.sh:ro" \
  -v hermes-tools-test:/opt/data \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  /test/install-tools.sh
docker run --rm --entrypoint /bin/bash \
  -v "$PWD/.tmp/hermes-cleanup/install-tools.sh:/test/install-tools.sh:ro" \
  -v hermes-tools-test:/opt/data \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  -c '/test/install-tools.sh | tee /tmp/second-run.log; grep -q "already installed" /tmp/second-run.log'
```

Expected: first run installs all three tools; second run reports each already installed and exits zero.

- [ ] **Step 5: Verify the installed amd64 versions without changing the disposable volume**

```bash
docker run --rm --entrypoint /bin/bash \
  -v hermes-tools-test:/opt/data \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  -c '/opt/data/.local/bin/gh --version | head -n1; /opt/data/.local/go/bin/go version; HOMEBREW_PREFIX=/opt/data/.local/homebrew /opt/data/.local/homebrew/bin/brew --version | head -n1'
```

Expected: `gh version 2.96.0`, `go1.26.5`, and `Homebrew 6.0.12`.

- [ ] **Step 6: Run the same installation under arm64 emulation**

```bash
docker volume rm hermes-tools-arm64-test 2>/dev/null || true
docker volume create hermes-tools-arm64-test
docker run --rm --platform linux/arm64 --entrypoint /bin/bash \
  -v "$PWD/.tmp/hermes-cleanup/install-tools.sh:/test/install-tools.sh:ro" \
  -v hermes-tools-arm64-test:/opt/data \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  /test/install-tools.sh
docker run --rm --platform linux/arm64 --entrypoint /bin/bash \
  -v hermes-tools-arm64-test:/opt/data \
  nousresearch/hermes-agent:v2026.7.20@sha256:f7b35053268f532f98955195c909f15a230470fbcbdacaa9fdecb95707dad04a \
  -c 'test "$(uname -m)" = aarch64; /opt/data/.local/bin/gh --version | grep -q "gh version 2.96.0"; /opt/data/.local/go/bin/go version | grep -q "go1.26.5"; HOMEBREW_PREFIX=/opt/data/.local/homebrew /opt/data/.local/homebrew/bin/brew --version | grep -q "Homebrew 6.0.12"'
```

Expected: both arm64 containers exit zero, proving the pinned image and all downloaded tools support arm64.

- [ ] **Step 7: Commit the tool reconciler**

```bash
git add kubernetes/ai/hermes/app/release.yaml
git commit -m "feat(hermes): verify multi-arch CLI tools"
docker volume rm hermes-tools-test hermes-tools-arm64-test
```

Expected: one local commit containing only the verified fail-soft tool initialization.

---

### Task 5: Consolidate gateway and dashboard under S6

**Files:**
- Modify: `kubernetes/ai/hermes/app/release.yaml`

**Interfaces:**
- Consumes: pinned image S6 services, migrated `/opt/data`, ExternalSecret `hermes`, API port 8642, dashboard port 9119.
- Produces: one regular container named `app`; two unchanged Services and the unchanged dashboard HTTPRoute; native durable lazy packages under `/opt/data/lazy-packages`; dual-listener startup/readiness probes.

- [ ] **Step 1: Run a failing final-runtime assertion**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
values = release["spec"]["values"]
controller = values["controllers"]["hermes"]
assert set(controller["containers"]) == {"app"}
assert set(controller["initContainers"]) == {"init-config", "install-tools"}
env = controller["containers"]["app"]["env"]
assert env["HERMES_DASHBOARD"] == "true"
assert env["PATH"].startswith("/opt/hermes/bin:")
for removed in ("PYTHONPATH", "PIP_BREAK_SYSTEM_PACKAGES", "HOME", "GATEWAY_HEALTH_URL"):
    assert removed not in env
assert "python-packages" not in values["persistence"]
PY
```

Expected: FAIL because the dashboard sidecar, Firecrawl init, old environment, and Python package volume remain.

- [ ] **Step 2: Remove obsolete runtime entries**

Delete these mappings completely:

```text
controllers.hermes.initContainers.install-firecrawl-python
controllers.hermes.containers.dashboard
persistence.python-packages
```

Remove dashboard and `install-firecrawl-python` entries from every `advancedMounts` mapping. Remove `PYTHONPATH`, `PIP_BREAK_SYSTEM_PACKAGES`, and explicit `HOME` from the app environment. Remove `GATEWAY_HEALTH_URL` with the dashboard sidecar.

- [ ] **Step 3: Replace `containers.app` with the complete consolidated container**

```yaml
          app:
            image:
              repository: nousresearch/hermes-agent
              tag: *hermesTag
            args: ["gateway", "run"]
            env:
              TZ: "${TZ}"
              HERMES_HOME: /opt/data
              GOPATH: /opt/data/go
              HOMEBREW_CELLAR: /opt/data/.local/homebrew/Cellar
              HOMEBREW_PREFIX: /opt/data/.local/homebrew
              HOMEBREW_REPOSITORY: /opt/data/.local/homebrew
              PATH: /opt/hermes/bin:/opt/hermes/.venv/bin:/opt/data/.local/bin:/opt/data/.local/go/bin:/opt/data/.local/homebrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
              TERM: xterm-256color
              API_SERVER_ENABLED: "true"
              API_SERVER_HOST: "0.0.0.0"
              API_SERVER_PORT: &apiPort 8642
              API_SERVER_CORS_ORIGINS: "https://hermes.${LOCAL_DOMAIN}"
              HERMES_DASHBOARD: "true"
              HERMES_DASHBOARD_HOST: "0.0.0.0"
              HERMES_DASHBOARD_PORT: &dashboardPort 9119
              HERMES_DASHBOARD_OIDC_ISSUER: https://sso.${REMOTE_DOMAIN}/application/o/hermes/
              HERMES_DASHBOARD_PUBLIC_URL: https://hermes.${LOCAL_DOMAIN}
              AGENT_BROWSER_ARGS: "--no-sandbox,--disable-dev-shm-usage"
              FIRECRAWL_API_URL: https://api.firecrawl.dev
              SEARXNG_URL: http://searxng.ai.svc.cluster.local:8080
            envFrom:
              - secretRef:
                  name: *app
            ports:
              - name: api
                containerPort: *apiPort
                protocol: TCP
              - name: dashboard
                containerPort: *dashboardPort
                protocol: TCP
            probes:
              liveness:
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /health
                    port: *apiPort
                  periodSeconds: 30
                  timeoutSeconds: 5
                  failureThreshold: 6
              readiness:
                enabled: true
                custom: true
                spec:
                  exec:
                    command:
                      - /bin/sh
                      - -c
                      - curl -fsS http://127.0.0.1:8642/health >/dev/null && curl -fsS -o /dev/null http://127.0.0.1:9119/
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 6
              startup:
                enabled: true
                custom: true
                spec:
                  exec:
                    command:
                      - /bin/sh
                      - -c
                      - curl -fsS http://127.0.0.1:8642/health >/dev/null && curl -fsS -o /dev/null http://127.0.0.1:9119/
                  periodSeconds: 5
                  timeoutSeconds: 5
                  failureThreshold: 60
            resources:
              requests:
                cpu: 250m
                memory: 1Gi
              limits:
                memory: 4Gi
```

The root dashboard request is expected to return a successful page or OIDC redirect; curl treats HTTP 3xx as successful without `--location`.

- [ ] **Step 4: Keep Services stable while using the consolidated pod**

Replace the Service port block with:

```yaml
    service:
      app:
        controller: *app
        ports:
          api:
            port: *apiPort
      dashboard:
        controller: *app
        ports:
          http:
            port: *dashboardPort
```

Do not add named `targetPort` values: app-template 5.0.1 documents that named target ports are unsupported, and numeric service ports render numeric target ports correctly. Leave the complete `route.app` mapping unchanged.

- [ ] **Step 5: Replace persistence with the final mount set**

```yaml
    persistence:
      config:
        existingClaim: *app
        advancedMounts:
          hermes:
            app:
              - path: /opt/data
            init-config:
              - path: /opt/data
            install-tools:
              - path: /opt/data

      config-file:
        type: configMap
        name: hermes-config
        advancedMounts:
          hermes:
            init-config:
              - path: /desired/config.yaml
                subPath: config.yaml
                readOnly: true
              - path: /desired/SOUL.md
                subPath: SOUL.md
                readOnly: true

      config-staging:
        type: emptyDir
        advancedMounts:
          hermes:
            init-config:
              - path: /staging

      shm:
        type: emptyDir
        medium: Memory
        sizeLimit: 1Gi
        advancedMounts:
          hermes:
            app:
              - path: /dev/shm

      tmpfs:
        type: emptyDir
        advancedMounts:
          hermes:
            app:
              - path: /tmp
            init-config:
              - path: /tmp
                subPath: init-config
            install-tools:
              - path: /tmp
                subPath: install-tools
```

Hermes's baked `HERMES_LAZY_INSTALL_TARGET=/opt/data/lazy-packages` remains available through the PVC; do not add `PYTHONPATH` or another package volume.

- [ ] **Step 6: Re-run source assertions and render final app-template output**

```bash
python - <<'PY'
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
values = release["spec"]["values"]
controller = values["controllers"]["hermes"]
assert set(controller["containers"]) == {"app"}
assert set(controller["initContainers"]) == {"init-config", "install-tools"}
env = controller["containers"]["app"]["env"]
assert env["HERMES_DASHBOARD"] == "true"
assert env["PATH"].startswith("/opt/hermes/bin:")
for removed in ("PYTHONPATH", "PIP_BREAK_SYSTEM_PACKAGES", "HOME", "GATEWAY_HEALTH_URL"):
    assert removed not in env
assert "python-packages" not in values["persistence"]
assert controller["containers"]["app"]["resources"] == {
    "requests": {"cpu": "250m", "memory": "1Gi"},
    "limits": {"memory": "4Gi"},
}
print("consolidated source values pass")
PY
python - <<'PY' | helm template hermes oci://ghcr.io/bjw-s-labs/helm/app-template \
  --version 5.0.1 --namespace ai -f - > .tmp/hermes-cleanup/final-render.yaml
import yaml
release = yaml.safe_load(open("kubernetes/ai/hermes/app/release.yaml", encoding="utf-8"))
print(yaml.safe_dump(release["spec"]["values"], sort_keys=False))
PY
python - <<'PY'
import yaml
docs = [d for d in yaml.safe_load_all(open(".tmp/hermes-cleanup/final-render.yaml", encoding="utf-8")) if isinstance(d, dict)]
deployment = next(d for d in docs if d.get("kind") == "Deployment")
spec = deployment["spec"]["template"]["spec"]
assert [c["name"] for c in spec["containers"]] == ["app"]
assert [c["name"] for c in spec["initContainers"]] == ["init-config", "install-tools"]
app = spec["containers"][0]
assert {(p["name"], p["containerPort"]) for p in app["ports"]} == {("api", 8642), ("dashboard", 9119)}
assert app["startupProbe"]["exec"] and app["readinessProbe"]["exec"]
assert app["livenessProbe"]["httpGet"]["path"] == "/health"
assert {v["name"] for v in spec["volumes"]} == {"config", "config-file", "config-staging", "shm", "tmpfs"}
services = {d["metadata"]["name"]: d for d in docs if d.get("kind") == "Service"}
assert services["hermes-app"]["spec"]["ports"][0]["targetPort"] == 8642
assert services["hermes-dashboard"]["spec"]["ports"][0]["targetPort"] == 9119
route = next(d for d in docs if d.get("kind") == "HTTPRoute")
assert route["metadata"]["name"] == "hermes"
print("final chart render passes")
PY
```

Expected: one app container, two ordered init containers, two ports, dual-listener startup/readiness, gateway liveness, stable Services, and the unchanged HTTPRoute.

- [ ] **Step 7: Schema-validate both source and chart output**

```bash
kustomize build kubernetes/ai/hermes/app | kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
kubeconform -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  .tmp/hermes-cleanup/final-render.yaml
```

Expected: zero invalid resources and zero errors in both runs. Investigate any skipped Hermes-related schema rather than ignoring it.

- [ ] **Step 8: Commit the S6 consolidation**

```bash
git add kubernetes/ai/hermes/app/release.yaml
git commit -m "refactor(hermes): supervise dashboard with gateway"
```

Expected: one local commit containing the one-container runtime, probes, resources, and final mounts.

---

### Task 6: Perform complete repository verification

**Files:**
- No planned file changes; fix only defects exposed by verification, then amend the owning commit.

**Interfaces:**
- Consumes: all prior local commits and Task 1 baselines.
- Produces: evidence that the final source renders, schemas pass, RBAC is permission-equivalent, no stale plumbing remains, and no deployment has occurred.

- [ ] **Step 1: Render the app and Flux-local configuration**

```bash
kustomize build kubernetes/ai/hermes/app > .tmp/hermes-cleanup/final-source.yaml
flux build kustomization hermes --path kubernetes/ai/hermes/app \
  > .tmp/hermes-cleanup/final-flux.yaml
kustomize build kubernetes/ai > .tmp/hermes-cleanup/final-ai.yaml
```

Expected: all three commands exit zero. `flux build` only reads the in-cluster Kustomization and renders local files; it does not reconcile.

- [ ] **Step 2: Re-run schema validation**

```bash
for file in .tmp/hermes-cleanup/final-source.yaml .tmp/hermes-cleanup/final-flux.yaml .tmp/hermes-cleanup/final-ai.yaml .tmp/hermes-cleanup/final-render.yaml; do
  echo "Validating $file"
  kubeconform -strict -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    "$file"
done
```

Expected: every file reports zero invalid resources and zero errors.

- [ ] **Step 3: Verify no stale source or rendered runtime remains**

```bash
python - <<'PY'
from pathlib import Path
import yaml
source = Path("kubernetes/ai/hermes/app/release.yaml").read_text(encoding="utf-8")
for forbidden in (
    "install-firecrawl-python",
    "python-packages",
    "PYTHONPATH",
    "PIP_BREAK_SYSTEM_PACKAGES",
    "GATEWAY_HEALTH_URL",
    "AGENTMEMORY_SECRET",
    "plugins/agentmemory",
):
    assert forbidden not in source, forbidden
cfg = yaml.safe_load(open("kubernetes/ai/hermes/app/resources/config.yaml", encoding="utf-8"))
assert "toolsets" not in cfg
assert cfg["platform_toolsets"] == {"cli": ["hermes-cli"]}
install = yaml.safe_load(open("kubernetes/ai/hermes/install.yaml", encoding="utf-8"))
assert {d["name"] for d in install["spec"]["dependsOn"]} == {"grafana-mcp", "volsync"}
print("stale source checks passed")
PY
```

Expected: `stale source checks passed`.

- [ ] **Step 4: Re-run canonical RBAC equivalence**

```bash
python - <<'PY'
import json, yaml

def canonical(rules):
    keys = ("apiGroups", "resources", "resourceNames", "nonResourceURLs", "verbs")
    return sorted(tuple(tuple(sorted(rule.get(key, []))) for key in keys) for rule in rules)

baseline = json.load(open(".tmp/hermes-cleanup/baseline-rbac.json", encoding="utf-8"))
role = next(d for d in yaml.safe_load_all(open("kubernetes/ai/hermes/app/rbac.yaml", encoding="utf-8")) if d["kind"] == "ClusterRole")
assert canonical(role["rules"]) == [tuple(tuple(x) for x in rule) for rule in baseline]
print("RBAC permission set unchanged")
PY
```

Expected: `RBAC permission set unchanged`.

- [ ] **Step 5: Review the complete local change set**

```bash
git status --short
git log --oneline --decorate -8
git diff 674e2957..HEAD -- kubernetes/ai/hermes
git diff --check 674e2957..HEAD
```

Expected: only the approved Hermes files changed after design commit `674e2957`; no whitespace errors; `.tmp/hermes-cleanup` is untracked/ignored and never staged.

- [ ] **Step 6: Confirm the live cluster was not changed**

```bash
kubectl -n flux-system get kustomization hermes -o jsonpath='{.status.lastAppliedRevision}{"\n"}'
kubectl -n ai get helmrelease hermes -o jsonpath='{.status.history[0].chartVersion}{" "}{.status.history[0].status}{"\n"}'
git status --short
```

Expected: Flux still reports the previously applied remote revision; the live HelmRelease remains healthy; all implementation commits are local and unpushed.

---

### Task 7: Validate an authorized Flux rollout

**Files:**
- No source changes unless rollout evidence exposes a defect; fixes follow the same local validation cycle and require renewed push permission.

**Interfaces:**
- Consumes: explicit user permission to push and the verified local commit series.
- Produces: Flux/Helm readiness, one `1/1` pod, working API/dashboard endpoints, retained tools, clean logs, unchanged effective RBAC, and usage evidence.

- [ ] **Step 1: Obtain explicit push permission**

Do not run any command in this task until the user explicitly authorizes pushing the local commits. Permission to implement or commit locally is not permission to deploy.

- [ ] **Step 2: Push the already reviewed branch**

```bash
git push origin HEAD
```

Expected: push succeeds. Do not manually invoke Flux reconciliation; allow the configured Git source interval/receiver to reconcile.

- [ ] **Step 3: Wait for Flux and Helm readiness**

```bash
kubectl -n flux-system wait kustomization/hermes --for=condition=ready --timeout=15m
kubectl -n ai wait helmrelease/hermes --for=condition=ready --timeout=15m
kubectl -n flux-system get kustomization hermes -o wide
kubectl -n ai get helmrelease hermes -o wide
```

Expected: both waits succeed and status references the pushed revision.

- [ ] **Step 4: Verify pod topology, init completion, Services, and route**

```bash
pod=$(kubectl -n ai get pod -l app.kubernetes.io/name=hermes -o jsonpath='{.items[0].metadata.name}')
kubectl -n ai wait "pod/$pod" --for=condition=ready --timeout=10m
kubectl -n ai get "pod/$pod" -o jsonpath='{range .status.initContainerStatuses[*]}init/{.name}: ready={.ready} restarts={.restartCount} reason={.state.terminated.reason}{"\n"}{end}{range .status.containerStatuses[*]}container/{.name}: ready={.ready} restarts={.restartCount}{"\n"}{end}'
kubectl -n ai get service hermes-app hermes-dashboard
kubectl -n ai get endpointslice -l app.kubernetes.io/name=hermes
kubectl -n ai get httproute hermes -o jsonpath='{range .status.parents[*].conditions[*]}{.type}={.status} reason={.reason}{"\n"}{end}'
```

Expected: exactly two successful init statuses, one ready app container with zero restarts, both Services have EndpointSlices, and the route is Accepted.

- [ ] **Step 5: Verify listeners and OIDC without exposing secrets**

```bash
kubectl -n ai exec "$pod" -c app -- /bin/sh -c 'curl -fsS http://127.0.0.1:8642/health && printf "\n"; curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9119/'
```

Expected: gateway health succeeds; dashboard returns HTTP 200 or an OIDC redirect in the 300 range.

- [ ] **Step 6: Verify retained tools with non-mutating version commands**

```bash
kubectl -n ai exec "$pod" -c app -- /bin/sh -c '
  command -v hermes
  hermes --version
  gh --version | head -n1
  go version
  brew --version | head -n1
  docker --version
'
```

Expected: `hermes` resolves through `/opt/hermes/bin`; versions are Hermes v2026.7.20, gh 2.96.0, Go 1.26.5, Homebrew 6.0.12, and the image-provided Docker CLI.

- [ ] **Step 7: Review startup logs for removed failure modes**

```bash
kubectl -n ai logs "$pod" -c app --since=20m > .tmp/hermes-cleanup/post-rollout.log
python - <<'PY'
from pathlib import Path
log = Path(".tmp/hermes-cleanup/post-rollout.log").read_text(encoding="utf-8", errors="replace")
for forbidden in (
    "API server rejected invalid API key: remote='127.0.0.1'",
    "platform 'cli' references unknown toolset 'mcp-grafana'",
    "hermes: command not found",
):
    assert forbidden not in log, forbidden
print("removed startup warnings are absent")
PY
kubectl -n ai get "$pod" -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
```

Expected: removed warning patterns are absent and restart count is zero. Also inspect the startup section and confirm Hermes reports the configured Discord platform without authentication or connection errors; do not print the bot token or Secret.

- [ ] **Step 8: Verify effective RBAC and resource usage**

```bash
kubectl auth can-i --as=system:serviceaccount:ai:hermes --list > .tmp/hermes-cleanup/final-can-i.txt
python - <<'PY'
from pathlib import Path
before = sorted(line.rstrip() for line in Path(".tmp/hermes-cleanup/baseline-can-i.txt").read_text(encoding="utf-8").splitlines() if line.strip())
after = sorted(line.rstrip() for line in Path(".tmp/hermes-cleanup/final-can-i.txt").read_text(encoding="utf-8").splitlines() if line.strip())
assert before == after
print("live effective RBAC unchanged")
PY
kubectl -n ai top pod "$pod" --containers
```

Expected: permission listings match exactly; resource usage is recorded and remains below the configured memory request/limit under idle conditions.

- [ ] **Step 9: Roll back only if acceptance fails**

If a blocking regression is confirmed, create and push a normal revert after explicit permission:

```bash
git revert --no-edit 674e2957..HEAD
git push origin HEAD
```

Expected: Git records revert commits and Flux returns to the prior deployment. Do not patch the live Deployment, HelmRelease, Services, RBAC, or Flux Kustomization.
