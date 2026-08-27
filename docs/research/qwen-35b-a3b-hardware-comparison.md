# Qwen 35B-A3B hardware comparison

**Date:** 2026-09-14  
**Scope:** kube5 versus a 64 GB M5 Pro MacBook Pro, the 128 GB BOSGAME M5 AI, and the 128 GB ASUS Ascent GX10/DGX Spark-class GB10 appliance. Cross-platform benchmark data is for Qwen3.5-35B-A3B; kube5's controlled measurements are for the closely related, currently deployed Qwen3.6-35B-A3B-MTP, so the comparison is directional rather than perfectly apples-to-apples.

## Verdict

- **Keep kube5** if this model's current speed is acceptable. It costs nothing more, is already integrated with LLMKube/Kubernetes, and sustains about 40 tok/s at a 44.8K prompt or 26.5 tok/s at a 119K prompt. Its weaknesses are CPU expert offload, nearly exhausted VRAM at 131K, and unisolated sharing with Jellyfin and Immich.
- **Choose the M5 Pro 64 GB** for the best single-user Qwen 35B-A3B latency and the lowest-friction local experience. A public oMLX result measured 95.8 tok/s at 4K and 64.4 tok/s at 32K. It is, however, a costly laptop rather than a natural Kubernetes server, and 64 GB limits future model growth.
- **Choose the BOSGAME 128 GB** for the lowest-cost dedicated 128 GB Linux AI appliance. Controlled llama.cpp testing of the same Ryzen AI Max+ 395 measured 58.4 tok/s for Qwen3.5-35B-A3B Q4_K_M. Its memory supports model classes that do not fit the Mac or kube5, but ROCm/kernel/Talos integration is less mature than the current CUDA deployment.
- **Choose the ASUS Ascent GX10** when the NVIDIA CUDA software ecosystem, 10/200 GbE networking, three-year PCSpecialist warranty, or development/fine-tuning workloads justify its premium. For Qwen 35B alone it is not materially faster than the BOSGAME: controlled llama.cpp testing measured 59.6–61.2 tok/s at Q4. Its advantage is software compatibility and multi-system scaling, not batch-one token generation.

## Comparison

| | Current kube5 | M5 Pro Mac | BOSGAME M5 AI | ASUS Ascent GX10 |
|---|---|---|---|---|
| Compute | RTX 4060 Ti 16 GB | M5 Pro, 20-core GPU | Ryzen AI Max+ 395, Radeon 8060S 40 CU | NVIDIA GB10 Grace Blackwell, 6,144 CUDA cores |
| Memory | 16 GB VRAM + ~46 GB host RAM, split over PCIe | 64 GB unified, 307 GB/s | 128 GB LPDDR5X unified, ~256 GB/s | 128 GB coherent LPDDR5X, 273 GB/s |
| Generation evidence | Qwen3.6 UD-Q4_K_XL + MTP: 39.7 tok/s at 44.8K; 26.5 tok/s at 119K | Qwen3.5 4-bit oMLX: 95.8 tok/s at 4K; 64.4 tok/s at 32K | Qwen3.5 Q4_K_M llama.cpp: 58.4 tok/s short generation | Qwen3.5 Q4_K_M llama.cpp: 59.6–61.2 tok/s; Q4_K_XL community run: 51 tok/s |
| Prefill evidence | 1,607 tok/s at 44.8K; 1,254 tok/s at 119K | 1,986 at 4K; 2,032 at 16K; 1,730 at 32K | 924 at 4K; 960 at 16K; 767 at 64K; 582 at 128K | 1,949 at 4K; 1,696 at 16K; 1,180 at 64K; 856 at 128K |
| Context/headroom | 131K proven but only 165 MiB GPU free | Q4 likely has ample 128K headroom; 262K needs validation | Ample 128K/262K headroom at Q4/Q8 | Ample 128K/262K headroom at Q4/Q8; 122B Q4 proven |
| Quant choices | Q4 is the practical quality tier | Q4 and Q8 are practical | Q4, Q8, and potentially BF16 are practical | Q4, Q8, and potentially BF16 are practical |
| Serving fit | Best: already deployed through LLMKube/CUDA | Best as standalone macOS oMLX service | Best as standalone Linux llama.cpp/ROCm service | Best as standalone DGX OS CUDA server; broadest AI framework support |
| Purchase price | $0 incremental | $3,699 (14-inch, 64 GB/1 TB, US Apple Store) | $2,999 (128 GB/2 TB, US BOSGAME listing) | About €4,360 incl. VAT/delivery from PCSpecialist search listing; confirm quote |
| Main risk | CPU offload and shared-VRAM OOM | Price, 64 GB ceiling, not a cluster node | ROCm/kernel integration and one-year vendor warranty | High price, ARM64 compatibility edges, only BOSGAME-class 35B speed |

## Evidence and implications

The official Qwen3.5 card identifies 35B total parameters, 3B activated per token, 262,144 native context, and recommends retaining at least 128K context for complex reasoning. This MoE shape is why all three systems can generate quickly despite loading roughly 20+ GB of 4-bit weights. [Official Qwen model card](https://huggingface.co/Qwen/Qwen3.5-35B-A3B/blob/main/README.md)

The current repository deploys `unsloth/Qwen3.6-35B-A3B-MTP-GGUF` at `UD-Q4_K_XL`, 131,072 context, q8 KV, one slot, and 20 CPU MoE layers. The controlled tuning record measured 1,607 prompt tok/s and 39.71 decode tok/s at a 44,812-token prompt. At a 119,012-token prompt it measured 1,253.55 prompt tok/s and 26.46 decode tok/s, while GPU use reached 15,786 MiB with only 165 MiB free. [Repository deployment](../../kubernetes/ai/llmkube/models/models.yaml) and [controlled benchmark](./qwen3.6-mtp-llama-cpp.md)

The 64 GB M5 Pro has a 20-core GPU and 307 GB/s memory bandwidth. A submitted oMLX benchmark for Qwen3.5-35B-A3B 4-bit measured 103.1 tok/s at 1K, 95.8 at 4K, 81.6 at 16K, and 64.4 at 32K, with 22.5 GB peak memory at 32K. These are not independently reproduced results, but they are the closest exact-chip/model measurements found. [Apple specifications](https://support.apple.com/en-us/126319) and [oMLX benchmark](https://omlx.ai/benchmarks/s91yidg5)

The BOSGAME listing specifies Ryzen AI Max+ 395, Radeon 8060S, 128 GB LPDDR5X-8000 shared memory, 2 TB SSD, dual M.2 slots, 2.5 GbE, and a one-year warranty. The official page currently lists the 128 GB US variant at $2,999. Its “126 TOPS” and “2.2× RTX 4090” claims are not useful predictors for this workload: current llama.cpp serving uses the GPU and memory subsystem, not the NPU TOPS headline. [BOSGAME product page](https://www.bosgame.com/products/bosgame-m5-ai-mini-desktop-ryzen-ai-max-395-96gb-128gb-2tb)

A controlled community suite using the same llama.cpp build, GGUF, and settings across platforms measured the Ryzen AI Max+ 395 at 58.0 tok/s for Q4_K_M and 50.8 tok/s for Q8_0. It also ran Qwen3.5-122B-A10B Q4 at 22.9 tok/s, demonstrating the main benefit of the 128 GB machine: capacity rather than class-leading 35B speed. [Benchmark methodology and results](https://github.com/baem1n/llm-bench)

AMD now publishes ROCm 7.2.1 llama.cpp binaries for gfx115x APUs and documents full GPU offload and Flash Attention. That materially improves viability, but the documented path assumes a supported Ubuntu/kernel stack. The repository's existing Talos/NVIDIA/LLMKube path is therefore not a drop-in fit; a standalone Ubuntu service would be the lower-risk deployment. [AMD llama.cpp guide](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/advanced/advancedryz/linux/llm/llamacpp.html)

The ASUS Ascent GX10 is an OEM DGX Spark-class system using the GB10 Grace Blackwell Superchip: 20-core Arm CPU, Blackwell GPU, 128 GB coherent memory at 273 GB/s, 140 W SoC TDP, 240 W supply, 10 GbE, and ConnectX-7. NVIDIA documents native CUDA/PyTorch/TensorRT-LLM/NIM support and up to 200B-parameter local inference. The “1 PFLOP FP4” headline is peak sparse tensor compute, not batch-one LLM speed; Qwen 35B decode remains constrained by its 273 GB/s memory subsystem. [NVIDIA hardware guide](https://docs.nvidia.com/dgx/dgx-spark/hardware.html) [ASUS specifications](https://www.asus.com/networking-iot-servers/desktop-ai-supercomputer/ultra-small-ai-supercomputers/asus-ascent-gx10/techspec/)

In the controlled cross-platform suite, the GB10 produced 59.6 tok/s for Qwen3.5-35B-A3B Q4_K_M and 52.6 tok/s at Q8_0—effectively tied with Ryzen AI Max+ 395 at 58.0 and 50.8 tok/s. It did better on 128K Q4 prompt ingestion (856 versus 582 tok/s). A separate 128K Q4_K_XL llama.cpp deployment reported about 51 tok/s generation. This makes GB10 the better development platform, but not a better-value Qwen 35B inference box. [Controlled benchmark](https://github.com/baem1n/llm-bench) [128K deployment report](https://forums.developer.nvidia.com/t/implementation-guide-dgx-spark-with-qwen3-5-35b-a3b-via-llama-cpp-for-claude-code/365382)

The ConnectX-7 ports matter only with another compatible system and suitable 200 GbE cabling/networking. A single GX10 does not gain inference speed from them. Likewise, its CUDA compatibility is substantially better than ROCm for experimentation, but it would still be simplest to expose it as a standalone OpenAI-compatible service rather than trying to make DGX OS a Talos node.

## Recommendation for this home-server setup

For **only Qwen 35B-A3B**, retain kube5 unless 26–40 tok/s is causing a real usability problem. If buying a second system:

1. **M5 Pro 64 GB** when Qwen 35B responsiveness, silence, portability, and easy oMLX serving matter most.
2. **BOSGAME 128 GB** when value, an always-on dedicated server, or future 70B/122B-class models matter most.
3. **ASUS Ascent GX10** only when CUDA/NVIDIA framework support, fine-tuning/development, 10/200 GbE, warranty, or a future second GB10 system is worth roughly the €1,000+ premium over a 128 GB Ryzen AI Max appliance.
4. Do not buy either appliance based on NPU/TOPS/PFLOPS marketing; for batch-one Qwen generation, measured runtime performance and memory bandwidth matter more.

Before replacing kube5, run the same pinned Qwen3.6 GGUF and representative 32K/128K Hermes prompts on the candidate. Existing public numbers do not hold model revision, MTP, quant, context, and runtime constant across all three systems.
