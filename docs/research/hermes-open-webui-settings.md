# Research: Hermes settings for Open WebUI

**Date:** 2026-08-24  
**Scope:** Hermes Agent `v2026.8.19`, Open WebUI `v0.11.0`, their repository manifests, and first-party integration documentation/source. No application configuration or cluster resources were changed.

## Verdict

No additional Hermes display setting is required to improve the Open WebUI integration. The deployed baseline already has the Hermes settings needed for a cross-pod connection: the API server is enabled, it binds beyond loopback, it listens on the port exposed by the Service, and it uses the same bearer secret supplied to Open WebUI.

The useful distinction is:

- **Required Hermes plumbing:** `API_SERVER_ENABLED`, `API_SERVER_KEY`, and, because Open WebUI is in another pod, a network-reachable `API_SERVER_HOST`. `API_SERVER_PORT` only needs an explicit value when using a non-default port or wiring a Service to it.
- **Optional Hermes UX/capability controls:** `API_SERVER_MODEL_NAME`, `platform_toolsets.api_server`, per-user profiles, and `gateway.api_server.max_concurrent_runs` under load.
- **Not Open WebUI controls:** Hermes `display.streaming`, `display.tool_progress`, `display.show_reasoning`, and `streaming.enabled`. The API adapter follows the client's `stream` request and emits API-specific stream events itself.
- **Open WebUI controls:** Hermes base URL and key, whether Ollama is shown, and Chat Completions versus Responses API mode. These are not Hermes settings.

Chat Completions remains the official recommended default. Responses mode is an optional Open WebUI-side experiment for richer structured tool-call events; Open WebUI does not currently gain Hermes server-side conversation chaining from it because it still sends full history instead of `previous_response_id`.

## Hermes-side settings

| Setting | Status for Open WebUI | Finding |
|---|---|---|
| `API_SERVER_ENABLED=true` | **Required** | Starts the OpenAI-compatible API server. It defaults to off. |
| `API_SERVER_KEY` | **Required** | Hermes requires bearer authentication even on loopback. Open WebUI must send the identical value. Use a strong secret. |
| `API_SERVER_HOST` | **Conditionally required** | Defaults to `127.0.0.1`. A separate Open WebUI pod cannot reach that bind, so this deployment needs its current network-reachable bind (`0.0.0.0`). It is not required when client and server genuinely share loopback. |
| `API_SERVER_PORT` | Optional/defaultable | Defaults to `8642`. Its value only has to agree with the URL and Kubernetes Service. The current explicit `8642` is correct but is not a UX enhancement. |
| Configured model/provider and usable tool backends | **Required for a useful agent**, not for protocol connectivity | Hermes creates a real server-side `AIAgent`; it is not an LLM proxy. Tool execution occurs in the Hermes pod/host. |
| `API_SERVER_CORS_ORIGINS` | **Not required for Open WebUI** | Open WebUI calls Hermes server-to-server. The official guide explicitly says CORS is unnecessary for this integration. The repository's current CORS value may serve a direct-browser Hermes surface, but it does not improve Open WebUI and should not be broadened for it. |
| `API_SERVER_MODEL_NAME` | Optional UX improvement | Changes the friendly model name advertised by `/v1/models`; default is the profile name or `hermes-agent`. Useful when several backends or profiles would otherwise be ambiguous. |
| `platform_toolsets.api_server` | Optional capability/UX control | Without an override Hermes uses `hermes-api-server`, a broad programmatic toolset that excludes interactive-only tools such as `clarify`, TTS, computer use, and kanban. An explicit list is only needed to narrow or deliberately alter those capabilities. |
| `gateway.api_server.max_concurrent_runs` | Optional operational tuning | Defaults to 10. It can protect a multi-user deployment from resource exhaustion, but reaching the cap returns HTTP 429, so it should be capacity-tuned rather than enabled as a generic UI improvement. |
| Separate Hermes profiles/API servers | Optional; recommended only for user isolation | Each profile gets separate config, memory, sessions, skills, key, port, and advertised model. Open WebUI can expose each as a separate connection/model and assign it to users. A single shared Hermes profile does not provide that isolation. |

### Current toolset nuance

The repository explicitly configures `platform_toolsets.api_server` with `clarify`, delegation, file, memory, skills, terminal, todo, and web. That setting is **not required** for Open WebUI connectivity. It also differs from Hermes' default API-server toolset: it narrows the available categories while adding `clarify`, which the programmatic default intentionally omits because the API call cannot pause for interactive clarification.

This may be an intentional least-capability policy. If the goal is a richer Open WebUI agent, the relevant Hermes-side review is whether this explicit list contains the desired capabilities, not whether more display flags should be enabled.

### Streaming and tool progress

Hermes' API adapter reads `stream` from the Chat Completions or Responses request. For streaming Chat Completions it wires token and tool callbacks directly, emitting `hermes.tool.progress` lifecycle SSE events; Responses mode emits standard `function_call` and `function_call_output` items. The adapter constructs its agent with `quiet_mode=True` and does not consult the native display settings for this path.

Therefore the current settings below may be useful to Hermes' CLI/dashboard/messaging presentation, but they are neither required nor additive for Open WebUI:

- `display.streaming: true`
- `streaming.enabled: true`
- `display.tool_progress: true`
- `display.show_reasoning: true`

The Open WebUI request and selected API mode control what its UI receives. Model/provider support still determines whether meaningful token or reasoning deltas exist.

## Open WebUI-side settings

| Setting | Status | Finding |
|---|---|---|
| OpenAI API enabled | **Required** | `ENABLE_OPENAI_API` defaults to true and is explicitly true here. |
| Hermes URL ending in `/v1` | **Required** | The current in-cluster URL `http://hermes-app.ai.svc.cluster.local:8642/v1` has the required suffix. A basic connection test can pass without this suffix while model discovery still fails. |
| Matching OpenAI API key | **Required** | The key at the Hermes URL's index must exactly match `API_SERVER_KEY`. The repository supplies corresponding semicolon-delimited URL/key lists. |
| `ENABLE_OLLAMA_API=false` | Optional cleanup | Hides the unused/default Ollama backend and avoids an empty model-picker section. It is already false here. Omit/enable it only when Ollama is actually wanted. |
| Chat Completions API type | **Recommended default** | Works without extra configuration and sends full conversation history. This is the official Hermes recommendation. |
| Responses API type | Optional, experimental UX trial | Selected in Open WebUI's connection editor, not Hermes. Hermes supplies structured tool events, and Open WebUI `v0.11.0` contains Responses-event handling. However, Open WebUI still sends full history instead of using `previous_response_id`, so the current practical gain is structured streaming rather than server-side state. |
| Streaming response enabled | Recommended/default client behavior | Needed to see incremental text and tool progress, but it is an Open WebUI request behavior, not a Hermes display setting. |

Open WebUI persists connection configuration in its database. The official Hermes guide warns that connection environment variables seed only the first launch; later changes must be made through Admin Settings or by deliberately resetting the data store. Open WebUI `v0.11.0` source likewise defines per-key database-backed configuration, including `api_type`. Consequently, manifests establish the initial/default Hermes connection but do not prove the currently stored API type or connection values.

## Practical conclusion for this repository

1. **Hermes-required state is already declaratively present:** enabled server, shared key, reachable bind, matching port, configured model/provider, and selected API-server tools.
2. **No Hermes display flag needs to be added for Open WebUI streaming, tool progress, or reasoning.** Existing display flags are for Hermes-owned surfaces.
3. **The lowest-risk optional UX improvement is only a friendly `API_SERVER_MODEL_NAME`** if `hermes-agent` is ambiguous in the model picker.
4. **The highest-impact capability decision is the existing explicit API-server toolset.** Review it only against intended agent powers and security boundaries.
5. **Any trial of structured tool rendering belongs in Open WebUI:** switch only the Hermes connection to Responses mode and compare it with the recommended Chat Completions default.
6. **For multiple untrusted or independent users, use separate Hermes profiles.** A display or model-name setting is not a substitute for separate memory/session/config state.

## Primary sources

- Hermes Agent Open WebUI integration guide: [live documentation](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/open-webui) and [source at the deployed Hermes revision](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/website/docs/user-guide/messaging/open-webui.md).
- Hermes API server reference: [stream formats and tool progress](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/website/docs/user-guide/features/api-server.md#post-v1chatcompletions), [configuration and concurrency](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/website/docs/user-guide/features/api-server.md#configuration), and [CORS](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/website/docs/user-guide/features/api-server.md#cors).
- Hermes `v2026.8.19` API implementation: [request-controlled Chat Completions streaming](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/gateway/platforms/api_server.py#L4173-L4194), [direct SSE tool lifecycle callbacks](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/gateway/platforms/api_server.py#L4321-L4405), and [API-server toolset resolution](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/gateway/platforms/api_server.py#L2928-L2967).
- Hermes toolset reference and source: [`hermes-api-server` behavior](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/website/docs/reference/toolsets-reference.md#platform-toolsets) and [default fallback when no platform override exists](https://github.com/NousResearch/hermes-agent/blob/fcbd1076a93841fa88855acce810e342a5b78101/hermes_cli/tools_config.py#L2403-L2427).
- Hermes profiles documentation: [profile isolation](https://hermes-agent.nousresearch.com/docs/user-guide/profiles#what-are-profiles) and [profile-specific configuration](https://hermes-agent.nousresearch.com/docs/user-guide/profiles#configuring-profiles).
- Open WebUI `v0.11.0` source: [OpenAI/Ollama environment defaults and URL/key lists](https://github.com/open-webui/open-webui/blob/f9590b8017199e56d5e953657e6498e3cef1d246/backend/open_webui/config.py#L217-L357), [connection API-type selector](https://github.com/open-webui/open-webui/blob/f9590b8017199e56d5e953657e6498e3cef1d246/src/lib/components/AddConnectionModal.svelte#L449-L474), [Responses routing](https://github.com/open-webui/open-webui/blob/f9590b8017199e56d5e953657e6498e3cef1d246/backend/open_webui/routers/openai.py#L1282-L1317), [Responses stream event handling](https://github.com/open-webui/open-webui/blob/f9590b8017199e56d5e953657e6498e3cef1d246/backend/open_webui/utils/middleware.py#L480-L529), and [database-backed connection configuration](https://github.com/open-webui/open-webui/blob/f9590b8017199e56d5e953657e6498e3cef1d246/backend/open_webui/models/config.py#L1-L53).
