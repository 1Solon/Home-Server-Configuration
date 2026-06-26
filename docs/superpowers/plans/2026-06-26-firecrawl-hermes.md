# Firecrawl for Hermes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy self-hosted Firecrawl in the cluster with shared Dragonfly and CloudNativePG, then point Hermes at the internal Firecrawl API.

**Architecture:** Add a new Flux-managed `kubernetes/ai/firecrawl` app using bjw-s `app-template`. Firecrawl components run as separate controllers and consume shared Dragonfly plus a dedicated `firecrawl` database in the existing `postgres17` CloudNativePG cluster.

**Tech Stack:** Flux Kustomizations, Kustomize, bjw-s app-template Helm chart, External Secrets, Dragonfly, CloudNativePG, Firecrawl containers.

---

### Task 1: Add Firecrawl App Skeleton

**Files:**
- Create: `kubernetes/ai/firecrawl/install.yaml`
- Create: `kubernetes/ai/firecrawl/app/kustomization.yaml`
- Modify: `kubernetes/ai/kustomization.yaml`

- [ ] **Step 1: Add the Flux Kustomization**

Create `kubernetes/ai/firecrawl/install.yaml` with a Flux `Kustomization` named `firecrawl`, targeting namespace `ai`, depending on `cloudnative-postgres`, `dragonfly`, and `searxng`, and pointing at `./kubernetes/ai/firecrawl/app`.

- [ ] **Step 2: Add the app Kustomization**

Create `kubernetes/ai/firecrawl/app/kustomization.yaml` with `externalsecret.yaml` and `release.yaml` resources.

- [ ] **Step 3: Register Firecrawl in AI stack**

Add `./firecrawl/install.yaml` to `kubernetes/ai/kustomization.yaml` before `./hermes/install.yaml`, so Firecrawl reconciles before Hermes.

### Task 2: Add Firecrawl Secrets

**Files:**
- Create: `kubernetes/ai/firecrawl/app/externalsecret.yaml`

- [ ] **Step 1: Template runtime and database secrets**

Create an `ExternalSecret` named `firecrawl` that reads from OnePassword items `firecrawl`, `cloudnative-pg`, and `ai-api-keys`. It should generate `firecrawl-secret` with `BULL_AUTH_KEY`, `NUQ_DATABASE_URL`, `NUQ_DATABASE_URL_LISTEN`, `NUQ_RABBITMQ_URL`, OpenAI-compatible API values, and `INIT_POSTGRES_*` values for database creation.

### Task 3: Add Firecrawl HelmRelease

**Files:**
- Create: `kubernetes/ai/firecrawl/app/release.yaml`

- [ ] **Step 1: Define controllers**

Create an app-template `HelmRelease` with controllers for `api`, `worker`, `extract-worker`, `nuq-worker`, `nuq-prefetch-worker`, `playwright-service`, and `rabbitmq`. Use Firecrawl's documented Node entrypoints:

- API: `dist/src/index.js`
- worker: `dist/src/services/queue-worker.js`
- extract worker: `dist/src/services/extract-worker.js`
- NUQ worker: `dist/src/services/worker/nuq-worker.js`
- NUQ prefetch worker: `dist/src/services/worker/nuq-prefetch-worker.js`

- [ ] **Step 2: Define shared config**

Configure `REDIS_URL`, `REDIS_RATE_LIMIT_URL`, `PLAYWRIGHT_MICROSERVICE_URL`, `USE_DB_AUTHENTICATION=false`, `IS_KUBERNETES=true`, `ENV=production`, `SEARXNG_ENDPOINT=http://searxng.ai.svc.cluster.local:8080`, `NUQ_RABBITMQ_URL`, and internal Firecrawl host/port values.

- [ ] **Step 3: Define services**

Expose `firecrawl` API service port `3002`, `firecrawl-playwright` service port `3000`, and `firecrawl-rabbitmq` service port `5672`. Do not create an HTTPRoute.

### Task 4: Point Hermes at Firecrawl

**Files:**
- Modify: `kubernetes/ai/hermes/app/release.yaml`
- Modify: `kubernetes/ai/hermes/app/resources/config.yaml`
- Modify: `kubernetes/ai/hermes/install.yaml`

- [ ] **Step 1: Add dependency**

Add `firecrawl` to Hermes' Flux `dependsOn` list.

- [ ] **Step 2: Configure Hermes environment**

Add `FIRECRAWL_API_URL=http://firecrawl.ai.svc.cluster.local:3002` to the Hermes app container environment.

- [ ] **Step 3: Configure Hermes web backend**

Change Hermes `web.backend` from `searxng` to `firecrawl`.

### Task 5: Verify Rendered Manifests

**Files:**
- No code files.

- [ ] **Step 1: Run Kustomize render checks**

Run `kubectl kustomize kubernetes/ai/firecrawl/app` and `kubectl kustomize kubernetes/ai/hermes/app`. Expected result: both commands render YAML without errors.

- [ ] **Step 2: Review working tree**

Run `git diff --check` and `git status --short`. Expected result: no whitespace errors and only intended files changed.
