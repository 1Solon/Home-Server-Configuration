# Firecrawl for Hermes Web Extract Design

## Goal

Self-host Firecrawl in the Kubernetes cluster and point Hermes at it for web extraction.

## Architecture

Firecrawl will run as an internal-only application in the `ai` namespace using the repository's existing Flux `Kustomization` plus bjw-s `app-template` pattern. It will expose an internal Kubernetes service at `http://firecrawl.ai.svc.cluster.local:3002` and will not publish an HTTPRoute.

Firecrawl will reuse shared cluster services instead of bundled dependencies. Redis-compatible queue and rate-limit traffic will use Dragonfly at `dragonfly.databases.svc.cluster.local:6379`. Firecrawl's NUQ database will use the shared CloudNativePG `postgres17` cluster through a dedicated `firecrawl` database and user created by the existing `ghcr.io/home-operations/postgres-init:18` init-container pattern.

## Components

- `api`: Firecrawl API server on port `3002`.
- `worker`: queue worker on port `3005`.
- `extract-worker`: extraction worker on port `3004`.
- `nuq-worker`: NUQ worker on port `3006`.
- `nuq-prefetch-worker`: NUQ prefetch worker on port `3011`.
- `playwright-service`: browser rendering helper on port `3000`.
- `rabbitmq`: private Firecrawl message broker on port `5672`.

The first deployment will omit bundled Redis, bundled Postgres, and public ingress. Firecrawl's current Helm example includes RabbitMQ, and this cluster does not have a shared RabbitMQ service, so Firecrawl will run a private internal RabbitMQ instance.

## Data Flow

Hermes sends extraction requests to the Firecrawl API service. Firecrawl uses Dragonfly for Redis-compatible queue/rate-limit state, RabbitMQ for Firecrawl's NUQ messaging path, Playwright for rendered page scraping, and CloudNativePG for NUQ persistence. Firecrawl can continue to use SearXNG for search via `SEARXNG_ENDPOINT`, while Hermes can stop depending directly on SearXNG for web extraction.

## Secrets

Firecrawl will get a generated Kubernetes Secret from External Secrets. The secret will template:

- `NUQ_DATABASE_URL`
- `NUQ_DATABASE_URL_LISTEN`
- `INIT_POSTGRES_*` values for the database init container
- `NUQ_RABBITMQ_URL`
- optional Firecrawl secret keys such as `BULL_AUTH_KEY`

The source OnePassword item is expected to expose a Firecrawl Postgres password, RabbitMQ password, and Bull admin key.

## Hermes Integration

Hermes will be configured to use the Firecrawl backend and internal Firecrawl URL. The existing SearXNG deployment remains because Firecrawl can use it for search and Open WebUI already depends on it.

## Verification

Static verification will render the affected Kustomize trees. Runtime verification after Flux applies the manifests should check Firecrawl API health and a simple scrape request from inside the cluster.
