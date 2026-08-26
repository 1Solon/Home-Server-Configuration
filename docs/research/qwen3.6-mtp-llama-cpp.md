# Research: Qwen3.6 MTP through llama.cpp on kube5

**Date:** 2026-08-26  
**Scope:** `llama-server` deployment through the repository's existing LLMKube/CUDA stack. The initial text-only recommendation was updated to enable image input after the deployment decision changed.

## Decision

Use **`unsloth/Qwen3.6-35B-A3B-MTP-GGUF` at `UD-Q4_K_XL`** with `mmproj-F16.gguf`, 65,536 context, one slot, and enough MoE expert layers retained on CPU to preserve at least llama.cpp's default 1,024 MiB fit margin. It is a better hardware match than dense 27B: the 35B-A3B file is larger, but only 3B parameters are active and its expert tensors can be selectively kept in host RAM; dense 27B requires broad layer offload on this 16 GiB GPU. Treat this as a benchmark candidate, not a fit guarantee: MTP, the projector, and the full 65K allocation must be measured on kube5 before deployment.

## Exact artifacts

| Variant | Hugging Face identifier | Recommended artifact / `-hf` quant selector | Exact file size | Smaller fit probes |
|---|---|---|---:|---|
| Dense 27B MTP | `unsloth/Qwen3.6-27B-MTP-GGUF` | `Qwen3.6-27B-UD-Q4_K_XL.gguf` / `:UD-Q4_K_XL` | 17,909,097,600 B (16.68 GiB) | `UD-Q3_K_XL` 14,787,986,560 B; `UD-Q2_K_XL` 12,040,512,640 B |
| MoE 35B-A3B MTP | `unsloth/Qwen3.6-35B-A3B-MTP-GGUF` | `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` / `:UD-Q4_K_XL` | 22,853,663,008 B (21.28 GiB) | `UD-Q3_K_XL` 17,227,569,440 B; `UD-Q2_K_XL` 12,574,128,416 B |

These names and byte sizes come from the repositories' file APIs, not rounded model-card tables. Other published names include standard `Q3_K_*`, `Q4_K_*`, `Q5_K_*`, `Q6_K`, `Q8_0`, dynamic `UD-IQ*`/`UD-Q*_XL`, and, for 35B-A3B, `Qwen3.6-35B-A3B-MXFP4_MOE.gguf`. [27B repository/API](https://huggingface.co/api/models/unsloth/Qwen3.6-27B-MTP-GGUF/tree/main?recursive=true&expand=true) [35B-A3B repository/API](https://huggingface.co/api/models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main?recursive=true&expand=true)

The **MTP repository is required**; the similarly named non-MTP GGUF repositories omit the necessary head. Qwen MTP is embedded in the selected model GGUF, so there is no separate draft-model file or `--model-draft`. The selected repository is pinned at revision `5bc3e238d916f48a861bac2f8a1990a0e9b7e98d`; the model LFS/SHA-256 is `55983c5a75a1ab969824077b3bb3de4146e82a9234072b48ad4e8f92ad3fe9f1`, and the projector LFS/SHA-256 is `71f3cbc1f7cc0f30d09d41cfa924c0060827ebc33bf15ace7e86661e856f0160`. [Unsloth MTP guide](https://unsloth.ai/docs/models/mtp)

## Server command shape

For a direct llama.cpp smoke test:

```bash
llama-server \
  -hf unsloth/Qwen3.6-35B-A3B-MTP-GGUF:UD-Q4_K_XL \
  --ctx-size 65536 \
  --parallel 1 \
  --flash-attn on \
  --mmproj /path/to/mmproj-F16.gguf \
  --spec-type draft-mtp \
  --spec-draft-n-max 2
```

Required MTP switches are **`--spec-type draft-mtp --spec-draft-n-max 2`**. Unsloth identifies 2 as the best starting value but says to benchmark 1–6; upstream's server help currently defaults `--spec-draft-n-max` to 3, so set it explicitly. `--ctx-size 65536` (short `-c 65536`) configures exactly 65,536 tokens; this is within the model's native 262,144-token context and needs no RoPE/YaRN override. Keep `--parallel 1`: the model repository currently says `-np > 1` is not yet supported with MTP, while upstream calls parallel MTP supported but not fully optimized. [Unsloth Qwen3.6 guide](https://unsloth.ai/docs/models/qwen3.6) [llama.cpp server options](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) [MTP PR #22673](https://github.com/ggml-org/llama.cpp/pull/22673)

For thinking mode, Unsloth recommends temperature 1.0 (0.6 for precise coding), top-p 0.95, top-k 20, min-p 0, presence penalty 0, and repeat penalty 1. For non-thinking mode use temperature 0.7, top-p 0.8, top-k 20, min-p 0, presence penalty 1.5, repeat penalty 1, plus `--chat-template-kwargs '{"enable_thinking":false}'`. [Unsloth Qwen3.6 guide](https://unsloth.ai/docs/models/qwen3.6)

## Multimodal projector

Image input requires `mmproj-F16.gguf`; the 35B-A3B projector is 899,283,584 B with SHA-256 `71f3cbc1f7cc0f30d09d41cfa924c0060827ebc33bf15ace7e86661e856f0160`. LLMKube stages it through `Model.spec.mmproj` and passes its resolved path as `--mmproj`. The current Unsloth guide demonstrates Qwen3.6 MTP with this projector, while older model-card wording cautions about MTP plus `mmproj`; therefore image+MTP needs a live image-request test. [Unsloth Qwen3.6 guide](https://unsloth.ai/docs/models/qwen3.6) [MTP PR](https://github.com/ggml-org/llama.cpp/pull/22673) [35B-A3B repository API](https://huggingface.co/api/models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main?recursive=true&expand=true)

## kube5 memory implications

Repository research records kube5 as an **RTX 4060 Ti with 16,380 MiB VRAM, 8 vCPU and about 46 GB RAM**, with one physical GPU advertised as ten time-sliced resources. GPU memory is not isolated among GLM, Jellyfin, and Immich. The current GLM service already projects 14,544 MiB CUDA use at 131K context. [Repository hardware note](./llmkube-model-settings-for-kube5.md)

The following cache estimates are architectural lower bounds derived from the model cards' full-attention layer and KV-head counts. They exclude recurrent state/checkpoints, compute buffers, graph workspaces, allocator rounding, and model weights:

| Variant | Full-attention target layers | F16 K+V at 65,536 | Q8 K+V at 65,536 | Extra MTP-head F16 KV |
|---|---:|---:|---:|---:|
| 27B (4 KV heads × 256) | 16 | ~4.00 GiB | ~2.00 GiB | ~0.25 GiB |
| 35B-A3B (2 KV heads × 256) | 10 | ~1.25 GiB | ~0.625 GiB | ~0.125 GiB |

The MTP head has its own context/KV cache. Unsloth's two current pages give inconsistent generic headroom advice (~1 GB on the Qwen page and ~2 GB on the general MTP page); budget the conservative **2 GB** until kube5 startup logs provide exact allocations. Upstream measured an approximately 2.49 GiB MTP increase for 27B Q6 at 10K context on a 3090/3060 system, reinforcing that the generic estimate is not a guarantee. [Qwen guide](https://unsloth.ai/docs/models/qwen3.6) [MTP guide](https://unsloth.ai/docs/models/mtp) [upstream measurement](https://github.com/ggml-org/llama.cpp/pull/22673#issuecomment-)

Consequences:

- **High:** 27B `UD-Q4_K_XL` exceeds physical VRAM from weights alone; at 65K, even `UD-Q3_K_XL` plus q8 KV and MTP/compute headroom does not fit wholly on the 16 GiB GPU. `UD-Q2_K_XL` is also too close to the limit for a safe full-GPU load. Dense-layer CPU offload is therefore mandatory and likely decode-slow.
- **High:** 35B-A3B `UD-Q4_K_XL` also cannot be fully resident, but llama.cpp's `--n-cpu-moe`/`-ncmoe` can retain selected expert layers in host RAM, matching the repository's proven GLM deployment pattern. Its smaller 65K attention cache makes it the preferred candidate.
- **Critical operationally:** time slicing provides no VRAM isolation. An MTP service that fits alone can still OOM when Jellyfin or Immich starts GPU work. Benchmark with effective GPU exclusivity or accept this failure mode.
- **Medium:** q8 KV (`--cache-type-k q8_0 --cache-type-v q8_0`) roughly halves the tabled attention cache, but Unsloth warns that BF16 may be needed if output becomes gibberish. Validate long-context quality and tool calls before standardizing q8.

## Minimum/current llama.cpp support

Qwen3.5-family base architecture support landed in upstream PR [#19468](https://github.com/ggml-org/llama.cpp/pull/19468), but that alone is insufficient. Native Qwen3.6 MTP support was merged by [PR #22673](https://github.com/ggml-org/llama.cpp/pull/22673) on 2026-05-16 at merge commit **`255582687b8dd211fdbc582e43ab842491554e94`**. Use that commit or newer; Unsloth simply requires the latest llama.cpp.

The currently pinned CUDA image digest (`sha256:190d82...`) identifies llama.cpp **b10573 / `d775b8967a46d8beb110d444aa3b8938179e0dd8`**. Its OCI configuration reports CUDA **12.8.1**, avoiding Unsloth's CUDA 13.2 warning, and the server help at that exact source revision exposes `draft-mtp`; it meets the minimum. Image digest and model revision remain separate immutable inputs. [Pinned server help](https://github.com/ggml-org/llama.cpp/blob/d775b8967a46d8beb110d444aa3b8938179e0dd8/tools/server/README.md)

## Operational caveats and validation gate

1. MTP accelerates decode, but upstream reports slower prompt processing from device/host embedding transfers; long tool histories may erase the benefit. Benchmark end-to-end latency, not only generated tokens/s. [PR #22673](https://github.com/ggml-org/llama.cpp/pull/22673)
2. Start at draft max 2 and sweep 1–6 with representative coding, prose, and tool prompts. Acceptance and net speed are hardware/content dependent.
3. Use one parallel slot. MTP parallel decoding is not fully optimized, and Unsloth's current cards explicitly disallow `-np > 1`.
4. Image input uses `mmproj-F16.gguf`. Vision+MTP guidance has changed across Unsloth materials, so require a real image-request validation run in addition to text/tool tests.
5. Keep at least 1 GiB measured CUDA margin after full 65K prefill, then exercise concurrent Jellyfin/Immich activity if coexistence is intended.
6. Record model download revision/commit and file SHA-256 before deployment; `main` artifact contents can be refreshed.
7. Unsloth warns against CUDA 13.2 for Qwen3.6 gibberish (use an earlier version or 13.3+). Verify the pinned image's CUDA runtime.
8. Do not use rounded Unsloth memory tables as a 65K VRAM budget: they describe total RAM+VRAM/unified-memory requirements and do not isolate the long KV cache or kube5's shared-GPU contention.

## Sources

- Kept: [Official Unsloth Qwen3.6 guide](https://unsloth.ai/docs/models/qwen3.6) — identifiers, flags, sampling, context, memory advice, caveats.
- Kept: [Official Unsloth MTP guide](https://unsloth.ai/docs/models/mtp) — MTP packaging and tuning guidance.
- Kept: [Unsloth 27B MTP repository](https://huggingface.co/unsloth/Qwen3.6-27B-MTP-GGUF) and [tree API](https://huggingface.co/api/models/unsloth/Qwen3.6-27B-MTP-GGUF/tree/main?recursive=true&expand=true) — exact files, sizes, model architecture.
- Kept: [Unsloth 35B-A3B MTP repository](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF) and [tree API](https://huggingface.co/api/models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main?recursive=true&expand=true) — exact files, sizes, model architecture.
- Kept: [llama.cpp MTP PR #22673](https://github.com/ggml-org/llama.cpp/pull/22673) — merge floor, implementation design, flags, benchmarks and caveats.
- Kept: [llama.cpp server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) — current authoritative CLI behavior.
- Dropped: search summaries, community posts, third-party deployment guides and unofficial quants — excluded by the primary-source-only requirement.

## Gaps

No live kube5 MTP startup log or full-context benchmark was available in the repository, so exact CUDA/host allocations, required `moeCPULayers`, and net throughput remain unknown. Before manifests are changed, run an isolated canary that captures llama.cpp's projected buffers, full-65K prefill memory, draft acceptance, prompt/decode throughput, and tool-call correctness for 35B-A3B `UD-Q4_K_XL`; fall back to `UD-Q3_K_XL` only if CPU-MoE tuning cannot provide safe margin.
