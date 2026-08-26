# Research: Local LLM ceiling on Minisforum MS-S1 Max

**Date:** 2026-09-03  
**Target:** general-assistant quality with interactive decode speed (about 15 tok/s or better)

## Hardware envelope

The linked 128 GB MS-S1 Max uses AMD's Ryzen AI Max+ 395 (16 Zen 5 cores / 32 threads), Radeon 8060S (40 CUs), and soldered LPDDR5X-8000 unified memory. The platform has a 256-bit memory interface (about 256 GB/s theoretical; about 239 GB/s measured on another Max+ 395 system), and AMD permits up to 96 GB to be assigned as graphics memory. Minisforum advertises up to 128 GB memory and performance modes reaching roughly 130 W sustained. [Minisforum product](https://minisforumpc.eu/products/minisforum-ms-s1-max-mini-pc) [AMD specifications](https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html) [Strix Halo Qwen3.8 test hardware](https://github.com/yandaq/qwen3.8-27b-strix-halo)

The important property for inference is capacity, not NPU TOPS: llama.cpp inference uses the Radeon GPU/CPU and unified memory bandwidth rather than the advertised NPU figure.

## Best quality model that fits interactively

**Qwen3.8-Flash-Next `UD-IQ4_XS` is the leading candidate.** It has 125B main parameters with 6B active, plus 51B n-gram embeddings and a 4B MTP head. Qwen reports stronger general-assistant results than Qwen3.8-27B: IFBench 81.3 vs 79.5, GPQA Diamond 91.7 vs 89.2, HLE 35.9 vs 30.8, CoWorkBench 73.9 vs 70.7, and JobBench 55.7 vs 33.4. These are Qwen-run high-precision evaluations, not independent GGUF-quantized tests. [Official model card](https://huggingface.co/Qwen/Qwen3.8-Flash-Next)

The Unsloth GGUF files total approximately:

| Quant | File size | Fit assessment in 128 GB unified memory |
|---|---:|---|
| `UD-IQ1_S` | 72.55 GB / 67.56 GiB | Easy, but severe quantization |
| `UD-IQ1_M` | 74.54 GB / 69.42 GiB | Easy, but severe quantization |
| `UD-Q2_K_XL` | 78.87 GB / 73.46 GiB | Easy, lower quality |
| `UD-IQ3_XXS` | 81.96 GB / 76.33 GiB | Easy |
| `UD-IQ4_XS` | 93.68 GB / 87.25 GiB | **Preferred quality/capacity balance** |
| `UD-Q3_K_XL` | 89.99 GB / 83.81 GiB | Alternative |
| `UD-Q4_K_XL` | 111.33 GB / 103.69 GiB | Fits weights, but leaves much less room for OS, runtime, vision/MTP and long context |

Exact sizes come from the [Hugging Face repository API](https://huggingface.co/api/models/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main?recursive=true&expand=true). Unsloth currently requires its experimental llama.cpp PR #27742 or Unsloth Desktop; upstream support is not yet mature. [Unsloth repository](https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF) [llama.cpp PR #27742](https://github.com/ggml-org/llama.cpp/pull/27742)

## Measured/indicative speeds

Early community Strix Halo tests of Flash-Next `UD-IQ4_XS`, using Vulkan/RADV and experimental llama.cpp support, report roughly **20–23 decode tok/s** and **291–390 prompt/prefill tok/s** at shallow context. One report measured about **19.4 tok/s decode at 16K context**. These are preliminary, single-user results rather than stable upstream benchmarks. [Strix Halo report](https://www.reddit.com/r/StrixHalo/comments/1vz5yb3/qwen38flashnext_125ba6b_running_on_strix_halo/)

More mature Max+ 395 measurements establish the broader platform envelope:

| Model | Quant | Prompt processing | Decode | Notes |
|---|---|---:|---:|---|
| Qwen3 30B-A3B | Q4_K_M | 1,142 tok/s | 86.1 tok/s | Vulkan/RADV, short pp512/tg128 |
| GPT-OSS 120B | Q4_K_M | 120 tok/s | 53.4 tok/s | llama-server measurement |
| MiniMax M2.5 229B-A10B | Q3_K_M | 156 tok/s | 32.8 tok/s | Fits near the capacity ceiling |
| Qwen3-235B-A22B | Q3_K_M | 101 tok/s | 17.2 tok/s | Interactive but slower |
| Llama 3.1 70B dense | Q4_K_M | 81.6 tok/s | 5.1 tok/s | Dense weights are bandwidth-bound |

Source: [visorcraft/strix-halo-llm-perf](https://github.com/visorcraft/strix-halo-llm-perf).

Prompt throughput is highly context-dependent. A Qwen3 30B-A3B Q4 benchmark drops from about 755 pp / 85 tg at shallow context to 17 pp / 12.5 tg at a 130,560-token context depth under Vulkan/RADV. Tuned ROCm improves deep-context prefill to about 51 tok/s but decode remains about 13.3 tok/s. [Strix Halo llama.cpp measurements](https://strixhalo.wiki/AI/llamacpp-performance)

Qwen3.8-27B offers a mature fallback. On Max+ 395, Q4_K_M/UD-Q4_K_XL with Vulkan and MTP measures about **26 tok/s average decode**; tuned full-context serving reports roughly **260–390 tok/s shallow prefill**, **20–26 tok/s short decode**, and **12–13 tok/s sustained long generations**. [Qwen3.8 quant comparison](https://github.com/yandaq/qwen3.8-27b-strix-halo) [full-context tuning](https://github.com/KyaniteLabs/qwen38-27b-strix-halo)

## Recommendation

1. Use Linux and the 128 GB configuration; allocate a large GTT/UMA aperture and use the highest sustainable power mode.
2. Start with **Qwen3.8-Flash-Next `UD-IQ4_XS`**, Vulkan/RADV, one slot, and 32K–64K context. Expect approximately **20–23 tok/s decode** and **300–390 tok/s shallow prompt processing**, falling as context fills.
3. Treat 128K as a benchmark target, not a promise. Full 262K context needs live memory and prefill testing; the model's native context specification does not imply acceptable full-context latency.
4. Keep **Qwen3.8-27B `UD-Q4_K_XL` + MTP** as the mature fallback at roughly **20–26 tok/s** with stronger software support.
5. Do not choose dense 70B for interactive use on this APU; despite fitting easily, measured decode can be only about 5 tok/s. Large sparse/MoE models make much better use of the memory capacity.

## Confidence and limitations

- **High confidence:** hardware capacity, GGUF file sizes, model architecture, and Qwen's published quality scores.
- **Medium confidence:** Qwen3.8-27B and established Strix Halo speed ranges.
- **Low-to-medium confidence:** Flash-Next speed, because llama.cpp support and the available benchmarks are experimental and very recent.
- No MS-S1 Max-specific Flash-Next benchmark was found; results come from equivalent Ryzen AI Max+ 395 / Radeon 8060S / 128 GB systems. Cooling and power limits can shift results.
