# Hermes Ornith Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch Hermes to use the in-cluster Ornith llama.cpp endpoint as its default model.

**Architecture:** Hermes reads its model configuration from `kubernetes/ai/hermes/app/resources/config.yaml`, which is packaged into the `hermes-config` ConfigMap. Ornith already runs as an OpenAI-compatible llama.cpp service in the `ai` namespace, so Hermes only needs the custom provider endpoint and model metadata.

**Tech Stack:** Flux Kustomization, bjw-s app-template HelmRelease, Kustomize, Hermes Agent config YAML, llama.cpp OpenAI-compatible API.

## Global Constraints

- YAML uses two-space indentation.
- Do not commit decrypted secrets or local logs.
- Validate rendered manifests with `kubectl kustomize` or `kustomize build`.
- Avoid cluster-mutating commands.

---

### Task 1: Switch Hermes Model Config To Ornith

**Files:**
- Modify: `kubernetes/ai/hermes/app/resources/config.yaml:2-6`
- Modify: `kubernetes/ai/hermes/install.yaml:11-15`

**Interfaces:**
- Consumes: Ornith service URL `http://ornith.ai.svc.cluster.local:8080/v1` and model alias `Ornith-1.0-9B` from `kubernetes/ai/llama-embed/app/ornith/release.yaml`.
- Produces: Hermes `model` config with `provider: custom`, `default: Ornith-1.0-9B`, `base_url: http://ornith.ai.svc.cluster.local:8080/v1`, and `context_length: 131072`.

- [x] **Step 1: Write the failing manifest assertion**

Run:

```powershell
rg -q "provider: custom" "kubernetes/ai/hermes/app/resources/config.yaml"; if ($LASTEXITCODE -ne 0) { "FAIL expected model.provider to be custom for Ornith"; exit 1 }; rg -q "default: Ornith-1.0-9B" "kubernetes/ai/hermes/app/resources/config.yaml"; if ($LASTEXITCODE -ne 0) { "FAIL expected model.default to be Ornith-1.0-9B"; exit 1 }; rg -q "base_url: http://ornith.ai.svc.cluster.local:8080/v1" "kubernetes/ai/hermes/app/resources/config.yaml"; if ($LASTEXITCODE -ne 0) { "FAIL expected model.base_url to point at Ornith service"; exit 1 }; rg -q "context_length: 131072" "kubernetes/ai/hermes/app/resources/config.yaml"; if ($LASTEXITCODE -ne 0) { "FAIL expected model.context_length to match Ornith context"; exit 1 }; "PASS Hermes uses Ornith"
```

Expected: fails with `FAIL expected model.provider to be custom for Ornith` before the edit.

- [x] **Step 2: Update Hermes model config**

Set the top-level `model` block in `kubernetes/ai/hermes/app/resources/config.yaml` to:

```yaml
model:
  provider: custom
  default: Ornith-1.0-9B
  base_url: http://ornith.ai.svc.cluster.local:8080/v1
  api_key: ""
  context_length: 131072
  api_mode: chat_completions
```

- [x] **Step 3: Add Flux dependency**

Add `llama-embed` to `spec.dependsOn` in `kubernetes/ai/hermes/install.yaml`:

```yaml
  dependsOn:
    - name: agentmemory
    - name: grafana-mcp
    - name: llama-embed
    - name: toolhive-config
    - name: volsync
      namespace: flux-system
```

- [x] **Step 4: Verify the assertion passes**

Run the same command from Step 1.

Expected: `PASS Hermes uses Ornith`.

- [x] **Step 5: Render affected manifests**

Run:

```powershell
kubectl kustomize kubernetes/ai/hermes/app
kubectl kustomize kubernetes/ai
```

Expected: both commands exit 0 and render YAML.

## Self-Review

- Spec coverage: the plan switches Hermes to the in-cluster Ornith endpoint and validates Kustomize output.
- Placeholder scan: no placeholders remain.
- Type consistency: all YAML keys match Hermes docs and the existing repository structure.
