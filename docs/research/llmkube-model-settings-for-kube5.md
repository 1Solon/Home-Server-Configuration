# Research: LLMKube model settings for kube5

**Date:** 2026-08-23  
**Scope:** `kubernetes/ai/llmkube/models/models.yaml`, LLMKube 0.9.19, the pinned llama.cpp image, kube5's live capacity, and the GPU-sharing configuration. Read-only cluster queries were used; no manifests or cluster resources were changed.

## Verdict

The manifest is **working and already well tuned for an exclusive 16 GiB GPU**. The selected model/quant, one slot, Flash Attention, q8 K cache, CPU expert offload, sampling, Jinja tool template, context policy, and immutable pins are all defensible. Contrary to a static size estimate, the exact 131,072-token configuration does fit: the running server reports 14,544 MiB projected CUDA use and leaves 1,275 MiB against llama.cpp's 1,024 MiB fit target.

It is **not the safest or best-defensible configuration for kube5 as configured**, for two reasons:

1. kube5 advertises ten time-sliced GPU replicas from one physical RTX 4060 Ti. GLM, Jellyfin, and Immich ML currently hold three shared GPU allocations. NVIDIA explicitly provides no GPU-memory or fault isolation for time slicing. GLM alone currently uses 14,764 MiB and leaves about 1,163 MiB, so another workload can make it fail.
2. LLMKube maps `cpu` and `memory` to Kubernetes **requests only**. The manifest reserves `500m` and `4Gi`, while the live server uses 8,623 MiB RAM, has 7,314 MiB of base host buffers, and may grow an additional prompt cache up to the 8,192 MiB default.

To reduce coexistence risk, use a **65,536-token shared-GPU baseline**, reduce the physical microbatch to 1,024, reserve materially more CPU/RAM, and cap the host prompt cache. Keep 131,072 only if GLM receives effective GPU exclusivity or if controlled concurrency testing proves that Jellyfin and Immich stay within the remaining VRAM.

## Verified kube5 and runtime facts

### Node and scheduling

Read-only observations on 2026-08-23:

- kube5: 8 vCPU, 7,950m allocatable CPU, 45,711,588 Ki allocatable RAM.
- Physical GPU: NVIDIA GeForce RTX 4060 Ti, 16,380 MiB reported VRAM.
- The NVIDIA device plugin advertises `nvidia.com/gpu: 10` because `kubernetes/infra/nvidia-device-plugin/nvidia-device-plugin/app/release.yaml` configures `timeSlicing.resources[].replicas: 10`.
- Three running kube5 pods request GPU access: GLM-4.7-Flash, Jellyfin, and Immich machine learning.
- Node requests before any proposed change: 2,731m CPU and 23,266 MiB RAM. A recommendation such as `cpu: "8"` or `hostMemory: 32Gi` would therefore make this pod unschedulable; resource recommendations must account for the rest of kube5.

NVIDIA's v0.20.0 device-plugin documentation says time-sliced replicas are shared accesses, not fractional GPUs: workloads retain access to all GPU memory, share one fault domain, and receive no memory isolation. It recommends treating a request of one as an access request rather than exclusivity. [NVIDIA device-plugin v0.20.0: shared access](https://github.com/NVIDIA/k8s-device-plugin/blob/v0.20.0/README.md#shared-access-to-gpus)

### Exact deployed software

- LLMKube chart `0.9.19` resolves to commit [`3eaab2c4deca641a069c16c4ec2e4d07673baf7c`](https://github.com/defilantech/LLMKube/tree/3eaab2c4deca641a069c16c4ec2e4d07673baf7c).
- OCI metadata for image digest `sha256:cf2e30...` identifies llama.cpp build `b10548`, commit [`a298422da78eb75e440a7de0ca408af64d323d93`](https://github.com/ggml-org/llama.cpp/tree/a298422da78eb75e440a7de0ca408af64d323d93). The live process prints the same build and commit.
- The live Pod arguments exactly match the operator's expected rendering, including `--n-gpu-layers 99`, `--ctx-size 131072`, `--parallel 1`, `--n-cpu-moe 21`, and all `extraArgs`.

LLMKube's pinned runtime builder performs these mappings directly and appends `extraArgs` last. [Runtime builder](https://github.com/defilantech/LLMKube/blob/3eaab2c4deca641a069c16c4ec2e4d07673baf7c/internal/controller/runtime_llamacpp.go#L80-L172) [Argument helpers](https://github.com/defilantech/LLMKube/blob/3eaab2c4deca641a069c16c4ec2e4d07673baf7c/internal/controller/runtime_llamacpp_args.go#L45-L166)

### Exact memory allocation

The pinned server's startup log provides the authoritative budget for this model and configuration:

| Allocation | MiB |
|---|---:|
| CUDA model buffer | 9,929.37 |
| CUDA q8 K cache, 131,072 cells × 47 layers | 3,595.52 |
| CUDA compute buffer (`ubatch=2048`) | 1,019.63 |
| **Projected CUDA total** | **14,544** |
| Initial CUDA free | 15,820 |
| **Projected free margin** | **1,275** |
| Host model buffer | 6,770.16 |
| Host compute buffer | 544.03 |
| **Base host buffers** | **7,314** |
| Current Pod RSS | 8,623 |

The server reports a 3,595.5 MiB **K-only** q8 cache and a 0 MiB V cache because this model uses MLA. `--cache-type-v q8_0` is therefore harmless but currently has no allocation effect. The exact pinned source sets `has_v = !is_mla`. [Pinned KV-cache source](https://github.com/ggml-org/llama.cpp/blob/a298422da78eb75e440a7de0ca408af64d323d93/src/llama-kv-cache.cpp#L185-L242)

The server also enables a host prompt cache with an 8,192 MiB default cap. The pinned help documents `--cache-ram N`, where 0 disables it. [Pinned server options](https://github.com/ggml-org/llama.cpp/blob/a298422da78eb75e440a7de0ca408af64d323d93/tools/server/README.md#common-params)

### Observed performance

Recent requests show approximately:

- 42 tokens/s generation on short context.
- 27–29 tokens/s at roughly 23k–29k cached context.
- Up to roughly 480 tokens/s prompt evaluation for a 2,980-token increment.

These are workload observations, not controlled A/B benchmarks. The history labels the latest `ubatch=2048` change as a benchmark, but the repository contains no result comparing it with `ubatch=1024` and two fewer CPU expert layers.

## Model and quantization

The pinned file is 17,520,169,312 bytes (16.32 GiB). Its metadata describes a 29.94B-parameter, 47-layer `deepseek2`/MLA model with a 202,752-token trained context. [Pinned Hugging Face revision API](https://huggingface.co/api/models/unsloth/GLM-4.7-Flash-GGUF/revision/0d32489ecb9db6d2a4fc93bd27ef01519f95474d) [Official model config](https://huggingface.co/zai-org/GLM-4.7-Flash/blob/main/config.json)

`UD-Q4_K_XL` remains the right quality/capacity choice. Unsloth's pinned model card recommends disabling repeat penalty, tool-use sampling of temperature 0.7 and top-p 1.0, and llama.cpp min-p 0.01. The manifest matches all four settings. [Pinned Unsloth model card](https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF/blob/0d32489ecb9db6d2a4fc93bd27ef01519f95474d/README.md)

## Field-by-field assessment

| Setting | Assessment | Recommendation |
|---|---|---|
| `UD-Q4_K_XL` | Correct | Keep. A higher quant would consume the headroom needed for context and shared-GPU safety. |
| GPU layers `-1` | Correct | Keep. LLMKube emits 99; CPU MoE overrides retain selected expert tensors in host RAM. |
| `moeCPULayers: 21` | Fits and leaves ~1.2 GiB | Keep for the shared-safe baseline. With exclusive GPU access, benchmark 20 then 19; preserve at least 1 GiB measured free VRAM. |
| `contextSize: 131072` | Proven to start and serve ~29k prompts, but leaves little shared-GPU headroom | Use 65,536 while time slicing remains. Keep 131,072 only with effective exclusivity and a full-context acceptance test. |
| `parallelSlots: 1` | Correct | Keep. More slots divide context and increase concurrency pressure. |
| Flash Attention | Correct | Keep. |
| CPU request `500m` | Materially under-reserved | Use `cpu: "4"`. It fits current node reservations and matches the server's current four generation threads while still permitting bursts. |
| Memory request `4Gi` | Below actual 8.6 GiB RSS | Use `hostMemory: 18Gi` if retaining a 4 GiB prompt-cache cap. LLMKube defines this field for hybrid CPU/GPU offload. |
| GPU request `1` | Required but not exclusive under time slicing | Keep, but do not interpret it as one physical GPU. Fixing exclusivity is outside `models.yaml`. |
| `--no-mmap` | Works, but is deprecated | Replace with `--load-mode mmap` (or omit it for auto). The pinned server explicitly warns that `--no-mmap` is deprecated. Benchmark storage behavior after the change. |
| `batch-size: 8192` | Logical batch; current long-prompt workload can use it | Keep initially. Benchmark 4,096 versus 8,192; do not change it together with ubatch. |
| `ubatch-size: 2048` | Costs 1,019 MiB compute buffer and coincided with moving two more expert layers to CPU | Use 1,024 for the shared-safe baseline. Benchmark 512/1,024/2,048 independently. |
| `threads-batch: 8` | Matches kube5's 8 vCPUs | Keep. |
| Generation threads | Server defaults to 4 of 8 | Benchmark `--threads 6` and `8`; CPU-offloaded MoE may benefit, but memory bandwidth can make eight slower. Do not claim a winner without measurement. |
| q8 K cache | Correct quality/capacity balance | Keep. Prefer the typed `cacheTypeK` field. |
| q8 V cache | No-op for this MLA model | Remove for clarity, or keep as harmless future-proofing. |
| Jinja | Required for tools and currently effective | Keep; prefer typed `jinja: true`. The GGUF embeds the tool-aware template. |
| Sampling flags | Match publisher's tool profile | Keep as defaults; clients may override per request for general chat. |
| `reasoning-format: deepseek` | Correct API shaping | Keep. It moves thoughts into `reasoning_content`; it does not itself toggle thinking. |
| `--no-context-shift` | Correct safety policy | Keep. Silently dropping early system/tool instructions is undesirable. |
| Prompt cache default 8 GiB | Useful for Hermes' repeated long prefix, but unreserved and large | Cap at 4,096 MiB, then compare 0/2,048/4,096 using real conversations. |
| Startup probe 90 minutes | Excessive after init-container download; cached model load is ~6 seconds | Reduce to the operator's 30-minute envelope (`failureThreshold: 180`). |
| Verbosity 4 | Helpful for tuning, noisy for steady state | Use 3 after benchmarking is complete. |
| Model and image pins | Correct | Keep both immutable pins. |

Kubernetes permits use above a request when capacity is available; requests primarily drive scheduling, while limits are enforced separately. LLMKube 0.9.19 creates CPU/memory requests but no CPU/memory limits. [LLMKube deployment builder](https://github.com/defilantech/LLMKube/blob/3eaab2c4deca641a069c16c4ec2e4d07673baf7c/internal/controller/deployment_builder.go#L695-L739) [Kubernetes resource semantics](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits)

## Recommended shared-GPU baseline

This diff reduces collision risk with Jellyfin and Immich while preserving model quality and most prompt throughput; time slicing still cannot guarantee isolation. It is a baseline for measurement, not a claim that 1,024 is universally optimal.

```diff
@@
-  contextSize: 131072
+  contextSize: 65536
   parallelSlots: 1
   flashAttention: true
+  jinja: true
+  cacheTypeK: q8_0
   moeCPULayers: 21
+  batchSize: 8192
+  uBatchSize: 1024
@@
   resources:
-    cpu: 500m
-    memory: 4Gi
+    cpu: "4"
+    hostMemory: 18Gi
     gpu: 1
@@
-      failureThreshold: 540
+      failureThreshold: 180
@@
     - --verbosity
-    - "4"
-    - --jinja
+    - "3"
     - --reasoning-format
     - deepseek
-    - --no-mmap
-    - --batch-size
-    - "8192"
-    - --ubatch-size
-    - "2048"
+    - --load-mode
+    - mmap
     - --threads-batch
     - "8"
-    - --cache-type-k
-    - q8_0
-    - --cache-type-v
-    - q8_0
+    - --cache-ram
+    - "4096"
```

All omitted fields remain unchanged. Do not add `--threads 8` to the baseline until the 4/6/8-thread A/B test is run.

### If 131,072 is mandatory

The current manifest can remain as the high-context profile because it demonstrably fits when GLM is the only active GPU process. Before calling it production-safe:

1. Ensure Jellyfin and Immich cannot begin GPU work concurrently, or introduce orchestration/scale-to-zero outside this manifest.
2. Prefill and generate beyond 65k with representative tool-bearing input.
3. Record GPU use after full prefill, not just startup; require at least 1 GiB free.
4. Compare `ubatch` 1,024 versus 2,048. The smaller value may permit `moeCPULayers: 19`, which could improve decode speed at the expense of prompt throughput.
5. Exercise malformed/repeated tool-call detection and long-context answer retrieval.

## Priorities

1. **Critical outside this file:** treat the GPU as shared and unisolated; the current 1.16 GiB free margin is not a concurrency guarantee.
2. **High:** replace the inaccurate `500m`/`4Gi` requests with approximately 4 CPU and 18 GiB host memory.
3. **High for shared operation:** reduce context to 65,536 and ubatch to 1,024.
4. **Medium:** cap prompt cache, migrate from deprecated `--no-mmap`, and use typed LLMKube fields.
5. **Benchmark:** generation threads, ubatch, batch, and CPU-MoE layer count must be tuned independently.

## Evidence gaps

- No controlled 4/6/8-thread or 512/1,024/2,048-ubatch benchmark exists for kube5.
- Live traffic reached about 29k context during this review, not the full 131k allocation.
- Jellyfin and Immich were allocated shared GPU access but had no active GPU process during the sample; their peak VRAM demand was not measured.
- PCIe width/speed and VM CPU pinning/NUMA placement were not established.
