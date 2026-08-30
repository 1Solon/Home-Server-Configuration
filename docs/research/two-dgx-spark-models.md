# Research: Models for two DGX Spark systems

**Date:** 2026-08-30
**Scope:** Whether the models shown in the supplied model picker can be served locally on two NVIDIA DGX Spark systems, and which option is the best fit for a Hermes/OpenAI-compatible agent. Throughput is reported only when a public two-Spark measurement exists; estimates and measurements from different runtimes are not blended.

## Verdict

Two DGX Spark systems are two 128 GB unified-memory GB10 machines, not one 256 GB GPU. A tensor-parallel service can distribute weights across them, but every rank still needs memory for model state, KV cache, activations, CUDA graphs, and the serving runtime. The practical aggregate budget is below the nominal 256 GB, and the ConnectX-7 link becomes part of the per-token critical path.

### Recommended order

1. **GLM-5.3-Flash** is the strongest operational choice if using a patched GB10 vLLM image is acceptable. Public TP=2 measurements report **46.9 tok/s warm code with NVFP4**, **61.7-62.9 tok/s structured output with EXL3**, **26.9 tok/s on an EXL3 hash-map prose prompt**, and **about 895-975 tok/s cold, uncached prefill** from 8K through 300K on two Sparks, with an OpenAI-compatible endpoint and recipe-specific tool/reasoning parsers.
2. **DeepSeek-V4-Flash-0731** is the best long-context alternative. A public TP=2 DSpark recipe reports roughly **55 tok/s typical** and **78 tok/s peak**, with 1M context. It needs the model's dedicated encoder/parser path and version-specific serving fixes.
3. **Qwen3.8-Flash-Next** is proven on one and two GB10-class systems, with roughly **45-65 tok/s single-stream on two Sparks** across public recipes and up to about **70 tok/s** on favorable structured work. Its large n-gram embedding table makes memory handling and long-context correctness more delicate.
4. **MiniMax-M3** fits, but only tightly. A two-Spark W4A16 deployment reports **36.6 tok/s JSON / 31.8 tok/s code** at a 196K ceiling with a 208,128-token KV pool. It leaves little memory for larger context or concurrency.
5. **Qwen3.8-27B** is the low-operations fallback. It fits on one Spark and can be replicated across both for availability or aggregate throughput; using both for one request is unnecessary.

### Picker-row quick answer

`max`, `high`, `medium`, `low`, and `xhigh` change reasoning effort and generated-token count, not weight footprint. Raw decode throughput remains runtime/configuration dependent; effort can change total wall time substantially because a higher setting often generates more reasoning tokens.

| Picker row | Run locally on 2x Spark? | Practical local performance | Coding and Hermes verdict |
|---|---|---|---|
| Kimi K3 (max) | **No**; public recipe uses 16 Sparks | N/A on two Sparks; 16-Spark recipe reports 19.8 general / 25.4 code tok/s | Excellent model, wrong hardware tier |
| GLM-5.3 (max) | **No**; public recipe uses 8 Sparks | N/A on two Sparks | Frontier coding quality, but use its API or the Flash model locally |
| Qwen3.8 2.4T A95B | **No**; about 1.2 TB ideal 4-bit lower bound | N/A on two Sparks | Frontier coding quality, API only for this hardware |
| GLM-5.3-Flash | **Yes, proven** | **46.9 warm code tok/s** with NVFP4; **61.7-62.9 structured tok/s** and **895-975 cold prefill tok/s at 8K-300K** with EXL3; **26.9 hash-map prose tok/s** with EXL3 | **Best local coding/Hermes choice**; recipe-specific GLM tool/reasoning parsers are available |
| Qwen3.8-Flash-Next | **Yes, proven** | 45-65 typical planning range, up to about 70 favorable; 116.8 aggregate at c2; uncached dual-node prefill 2,328-2,960 tok/s at 1K-16K; 1x-Spark prefill 2,030-2,460 tok/s | Fast and strong; validate SM121 long-context correctness and preserved reasoning before trusting it with agents |
| DeepSeek V4 Pro 0813 (max) | **No**; approximately 1.6T total weights | N/A on two Sparks | Excellent coding, but API or much larger cluster only |
| GLM-5.2 (max) | **No**; 8-Spark public recipe | N/A on two Sparks | Good but superseded for this purchase by GLM-5.3-Flash |
| Qwen3.8 27B (xhigh) | **Yes, easily; one Spark is enough** | No matched Spark result; local decode and prefill performance are **not established by the cited sources** | Simplest and lowest-risk Hermes endpoint; materially weaker long-horizon coding than the Flash models; xhigh increases total generated tokens |
| DeepSeek V4 Flash 0731 (max) | **Yes, proven** | 37.8 prose, 62.2 code, 55.4 measured mean, 66.1 favorable peak; 1,513-2,639 prefill tok/s on the preview stack | **Best long-context option**; strong coding, but its dedicated encoding/parser path makes Hermes setup less forgiving |
| Kimi K3 (low) | **No**; same Kimi K3 weights | Same fit result as `max`; only reasoning effort changes | Same model and quality ceiling; lower effort is faster end-to-end, not locally runnable |
| Motif 3 | **Experimental fit** at NVFP4 | No Spark measurement; local decode and prefill performance are **not established by the cited sources** | Strong SWE-bench Verified result and official parsers; do not buy around it until someone demonstrates a correct GB10 deployment |
| MiniMax-M3 | **Yes, proven but tight** | 31.8 code / 36.6 JSON tok/s; no published prefill; 196K balanced context | Good tools and coding, but single-stream and tiny memory margin make it a worse Hermes service than GLM or DeepSeek |
| DeepSeek V4 Pro (max) | **No**; older preview of the Pro family | N/A on two Sparks | Superseded by `-0813`; neither fits |
| Qwen3.8 27B (medium) | **Yes, easily; same weights as xhigh** | No effort-specific raw decode measurement is cited; fewer reasoning tokens generally reduce wall time | Better default than xhigh for routine Hermes tasks; raise effort only for hard coding jobs |
| DeepSeek V4 Pro (high) | **No**; same preview weights as the max row | N/A on two Sparks | Same fit result; only reasoning effort differs |
| Kimi K2.7 Code | **No**; about 500 GB ideal 4-bit lower bound | N/A on two Sparks | Coding-specialized and attractive, but requires a larger cluster or API |
| MiMo-V2.5-Pro | **No**; public Spark recipe uses 8 nodes | N/A on two Sparks | Good coding/tool support, wrong hardware tier |

The Qwen3.8-27B and Motif 3 performance entries are intentionally not estimated because the cited sources contain no direct Spark measurements. All other numeric throughput values in the table are public measurements on one or two GB10 systems as identified.

### Do not plan around these on two Sparks

**Kimi K3, Kimi K2.7 Code, full GLM-5.3, GLM-5.2, Qwen3.8-2.4T-A95B/Qwen3.8-Max, DeepSeek-V4-Pro, and MiMo-V2.5-Pro** are not credible two-Spark targets. Public GB10 recipes for Kimi K3 and GLM-5.2/5.3 use 16 and 8 Sparks respectively; the MiMo recipe uses 8 nodes. Active MoE parameters reduce compute per token, but they do not remove the need to store the complete expert set.

**Motif 3** is an experimental possibility, not a deployment recommendation. Its NVFP4 checkpoint may fit in the raw two-node weight budget, but the official deployment instructions are tested on H200/B200 and no two-Spark result was found.

The picker labels `max`, `high`, `medium`, `low`, and `xhigh` are reasoning-effort settings, not separate model weights. `Qwen3.8-Max` is the hosted Qwen service based on `Qwen3.8-2.4T-A95B`; it is not a smaller local checkpoint.

## Hardware and topology

NVIDIA documents each DGX Spark as a GB10 Grace Blackwell system with 128 GB LPDDR5x unified memory, 273 GB/s memory bandwidth, a 20-core Arm CPU, 6,144 CUDA cores, and two ConnectX-7 QSFP ports. Each QSFP port is up to 200 Gb/s. NVIDIA explicitly positions clustering for models that do not fit on one device and advertises support up to 405B for a dual-Spark configuration, but that sizing is not a guarantee for every architecture, quantization, context length, or runtime.

For two-node tensor parallelism, use a direct 200 Gb/s QSFP connection and configure NCCL/RoCE on the ConnectX-7 interface. The NVIDIA guide says the two nodes must be physically cabled, have IP addresses on the inter-device interfaces, and use the correct interface mapping. A data-parallel deployment instead runs one complete model copy per Spark; it improves aggregate capacity but cannot make one request faster.

| Property | Per Spark | Two-Spark implication |
|---|---:|---|
| Unified memory | 128 GB | 256 GB nominal; less is usable after the OS/runtime |
| Memory bandwidth | 273 GB/s | Not a single shared 546 GB/s pool |
| GPU | GB10 Blackwell, 6,144 CUDA cores | One GPU/rank in the public TP=2 recipes |
| Cluster link | 2x ConnectX-7 QSFP, up to 200 Gb/s/port | Required for practical TP2; link latency/bandwidth affects decode |
| NVIDIA model-size guidance | 200B one Spark / 405B dual Spark | Marketing guidance, not a fit test |

Sources: [NVIDIA DGX Spark hardware guide](https://docs.nvidia.com/dgx/dgx-spark/hardware.html) and [NVIDIA ConnectX-7 clustering guide](https://docs.nvidia.com/dgx/dgx-spark/spark-clustering.html).

## Model resolution and fit

The fit column means fit as a useful service with room for KV cache and runtime overhead, not merely that a quantized file can be placed on disk.

| Picker label | Local identifier | Official size / context | Two-Spark result |
|---|---|---|---|
| Kimi K3 (max) | [`moonshotai/Kimi-K3`](https://huggingface.co/moonshotai/Kimi-K3) | MoE, 2.8T total / 104B active; 1,048,576 context; native MXFP4 weights | **No.** The public GB10 deployment uses TP16 on 16 Sparks; the recommended TP16 recipe reports 19.82 tok/s on a general corpus and 25.38 tok/s on coding. |
| GLM-5.3 (max) | [`zai-org/GLM-5.3`](https://huggingface.co/zai-org/GLM-5.3) | Approximately 753B repository artifact; same base architecture as GLM-5.2; 1M context inherited from GLM-5.2 | **No.** The public GB10 Int4-Int8Mix deployment is TP8 on 8 Sparks. |
| Qwen3.8 2.4T A95B | [`Qwen/Qwen3.8-2.4T-A95B`](https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B) | MoE, 2.4T total / 95B active; 262,144 native, extensible to about 1.01M | **No.** Even an ideal 4-bit lower bound is about 1.2 TB of weights before scales, KV, or runtime state. |
| GLM-5.3-Flash | [`zai-org/GLM-5.3-Flash`](https://huggingface.co/zai-org/GLM-5.3-Flash) | MoE, 320B total / 18B active; 1M-native checkpoint in the public GB10 recipe | **Yes, proven.** TP2 NVFP4 recipes exist and have direct measurements. |
| Qwen3.8-Flash-Next | [`Qwen/Qwen3.8-Flash-Next`](https://huggingface.co/Qwen/Qwen3.8-Flash-Next) | 125B language model / 6B active, plus a 51B n-gram table and 4B MTP component; 262,144 native | **Yes, proven but memory-sensitive.** Public NVFP4 recipes use mmap/offload handling for the approximately 126 GiB checkpoint. |
| DeepSeek-V4-Pro-0813 | [`deepseek-ai/DeepSeek-V4-Pro-0813`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro-0813) | DeepSeek V4 Pro family: about 1.6T total / 49B active; 1M context; FP4 experts plus FP8 non-expert state | **No.** The complete weight budget is far above two Sparks; no two-Spark deployment was found. |
| GLM-5.2 | [`zai-org/GLM-5.2`](https://huggingface.co/zai-org/GLM-5.2) | 753B repository artifact; 1M context; MTP support | **No.** The public GB10 production recipe is TP8 on 8 Sparks. |
| Qwen3.8-27B | [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) | Dense 27B; 262,144 native, extensible to 1M; native image/video input | **Yes, easily.** It should fit on one Spark at practical quantizations. Use DP2 rather than TP2 unless a specific latency test justifies sharding. |
| DeepSeek-V4-Flash-0731 | [`deepseek-ai/DeepSeek-V4-Flash-0731`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731) | V4 Flash family: 284B total / 13B active; 1M context; FP4 experts plus FP8 non-expert state | **Yes, proven.** Public TP2 DSpark deployments serve the official 0731 release. |
| Motif 3 | [`Motif-Technologies/Motif-3`](https://huggingface.co/Motif-Technologies/Motif-3) | MoE, approximately 314B total / 13.2B active; 262,144 context; NVFP4 checkpoint available | **Experimental.** Official vLLM instructions target H200/B200 and no Spark measurement was found. |
| MiniMax-M3 | [`MiniMaxAI/MiniMax-M3`](https://huggingface.co/MiniMaxAI/MiniMax-M3) | MoE, approximately 428B total / 23B active; 1M context | **Yes, tightly.** W4A16 TP2 deployment is measured; 4-bit KV and a single stream are part of the proven configuration. |
| DeepSeek-V4-Pro | [`deepseek-ai/DeepSeek-V4-Pro`](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro) | Preview V4 Pro, about 1.6T total / 49B active; 1M context | **No.** Treat the unsuffixed preview and the 0813 release as separate artifacts; neither has a two-Spark fit result. |
| Kimi K2.7 Code | [`moonshotai/Kimi-K2.7-Code`](https://huggingface.co/moonshotai/Kimi-K2.7-Code) | MoE, 1T total / 32B active; 256K context; native INT4 quantization | **No.** An ideal 4-bit lower bound is about 500 GB before scales, KV, and runtime state. |
| MiMo-V2.5-Pro | [`XiaomiMiMo/MiMo-V2.5-Pro`](https://huggingface.co/XiaomiMiMo/MiMo-V2.5-Pro) | MoE, 1.02T total / 42B active; up to 1M context; FP8 mixed | **No.** The public DGX Spark deployment uses TP8 across 8 nodes. |

### Why active parameters are not the fit metric

For an MoE model, active parameters approximate the compute performed for one token. The complete routed-expert weight set still has to be resident or repeatedly fetched. A useful lower-bound check is:

```text
weight bytes >= total parameters * bits per weight / 8
```

This deliberately ignores scales, embeddings, unquantized attention, KV cache, activations, and safety headroom. It is therefore optimistic. It explains why a 1T model with 32B active parameters is not a 32B deployment, while a 320B model with 18B active parameters can be viable when a specialized NVFP4 TP2 stack is available.

## Two-Spark throughput evidence

These measurements are from different checkpoints, engines, quantizations, prompt sets, and warm-up protocols. They are planning evidence, not an apples-to-apples leaderboard.

| Model and deployment | Decode evidence | Prefill / concurrency evidence | Status |
|---|---|---|---|
| **GLM-5.3-Flash**, TP2, NVFP4 or EXL3 weights, DFlash2, fp8 KV | NVFP4 recipe: **46.9 tok/s** warm code and **54-61 tok/s** structured. EXL3 4-bpw recipe: **62.9 tok/s** sparkDash structured result (**61.7 tok/s** lab median) and **26.9 tok/s** hash-map prose | EXL3 cold, uncached prefill: **895 tok/s at 8K**, **975 at 100K**, **973 at 256K**, and **941 at 300K**. Warm/empty-KV structured concurrency reaches **146.5 aggregate tok/s at c4**; prose and long-context decode are about 24-27 tok/s | Direct measurements on two Sparks, but not a matched quantization comparison. The EXL3 result uses specialized fused kernels and DFlash2; speculative acceptance makes output shape decisive. |
| **DeepSeek-V4-Flash-0731**, TP2, DSpark, NVFP4 KV, 1M | Official 0731 recipe: about **55 tok/s typical**, **78 tok/s peak**; a patched run reports **55.4 mean / 66.1 peak**, with **62.2 code** and **66.1 structured** | A realistic mixed c4 run on the same recipe reports **22.3 tok/s per stream / 88.6 aggregate**; preview-checkpoint prefill measurements reached **1,513 tok/s at 6K**, **2,284 at 25K**, and **2,639 at 78K** | Direct two-Spark evidence, but do not transfer preview prefill numbers to 0731 without rerunning. |
| **Qwen3.8-Flash-Next**, TP2, NVFP4, NEXTN/MTP | **64.4 tok/s** single stream and **69.7-70.2 tok/s** favorable peak in separate recipes | **116.8 tok/s aggregate** at two streams in one report; uncached dual-node prefill **2,328 / 2,759 / 2,960 tok/s** at 1K / 4K / 16K; one-GB10 prompt throughput about **2,030-2,460 tok/s** | Direct community measurements. Correctness testing is essential because an early SM121 sparse-attention path could silently corrupt long contexts. |
| **MiniMax-M3**, TP2, W4A16 GPTQ, 4-bit KV, EAGLE3 | **36.6 tok/s JSON / 31.8 tok/s code**, single stream, temp 0 | Proven profile has a **196K** context ceiling and **208,128-token** KV pool; concurrency beyond one stream and prefill throughput are not established by the cited measurement | Direct measurement. Weight load is about 224 GB on disk, leaving roughly 9 GB/node for KV in the cited configuration. |

The EXL3 checkpoint is under **ShapleyMCG License 1.0** and the DFlash2 drafter is **CC BY-NC-ND 4.0**; verify those terms before production or commercial use.

### Coding quality signals

The following are publisher-reported or model-card evaluation results. They use different harnesses and should not be interpreted as a controlled comparison. They are useful for identifying capability tiers, not for predicting local speed.

| Model | Terminal Bench 2.1 | DeepSWE | SWE-bench Pro / Verified | Tool-use signal |
|---|---:|---:|---:|---|
| GLM-5.3 | 88.2 | 66.9 | Not reported / not used here | Toolathlon 73.0; AutomationBench 48.2 |
| GLM-5.3-Flash | 84.3 | 63.4 | Not reported / not used here | Structured tool parser available in the proven Spark recipe |
| Qwen3.8-Flash-Next | Not reported | 58.7 | 62.5 Pro / not shown | Toolathlon-Verified 73.5; official card documents preserved reasoning for agent turns |
| Qwen3.8-Max / 2.4T checkpoint | 86.6 | 56.6 | 67.7 / not shown | Toolathlon 72.5 |
| Qwen3.8-27B | 73.0 | 42.2 | 61.7 / not shown | QwenSWEBench 79.0; local card documents OpenAI-compatible serving |
| DeepSeek-V4-Pro-0813 | 87.9 | 62.7 | 61.5 NL2Repo / not shown | Toolathlon-Verified 74.1 |
| DeepSeek-V4-Flash-0731 | 82.7 | 54.4 | 54.2 NL2Repo / not shown | Toolathlon-Verified 70.3 |
| GLM-5.2 | 81.0, or 82.7 best reported harness | 46.2 | 62.1 / not shown | MCP-Atlas 76.8 |
| Motif 3 | 74.9 | Not reported | Not reported / 76.2 | Official parser flags are `motif`; tested on H200/B200 |
| MiniMax-M3 | 65.2 in the publisher comparison | Not reported | Not reported / 75.0 | Proven Spark recipe uses `minimax_m3` parser and clean JSON tool calls |
| MiMo-V2.5-Pro | Not shown in the retrieved card | Not shown | 57.2 / 78.9 | Official SGLang example uses `mimo` reasoning and tool parsers |
| Kimi K3 | 88.3 | 67.5 | Not reported | Toolathlon-Verified 76.5; 16-Spark deployment has streamed tool arguments |
| Kimi K2.7 Code | Not shown | Not shown | Not shown | MCP-Mark Verified 81.1 and MCP-Atlas 76.0; hardware is the blocker |

Sources for the quality table are the linked first-party model cards above. The local throughput artifacts are listed in [Sources](#sources).

## Hermes compatibility

Hermes connects to an OpenAI-compatible endpoint. The repository's Hermes research identifies Chat Completions as the lowest-risk default, with the server API key, network-reachable bind, and `/v1` URL required. Model-specific parsing still matters: a successful HTTP response is not proof that reasoning or tool calls were represented correctly.

| Model | Hermes suitability | Required caution |
|---|---|---|
| **GLM-5.3-Flash** | **Best overall two-Spark candidate** | Use the tested parser/runtime combination. The public recipe enables automatic tool choice, uses a GLM parser, and exposes an OpenAI-compatible API. Prefer the corrected compressed-tensors NVFP4 checkpoint over the ModelOpt build when following that recipe; its author reports intermittent corrupted token IDs in the older build. |
| **DeepSeek-V4-Flash-0731** | **Good, with adapter work** | The official release intentionally has no Jinja chat template. Use its `encoding` package or a runtime with the matching DeepSeek parser. `max_tokens` includes reasoning and visible output; in-progress tool calls must be discarded when truncated. Avoid client stop strings firing inside `<think>`. |
| **Qwen3.8-Flash-Next** | **Promising but validate before production** | Use the latest SGLang/vLLM path and run long-context needle retrieval plus tool-call tests. Preserve the model's reasoning history when using multi-turn agents. The known SM121 attention corruption issue makes correctness more important than headline tok/s. |
| **MiniMax-M3** | **Good if the tight memory profile is acceptable** | Use the `minimax_m3` reasoning/tool parser and the validated W4A16 plus 4-bit KV recipe. The cited deployment has clean tool calls, but little KV headroom and MiniMax's model license is separate from the serving code license. |
| **Qwen3.8-27B** | **Simplest fallback** | The local card documents OpenAI-compatible vLLM/SGLang serving and reasoning controls. Validate the exact tool parser and chat template selected by the runtime; use DP2 for service capacity if desired. |
| **Motif 3** | **Not yet** | The model card explicitly supplies tool/reasoning parser flags, but only H200/B200 deployment is documented. Do not infer Spark support from the existence of an NVFP4 checkpoint. |

For Qwen, GLM, Kimi, DeepSeek, MiniMax, and MiMo, `reasoning_effort` values shown in the picker control token budget or prompt formatting. They can change end-to-end agent latency substantially; do not assume effort levels have identical decode behavior when speculative acceptance and output shape also affect throughput.

### Hermes field reports: DeepSeek versus Qwen

The direct Hermes reports favor **DeepSeek-V4-Flash as the more dependable daily driver today**, not as an uncontested better model. One user running Qwen through Hermes on a single Spark reported an overnight cache-contamination failure and a `systemd-oomd` service kill, then explicitly called DeepSeek V4 the more dependable daily agent. A separate dual-Spark DeepSeek user described weeks of flawless 24/7 operation, and another reported using Hermes with DeepSeek on dual Sparks for routine remote computer administration. These are meaningful operational endorsements, but they are anecdotes rather than a controlled model-quality comparison.

The contrary evidence is material. Another single-Spark Hermes Desktop report found Qwen at least as useful as DeepSeek, and possibly better on some real agent tasks, despite Qwen scoring slightly worse in that user's benchmark. That report preferred Qwen's concision and native vision support and no longer observed earlier looping after runtime updates. A further user said DeepSeek worked well and was slightly faster but still preferred aspects of Qwen.

The defensible summary is therefore: **several experienced users prefer DeepSeek-V4-Flash for mature, long-running Hermes reliability, while Qwen3.8-Flash-Next remains competitive and may be better for some agent workflows**. Do not convert that into a general intelligence ranking. The comparisons mix one- and two-Spark deployments, different quantizations and engines, and a rapidly changing launch-period Qwen software stack.

## Deployment recommendation

### Default: GLM-5.3-Flash

Use a TP2 deployment with the proven community stack rather than a generic upstream image. The cited two-Spark recipe uses NVFP4 weights, fp8 KV, DFlash2 speculative decoding, a 262,144-token ceiling, and an OpenAI-compatible port. Pin the image, model revision, parser, NCCL interface, and exact quantization. Run deterministic text, structured JSON, tool-call, and long-context correctness probes after every image or model change.

### Alternative: DeepSeek-V4-Flash-0731

Use the official 0731 checkpoint with the validated DSpark recipe if 1M context is more important than simpler integration. Keep the dedicated encoder/parser files with the model cache. Treat the 1M setting as a ceiling shared by a finite KV pool, not as six simultaneous 1M requests. Measure warm and mixed agent traffic rather than quoting the best repetitive-output number.

### Fallback: Qwen3.8-27B or Qwen3.8-Flash-Next

Choose Qwen3.8-27B for lower operational risk and one-Spark placement. Choose Qwen3.8-Flash-Next only when the larger model and long-context behavior justify the specialized memory/runtime handling. The existing Qwen benchmark report in this repository should be used as the source of its detailed SM121 correctness and throughput caveats.

### Do not use two Sparks as a reason to buy a larger checkpoint

Two Sparks are justified by model fit, KV headroom, aggregate service throughput, or experimentation with TP2. They are not sufficient for the 1T-to-2.8T choices in the picker. For those, the evidence points to a larger cluster, a hosted endpoint, or a smaller local model rather than an aggressive two-node quantization.

## Gaps and validation plan

- No matched benchmark holds checkpoint, quantization, context, sampling, runtime, and prompt set constant across all candidates.
- No public two-Spark prefill result was found for MiniMax-M3. GLM-5.3-Flash now has a direct EXL3 prefill ladder, but it is not a matched comparison with the NVFP4 recipe.
- Motif 3 has no GB10 measurement; its two-Spark fit remains an experiment even though its NVFP4 weights may fit mathematically.
- Local tool-call correctness is more important than model-card scores for Hermes. Test malformed arguments, parallel calls, multi-turn preserved reasoning, truncated calls, and tool-result replay.
- Before deployment, benchmark each shortlisted model with: cold boot, warm single stream, 4-way mixed agent traffic, 8K/32K/128K prefill, JSON/tool calls, and a long-context retrieval needle. Record completion tokens from server usage rather than counting streamed chunks.

## Sources

### Official hardware

- [NVIDIA DGX Spark hardware guide](https://docs.nvidia.com/dgx/dgx-spark/hardware.html) - memory, compute, power, and NVIDIA's model-size guidance.
- [NVIDIA DGX Spark ConnectX-7 clustering guide](https://docs.nvidia.com/dgx/dgx-spark/spark-clustering.html) - QSFP cabling, 200 Gb/s ports, interface mapping, and multi-Spark networking.

### Official model cards and technical reports

- [Kimi K3](https://huggingface.co/moonshotai/Kimi-K3) - 2.8T/104B, 1M context, coding/agent benchmarks, reasoning and API behavior.
- [Kimi K2.7 Code](https://huggingface.co/moonshotai/Kimi-K2.7-Code) - 1T/32B, 256K context, coding/tool benchmarks, native INT4 and API behavior.
- [GLM-5.3](https://huggingface.co/zai-org/GLM-5.3) and [GLM-5.2](https://huggingface.co/zai-org/GLM-5.2) - model cards, benchmarks, context, and supported runtimes.
- [GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash) - 320B/18B, multimodality, reasoning controls, and serving frameworks.
- [Qwen3.8-2.4T-A95B](https://huggingface.co/Qwen/Qwen3.8-2.4T-A95B) - 2.4T/95B, context, Qwen3.8-Max relationship, benchmark results, and local serving.
- [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) - 27B, context, vision, coding benchmarks, and local serving.
- [Qwen3.8-Flash-Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next) - local checkpoint details and native context; see the existing repository report for the complete benchmark extraction.
- [DeepSeek-V4-Pro-0813](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro-0813) - official release, 1M context, DSpark, dedicated encoding, and agent benchmarks.
- [DeepSeek-V4-Flash-0731](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731) - official release, 1M context, DSpark, dedicated encoding, and agent benchmarks.
- [DeepSeek-V4-Pro](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro) and [DeepSeek-V4-Flash](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash) - preview family size, precision, context, and comparison results.
- [Motif 3](https://huggingface.co/Motif-Technologies/Motif-3) - 314B/13.2B, architecture, NVFP4 availability, parser flags, and H200/B200 deployment.
- [MiniMax-M3](https://huggingface.co/MiniMaxAI/MiniMax-M3) - 428B/23B, 1M context, sparse attention, reasoning modes, and serving frameworks.
- [MiMo-V2.5-Pro](https://huggingface.co/XiaomiMiMo/MiMo-V2.5-Pro) - 1.02T/42B, 1M context, MTP, parser flags, and deployment requirements.

### Direct two-Spark benchmark artifacts

- [GLM-5.3-Flash NVFP4 dual DGX Spark](https://github.com/MiaAI-Lab/GLM-5.3-Flash-NVFP4-Dual-DGX-Spark) - TP2 topology, parsers, quantization, and structural throughput.
- [GLM-5.3-Flash EXL3 dual DGX Spark](https://github.com/MiaAI-Lab/GLM-5.3-Flash-EXL3-2x-DGX-Sparks) - 4-bpw EXL3 weights, DFlash2 code/structured/prose decode, concurrency, and 8K-300K prefill measurements.
- [GLM-5.3-Flash DFlash2 dual DGX Spark](https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark) - corrected quantization, DFlash2 results, concurrency, and SM121 caveats.
- [DeepSeek-V4-Flash-0731 DSpark dual DGX Spark](https://github.com/tonyd2wild/Deepseek-v4-Flash-0731-DSpark-1M-NVFP4-KV-2x-DGX-Spark) - 0731/preview measurements, 1M profile, prefill, concurrency, and reasoning/tool-call caveats.
- [DeepSeek-V4-Flash DSpark dual DGX Spark](https://github.com/MiaAI-Lab/DeepSeek-v4-Flash-DSpark-2x-DGX-Spark) - official 0731 update, typical/peak speed, and deployment requirements.
- [MiniMax-M3 dual DGX Spark](https://github.com/tonyd2wild/MiniMax-M3-2x-DGX-Spark-36-tok-s) - W4A16 weight size, KV pool, and measured JSON/code throughput.
- [MiniMax-M3 three-Spark result](https://github.com/tonyd2wild/Minimax-M3-NVFP-3x-DGX-Sparks-TP-3) - supporting evidence that larger parallelism is slow and interconnect-sensitive.
- [Qwen3.8-Flash-Next benchmark report already in this repository](qwen38-flash-dgx-spark-benchmarks.md) - one- and two-GB10 measurements, prefill, concurrency, and SM121 correctness warnings.

### Public GB10 scale evidence

- [Kimi K3 GB10 platform recipes](https://github.com/ciprianveg/gb10-vllm) - public 16-Spark Kimi K3 and 8-Spark GLM recipes, runtimes, and model-specific deployment scale.
- [MiMo-V2.5-Pro 8-node DGX Spark recipe](https://github.com/idonati/spark-vllm-docker-festr2) - public scale evidence for the MiMo model family.

### Hermes field reports

- [Qwen cache and memory failure; DeepSeek called the more dependable daily agent](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/193) - single-Spark Qwen Hermes workflow and operational comparison.
- [Dual-Spark DeepSeek described as flawless over weeks of 24/7 work](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/169) - long-running DeepSeek field report.
- [Hermes with DeepSeek on dual Sparks for remote computer administration](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/187) - practical agent-workflow report.
- [Qwen described as at least as useful as DeepSeek and possibly better for some tasks](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/209) - contrary single-Spark field report, including native vision and improved looping behavior.
- [DeepSeek described as slightly faster while the user still liked Qwen](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/166) - mixed preference report.

### Repository context

- [Hermes settings research](hermes-open-webui-settings.md) - OpenAI-compatible connection requirements, Chat Completions recommendation, and tool/streaming behavior.
- [Existing kube5 model research](best-agentic-model-for-kube5.md) - local agent/tool-calling priorities and the repository's preference for explicit runtime correctness validation.
