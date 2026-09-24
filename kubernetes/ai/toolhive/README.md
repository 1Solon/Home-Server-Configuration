# ToolHive MCP Gateway

MCP (Model Context Protocol) gateway for the cluster, modeled on
[Jory's toolhive setup](https://github.com/joryirving/home-ops/tree/main/kubernetes/apps/base/llm/toolhive),
minus the parts this cluster does not need.

- [Virtual MCPServer](https://docs.stacklok.com/toolhive/guides-vmcp/) aggregates all
  registered MCP servers behind one internal endpoint: `https://mcp.${LOCAL_DOMAIN}/mcp`.
- Tool names are prefixed with their owning server (`flux_`, `kubectl_`, ...) to avoid
  collisions.
- Embedded **tool search** (optimizer) serves only mode-relevant tools to the client;
  embeddings are computed by a CPU-only LLMKube service running
  [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF)
  (`kubernetes/ai/llmkube/models/embed.yaml`). No LiteLLM: a single client does not need
  the proxy, database or SSO that Jory's shared inference platform carries.
- MCP session state is stored in the shared Dragonfly, db 1.
- The endpoint is internal-only (envoy-internal gateway, no external route, no key auth).

## Deployment order (Flux Kustomizations, `install.yaml`)

1. `toolhive-crds` - CRDs chart from `oci://ghcr.io/stacklok/toolhive/toolhive-operator-crds`
2. `toolhive` - operator chart from `oci://ghcr.io/stacklok/toolhive/toolhive-operator`
3. `toolhive-config` - MCPGroup, VirtualMCPServer, HTTPRoute, PodMonitor
4. `toolhive-servers` - the MCPServer/MCPServerEntry workload definitions

## Registered MCP servers

| Server | Type | Backend |
|---|---|---|
| flux | MCPServer | `flux-operator-mcp`, read-only RBAC + Flux-crud write role |
| kubectl | MCPServer | `kubectl-mcp-server`, read-only, secrets excluded |
| github | MCPServer | `github-mcp-server`, PAT from 1Password |
| grafana | MCPServerEntry | existing `mcp-grafana` deployment in `observability` |
| kubesearch | MCPServer | `perfectra1n/kubesearch-mcp` |
| arr | MCPServer | `mcp-arr-server` npx against Sonarr/Radarr/Prowlarr (`home-media`) |
| seerr | MCPServer | `overseerr-mcp` npx against Jellyseerr (`home-media`) |
| unifi | MCPServer | `sirkirby/unifi-network-mcp` against `https://unifi.${LOCAL_DOMAIN}` |

Deferred (not present in this cluster yet): `ha-mcp` (no Home Assistant instance,
by request), `talos-mcp` (needs Talos `ServiceAccount` API-server support /
`talos.dev` credentials, which the cluster does not provide), `dispatch-mcp`,
`plan-shop-eat-mcp`.

## Required 1Password items

- `toolhive` (vault `Homelab`, created by the implementation agent) with:
  - `GITHUB_PERSONAL_ACCESS_TOKEN` - **populated** with the gh CLI token
    (`gho_`, scopes `repo`, `workflow`, `read:org`, `gist`, `write:packages`). Rotate
    to a fine-grained PAT if you want narrower scopes for the MCP server.
  - `UNIFI_NETWORK_USERNAME` / `UNIFI_NETWORK_PASSWORD` - **empty, fill these in** so
    unifi-network-mcp can talk to the controller.
- Existing items already referenced by other apps are reused verbatim: `sonarr`
  (`SONARR__API_KEY`), `radarr` (`RADARR__API_KEY`), `prowlarr` (`PROWLARR__API_KEY`),
  `seerr` (`SEERR_API_KEY`).

## Client endpoint

Point any MCP client at `https://mcp.local.solonsstuff.com/mcp`
(streamable-http, no authentication: the route is internal-only). Tools appear
prefixed, e.g. `flux_list_reconciliations`, `grafana_search_dashboards`.
