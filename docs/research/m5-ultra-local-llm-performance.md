# M5 Ultra local-LLM performance outlook

**Date:** 2026-09-14  
**Status:** Pre-release estimate. Apple announced the M5 Ultra Mac Studio on 2026-08-25; deliveries begin 2026-09-22 and the 512 GB configuration is due in late October. No trustworthy independent M5 Ultra Qwen benchmark was available at the time of writing.

## Hardware

The maximum M5 Ultra configuration has a 36-core CPU, 80-core GPU, 32-core Neural Engine, 1.2 TB/s unified-memory bandwidth, 512 GB unified memory, and up to 16 TB SSD. Maximum continuous system power is 480 W. The 512 GB memory option increases capacity, not compute speed; an 80-core/256 GB machine should run a model that fits in 256 GB at essentially the same speed. [Apple specifications](https://www.apple.com/mac-studio/specs/) [Apple announcement](https://www.apple.com/newsroom/2026/08/apple-introduces-new-mac-studio-with-m5-max-and-m5-ultra/)

Apple claims up to four times M3 Ultra LLM prompt-processing performance in LM Studio. This is a vendor-selected TTFT/prefill result and does not imply four-times decode speed. The new GPU Neural Accelerators mainly target matrix-heavy prompt processing; autoregressive generation remains more sensitive to memory bandwidth and dual-die software scaling.

## Expected Qwen performance

The following ranges are engineering estimates, not measured M5 Ultra results. They combine existing M5 Max, M5 Pro, and M3 Ultra oMLX measurements with the M5 Ultra's doubled M5 Max GPU resources, 1.2 TB/s bandwidth, Apple's prefill claim, and an allowance for imperfect UltraFusion/dual-die scaling.

| Model / practical stack | Estimated prefill | Estimated 64K cold prefill | Estimated batch-one generation |
|---|---:|---:|---:|
| Qwen3.5/3.6 35B-A3B, optimized 4-bit MLX/MTP | 4,000–8,000 tok/s | 8–16 s | 180–260 tok/s |
| Qwen3.8-27B, optimized 4-bit MLX with speculative prefill/MTP | 3,000–6,000 tok/s | 11–22 s | 70–120 tok/s |
| 70B dense Q4 | 1,500–3,000 tok/s | 22–44 s | 35–55 tok/s |
| Qwen3.5 122B-A10B Q4 | 2,000–4,000 tok/s | 16–33 s | 60–90 tok/s |
| 200B–235B MoE Q4 | 800–1,800 tok/s | 36–82 s | 25–50 tok/s, architecture-dependent |
| 400B-class dense Q4 | 200–600 tok/s | 2–5.5 min | roughly 5–12 tok/s |

Existing anchors:

- M5 Max 128 GB reached 139 tok/s for Qwen3.5-35B-A3B 4-bit through MLX in a controlled cross-platform benchmark. [Benchmark](https://github.com/baem1n/llm-bench)
- M5 Pro 20-core reached 1,396–1,471 prompt tok/s and 33–34 tok/s generation at 64K for optimized Qwen3.8-27B 4-bit variants. [oQ4e benchmark](https://omlx.ai/benchmarks/performance/owwiv4qa) [AWQ benchmark](https://omlx.ai/benchmarks/performance/f26yejde)
- M3 Ultra 80-core measured 2,638–2,870 prompt tok/s and 84–88 tok/s generation at short context for Qwen3.5-35B-A3B 4-bit. At Q8 it measured 1,586 prompt tok/s and 45 tok/s generation at 64K. [Q4 benchmark](https://omlx.ai/benchmarks/7r0wyftl) [Q8 benchmark](https://omlx.ai/benchmarks/nz1tdg64)

## Capacity

A 512 GB M5 Ultra should hold:

- 27B/35B models at high precision with very large contexts and multiple slots.
- 70B dense models at BF16 or lower quantization.
- 122B models at BF16 or with substantial concurrency.
- 200B–235B models at Q8-class precision.
- 400B-class dense models at Q4 with runtime/context headroom.

Capacity does not guarantee responsiveness. A 400B dense Q4 model can fit while remaining slow because every generated token streams hundreds of gigabytes of weights.

## Deployment implications

Use MLX/oMLX, Core AI, or an MLX-backed LM Studio server. llama.cpp Metal may not exploit the GPU Neural Accelerators or both dies as effectively. Verify that the selected runtime uses both Ultra dies; poor dual-die scheduling can leave performance near one M5 Max rather than approaching two.

For this home-server environment, expose the Mac as a standalone OpenAI-compatible service over 10 GbE and route it through LiteLLM/Hermes. It is not a Talos/Kubernetes node and does not provide CUDA compatibility.

## Recommendation

For Qwen 27B/35B alone, an RTX 5090 should offer comparable or better measured responsiveness at a fraction of the price while retaining the existing CUDA/Talos path. The M5 Ultra becomes compelling when one quiet machine must combine strong interactive performance with 256–512 GB model capacity. Wait for independent 80-core oMLX results after 2026-09-22 before treating the estimates above as purchase-grade evidence.
