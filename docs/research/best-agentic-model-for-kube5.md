# Research: Best Agentic LLM + GGUF Quant for kube5 (RTX 4060 Ti 16 GiB)

**Date:** 2026 (research run against current sources)
**Scope:** llama.cpp `server-cuda` on Kubernetes via llmkube `Model` CRD; goal is maximum agentic/tool-use quality within the hardware budget.

## Verified host constraints

- **GPU:** NVIDIA GeForce RTX 4060 Ti, 16,380 MiB VRAM, driver 595.91.07
- **CPU/RAM:** 8 vCPU, ~46 GB RAM (Talos Linux VM, node `kube5`)
- **Runtime:** llama.cpp server (`ghcr.io/ggml-org/llama.cpp:server-cuda`), deployed via the llmkube operator using a `Model` CRD whose `source` points at a GGUF file on a PVC
- **Currently served:** `unsloth/Qwen-AgentWorld-35B-A3B-GGUF`, quant `UD-Q4_K_M`, all 41/41 layers offloaded to GPU plus `moeCPULayers: 15` expert layers on CPU, context 65,536, flash attention on, parallel slots 1. Manifest comment: 15 CPU MoE layers is the minimum offload that fits 64k ctx in 16 GiB VRAM.
- **Storage:** model PVC is 100 GiB → single GGUFs up to ~90 GB are storable; RAM+VRAM combined gives a ~60 GB practical ceiling.

## TL;DR recommendation

**#1: Stay on / upgrade within the Qwen3.5-35B-A3B class MoE (your current `Qwen-AgentWorld-35B-A3B`) at `UD-Q4_K_M`, and try to raise quant quality toward `UD-Q5_K_M`/`UD-Q4_K_XL` by trimming context to 32k–48k if you want maximum reliability.** It is currently the best-quality open-weight agentic model that fits this node's RAM+VRAM envelope with the proven n-cpu-moe pattern (a 4060 Ti 16 GB owner reports ~60 tok/s at 64k ctx with `n-cpu-moe=11` on this exact model family), and it scores well on function calling (BFCL-V4 ~67% reported for Qwen3.5-35B-A3B).

**#2: GLM-4.7-Flash (30B-A3B, zai-org)** — Unsloth's explicitly recommended local agent model; native tool-call training, 203k context support, runs on 24 GB RAM-class hardware with the same `--n-cpu-moe` pattern. Use `UD-Q4_K_XL` minimum (Unsloth: ≥4-bit required for good performance).

**#3: gpt-oss-20b (OpenAI)** — dense-ish MoE small enough for full-GPU serving (~12–14 GB GGUF MXFP4/F16 variants fit entirely in 16 GiB), freeing you from CPU-expert bottleneck and giving very low latency; weaker raw capability than the two above but natively trained for agentic tool use with Harmony format.

Do not go below 4-bit weight quantization for a primary tool-use agent: Unsloth recommends ≥4-bit for agentic performance, and llama.cpp docs warn aggressive KV-cache quantization also degrades tool calling.

---

## Findings

### 1. Candidate models (recency-checked)

1. **Qwen3.5-35B-A3B / Qwen-AgentWorld-35B-A3B (Unsloth GGUF)** — 35B-total / ~3B-active MoE, 40 MoE layers, ~21 GB at Q4_K_M, up to 262k context claimed. Reported BFCL-V4 function-calling score ≈ 67.3%, and it is widely reported as a "gamechanger" for local agentic coding ([LLM Reference](https://www.llmreference.com/model/qwen3.5-35b-a3b), [r/LocalLLaMA](https://www.reddit.com/r/LocalLLaMA/comments/1rdxfdu/qwen3535ba3b_is_a_gamechanger_for_agentic_coding/)). Your currently-served `Qwen-AgentWorld` variant is an agentic/tool-use-tuned derivative of this architecture ([Qwen AgentWorld blog](https://qwen.ai/blog?id=qwen-agentworld)). Empirically proven on your exact GPU: RTX 4060 Ti 16 GB @ ~60 tok/s, 64k context, Q4_K_L, `n-cpu-moe=11` ([r/LocalLLaMA report](https://www.reddit.com/r/LocalLLaMA/comments/1smlvni/qwen3535b_running_well_on_rtx4060_ti_16gb_at_60/)).
2. **GLM-4.7-Flash (zai-org)** — 30B-A3B MoE, 202,752-token context per the official HF model card ([HF card](https://huggingface.co/zai-org/GLM-4.7-Flash)). Unsloth maintains refreshed Dynamic GGUFs and publishes a dedicated local-agent guide recommending `UD-Q4_K_XL` as the default quant with sampling `--temp 0.7 --top-p 1.0 --min-p 0.01 --repeat-penalty 1.0`, and warns older llama.cpp builds had a scoring-function bug causing output loops — use a current image ([Unsloth GLM-4.7-Flash guide](https://unsloth.ai/docs/models/glm-4.7-flash), [unsloth/GLM-4.7-Flash-GGUF](https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF)).
3. **gpt-oss-20b (OpenAI)** — natively optimized for agentic tasks including developer-defined functions and interleaved tool calls ([OpenAI model card / safety hub](https://deploymentsafety.openai.com/gpt-oss/agentic-tool-use)); official GGUF from ggml-org fits mostly or wholly in 16 GiB ([ggml-org/gpt-oss-20b-GGUF](https://huggingface.co/ggml-org/gpt-oss-20b-GGUF)). Caveat: third-party head-to-head testing found Qwen3-30B-A3B beat gpt-oss-20b on function-selection rate (93% vs 60%) and parallel calls, while gpt-oss was much faster ([Zenn benchmark](https://zenn.dev/daishiro/articles/local-llm-tool-calling-agent-benchmark?locale=en)) and its Harmony format is more parser-sensitive in llama-server ([openai/harmony](https://github.com/openai/harmony)).
4. **Larger frontier-open models are out of budget:** Kimi K2.5 (Jan 2026, huge MoE, [HF](https://huggingface.co/moonshotai/Kimi-K2.5)), DeepSeek-V3.2 (508B-class, [deepseek.com](https://www.deepseek.com/en/news/deepseek-v3-2/)), GLM-4.7 full, MiniMax-M2/M3 — all exceed the ~60 GB RAM+VRAM ceiling even at aggressive quants, or would thrash swap. llama.cpp *does* have architectures for them (`glm4moe`, `minimax-m2/m3`, kimi-linear/k2.5 support landed Feb 2026), so they're runnable in principle but not on this node ([llama.cpp llama-arch.h](https://github.com/ggml-org/llama.cpp/blob/master/src/llama-arch.h)).
5. **BFCL leaderboard context:** official BFCL V4 leaderboard last-updated April 2026; top open models there include Ling 3.0 Flash (~73%) and LFM2.5 variants, but none of those have the maturity/community tooling of the three picks above on llama.cpp ([gorilla.cs.berkeley.edu](https://gorilla.cs.berkeley.edu/leaderboard)).

### 2. Quantization guidance

- **Unsloth Dynamic (UD-*) quants** use model-specific layer-by-layer precision choices evaluated with KL-divergence and task benchmarks, not just perplexity; UD-Q4_K_M/XL generally matches or beats standard Q4_K_M at similar size ([Unsloth Dynamic 2.0 docs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs)).
- **≥4-bit floor for agents:** Unsloth explicitly says to use at least 4-bit for best performance on GLM-4.7-Flash and step up to UD-Q5_K_XL/Q6 when memory allows, especially for long multi-step coding agents ([Unsloth GLM-4.7-Flash guide](https://unsloth.ai/docs/models/glm-4.7-flash)). Sub-4-bit (UD-Q2_K etc.) degrades structured-output/tool-call JSON reliability first.
- **Template bugs matter more than quant tier sometimes:** Unsloth fixed a Qwen3.5 tool-calling chat-template bug affecting all quant uploaders (Feb 27, 2026 update) — always pull the latest refreshed GGUF revision ([Unsloth Dynamic docs changelog](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs), [r/unsloth](https://www.reddit.com/r/LocalLLaMA/comments/1rgel19/new_qwen3535ba3b_unsloth_dynamic_ggufs_benchmarks/)).
- **KV-cache quant also affects tool calling:** llama.cpp's function-calling doc warns aggressive KV quantization can substantially reduce tool-calling quality — prefer `-ctk q8_0 -ctv q8_0` over q4_0 for agent workloads ([llama.cpp function-calling doc](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md)).

### 3. Context vs VRAM on 16 GiB

- **Budget order:** non-expert weights on GPU → KV cache → as many expert layers as fit → leave 0.8–1.5 GiB free (llama.cpp `--fit` default margin is 1024 MiB) ([server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md?plain=1), [MoE tuning discussion #15280](https://github.com/ggml-org/llama.cpp/discussions/15280)).
- **Tuning loop:** start `--n-cpu-moe N = num_layers` (all experts on CPU), decrease N until VRAM is nearly full but stable; OOM → raise N; >1 GB free → lower N. For Qwen3.5-35B-A3B (40 MoE layers), N≈11 fits 64k ctx on a 4060 Ti 16 GB empirically.
- **64k is realistic; 128k possible with q8_0 KV + fewer GPU experts; 200k demonstrated on GLM-4.7-Flash REAP pruned variant on a 5060 Ti 16 GB** ([r/LocalLLaMA 200k ctx report](https://www.reddit.com/r/LocalLLaMA/comments/qlanzn)). Keep KV on GPU (`--no-kv-offload` slows generation badly) ([discussion #11005](https://github.com/ggml-org/llama.cpp/discussions/11005)).
- Your manifest's finding (15 CPU MoE layers minimum at 64k for AgentWorld-35B UD-Q4_K_M) is consistent with the community data point of 11 at slightly different quant/context; both confirm the pattern works.

### 4. Tool-calling support in llama.cpp server & llmkube mapping

- llama-server handles tool calls via the model's Jinja chat template with `--jinja`; use current builds since template/arch support moves fast ([server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md?plain=1), [function-calling doc](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md)). Known issues: gpt-oss Harmony parser edge cases; Ollama template incompatibilities flagged by Unsloth for GLM-4.7-Flash (not applicable — you use llama.cpp directly); old llama.cpp scoring-function bug caused looping with early GLM-4.7-Flash GGUFs.
- llmkube `Model` CRD maps cleanly: `source` → GGUF repo/file (pin the exact quant directory, e.g. `UD-Q4_K_M/`), `moeCPULayers` → `--n-cpu-moe`, GPU layers → `-ngl`, context/flash-attn/slots fields map to `-c`, `-fa on`, `--parallel`. Sampling overrides (`--temp 0.7 --top-p 1.0 --min-p 0.01 --repeat-penalty 1.0`) should be passed via extra args if the CRD supports them — repeat penalty must be 1.0 for GLM-4.7-Flash tool calls ([Unsloth guide](https://unsloth.ai/docs/models/glm-4.7-flash)).

### 5. Recommended serving parameters (#1 pick)

For `unsloth/Qwen-AgentWorld-35B-A3B-GGUF` (or newer Qwen3.5-35B-A3B refresh):

```yaml
quantization: UD-Q4_K_M      # floor for agentic; consider UD-Q5_K_M with ctx 32768
gpuLayers: all               # 41/41 attention+shared weights on GPU
moeCPULayers: 11–15          # tune down from 15 while VRAM allows; ~11 fits 64k
context: 65536               # realistic max; 131072 achievable with -ctk/-ctv q8_0
kvCache: q8_0/q8_0           # do NOT use q4_0 KV for tool calling
flashAttention: true
parallelSlots: 1
sampling: temp 0.7, top_p 1.0, min_p 0.01, repeat_penalty 1.0
```

## Ranked shortlist

| Rank | Model | Quant | Weights size | Est. footprint | Achievable ctx | Why |
|---|---|---|---|---|---|---|
| **1** | unsloth/Qwen-AgentWorld-35B-A3B (or newest Qwen3.5-35B-A3B refresh) | UD-Q4_K_M (→UD-Q5_K_M if ctx≤32k) | ~21 GB | ~13 GiB VRAM + ~10 GB RAM | 64k–128k | Best quality-in-budget; BFCL-V4 ~67%; proven at 60 tok/s on your exact GPU; agentic-tuned |
| **2** | zai-org/GLM-4.7-Flash | UD-Q4_K_XL | ~18 GB | ~12 GiB VRAM + ~8 GB RAM | up to ~128k+ (203k claimed) | Unsloth's recommended local agent model; native tool training; needs recent llama.cpp + repeat_penalty 1.0 |
| **3** | openai/gpt-oss-20b (ggml-org GGUF) | F16/original MXFP4 | ~12–13 GB | ~14 GiB VRAM (fully on GPU) | 32k–64k | Fastest (no CPU experts), natively agentic, lowest ops risk; weakest capability of the three |

## Sources

- Kept: [Unsloth Dynamic 2.0 GGUFs docs](https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs) — quant philosophy, ≥4-bit guidance, template-bug changelog
- Kept: [Unsloth GLM-4.7-Flash how-to-run guide](https://unsloth.ai/docs/models/glm-4.7-flash) — publisher quant/sampling recommendations for agentic use
- Kept: [zai-org/GLM-4.7-Flash HF card](https://huggingface.co/zai-org/GLM-4.7-Flash) — primary source for size/context
- Kept: [llama.cpp server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md?plain=1) — `--n-cpu-moe`, KV cache types, `--fit`
- Kept: [llama.cpp function-calling doc](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md) — KV quant vs tool-calling warning, `--jinja`
- Kept: [MoE tensor-allocation discussion #15280](https://github.com/ggml-org/llama.cpp/discussions/15280) — practical tuning loop
- Kept: [RTX 4060 Ti 16 GB Qwen3.5-35B report](https://www.reddit.com/r/LocalLLaMA/comments/1smlvni/qwen3535b_running_well_on_rtx4060_ti_16gb_at_60/) — hardware-identical empirical data point
- Kept: [OpenAI gpt-oss deployment-safety/agentic-tool-use](https://deploymentsafety.openai.com/gpt-oss/agentic-tool-use) — primary model-card evidence
- Kept: [Zenn local tool-calling benchmark](https://zenn.dev/daishiro/articles/local-llm-tool-calling-agent-benchmark?locale=en) — only direct Qwen-vs-gpt-oss head-to-head found
- Kept: [Berkeley BFCL leaderboard](https://gorilla.cs.berkeley.edu/leaderboard) — official function-calling leaderboard
- Dropped: blog summaries (insiderllm PDFs, al-engr, benchlm mirrors) — secondary/aggregator content
- Dropped: Kimi K2.5 / DeepSeek-V3.2 coverage — out of hardware budget despite recency

## Gaps

- No published BFCL/tau-bench score specifically for the `Qwen-AgentWorld-35B-A3B` fine-tune itself (only base Qwen3.5-35B-A3B ≈67% BFCL-V4).
- Exact VRAM numbers per quant for AgentWorld-35B not published; estimates derived from GGUF sizes and the 4060 Ti community data point. Verify empirically by lowering `moeCPULayers` from 15 toward 11 and watching nvidia-smi.
- Whether llmkube exposes sampling overrides (repeat_penalty/min_p) was not verifiable without repo access to the CRD schema — check locally before deploying GLM-4.7-Flash.

## Addendum: decision for Hermes (2026-08-22)

Hermes' workload is ~80% general Q&A with light, single-shot tool use (cluster status query, daily PR overview) — not deep multi-step agentic loops. Agentic-specialized tunes (e.g. Qwen-AgentWorld) tend to be tool-trigger-happy and terse, which is a poor fit for a chat-first assistant. The hybrid chat+agent tuning of **GLM-4.7-Flash** matches this profile better, so it was selected over the #1-ranked AgentWorld pick.

Follow-up verification:

- `unsloth/GLM-4.7-Flash-GGUF` `UD-Q4_K_XL` is ~17.5–18.3 GB ([HF file listing](https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF/blob/main/GLM-4.7-Flash-UD-Q4_K_XL.gguf)) — fits the node via the same n-cpu-moe pattern (community starting point ≈24 CPU expert layers at 64k ctx on 16 GiB; tune downward while VRAM allows).
- Sampling per Unsloth: tool/agent use `--temp 0.7 --top-p 1.0`, `--min-p 0.01`, and **`--repeat-penalty 1.0`** (non-default penalties break GLM tool calls).
- llmkube passes sampling through `extraArgs` (already used in `models.yaml`), so the open gap above is resolved — no CRD change needed.
- Keep KV cache on GPU unquantized or q8_0; avoid q4_0 KV (llama.cpp function-calling doc warning still applies).
- **MTP (multi-token prediction):** GLM-4.7-Flash ships an MTP (`nextn`) module usable on vLLM via speculative decoding, but it is not usable in our stack today: standard Unsloth GGUF conversions (~862 tensors) discard the MTP weights (only regenerated ~868-tensor files keep them), llama.cpp `--spec-type draft-mtp` support for this arch is new/experimental, and gains are unproven when expert layers sit on CPU over PCIe. Speed levers in order: tune `moeCPULayers` down; revisit MTP-inclusive GGUFs once a stable llama.cpp release supports `draft-mtp`; optionally try a separate draft model (`--spec-type draft-simple`).
