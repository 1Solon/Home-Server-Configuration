# Research: Qwen3.8-Flash-Next on DGX Spark

**Date:** 2026-08-30
**Scope:** Public benchmark evidence for the local Qwen3.8-Flash-Next model on one or two NVIDIA DGX Spark systems. Results are separated by engine, quantization, workload, and concurrency; they are not treated as a single apples-to-apples benchmark.

## Verdict

- The phrase **"Qwen 3.8 Flash"** most precisely resolves to the local checkpoint **`Qwen/Qwen3.8-Flash-Next`**. **`qwen3.8-flash`** is Qwen Cloud's hosted service based on that model. `Qwen3-8B`, `qwen3.5-flash`, and `qwen3-coder-flash` are different model names.
- A single GB10 system has credible community measurements of about **32 tok/s for free-form prose**, **33-42 tok/s for coding tasks**, and **2,030-2,460 prompt tok/s** with the vLLM NVFP4/MTP recipe. The vLLM measurements used an ASUS Ascent GX10, which has the same GB10 and memory subsystem but is not literally NVIDIA-branded DGX Spark hardware. A separate SGLang recipe on an actual DGX Spark reports **41.5 tok/s on a code workload**.
- The strongest public 2x Spark measurements now include **64.4 tok/s single-stream and 116.8 tok/s aggregate at two streams**, **48.1 prose / 63.8 code tok/s single-stream with 126.1 / 159.9 aggregate at eight streams**, **about 70 tok/s peak** on a different MTP4/CUDA-graph configuration, and uncached client-observed prefill of **2,327.78 / 2,758.65 / 2,960.12 input tok/s** at 1K / 4K / 16K prompts. A separate vLLM recipe reports **55.8 tok/s fresh single-stream decode and 126.1 aggregate at eight streams**, with a warmed counter-based reading of 63 and 203 tok/s. These are community measurements, not an official NVIDIA or Qwen benchmark and not directly comparable to one another.
- Two Sparks help a single request only when tensor parallelism is enabled. With data-parallel replicas, two systems increase aggregate service capacity but do not make one request faster. Tensor parallelism also adds dependence on the ConnectX-7 link and multi-node software stability.
- For a purchase or production decision, treat **roughly 50-70 tok/s single-stream on 2x Spark as an observed community range, not a guaranteed specification**. No trustworthy matched benchmark was found that holds model artifact, runtime, prompts, context, MTP settings, and correctness validation constant across one and two systems.
- Hermes field reports do **not** establish a universal quality winner. They favor DeepSeek-V4-Flash as the more mature and dependable daily agent, while one later Qwen report found it at least as useful and possibly better for some agent tasks. The reports mix hardware counts and fast-changing runtimes, so this is operational evidence rather than a controlled model comparison.

## Model Resolution

| User-facing name | Exact identifier | Meaning |
|---|---|---|
| Qwen 3.8 Flash, local | `Qwen/Qwen3.8-Flash-Next` | Official open-weight Transformers checkpoint |
| Qwen 3.8 Flash, hosted | `qwen3.8-flash` | Qwen Cloud service based on Qwen3.8-Flash-Next; 1M-token service context |
| Qwen 3.8 Flash NVFP4 | `RadixArk/Qwen3.8-Flash-Next-NVFP4` | Community-published local quantization used by the SGLang Spark recipes |
| Qwen 3.8 Flash GGUF | Qwen3.8-Flash-Next GGUF variants | Community conversions used by llama.cpp recipes |

The official model card describes a 125B language model with 6B activated parameters, a 51B n-gram embedding table, and a 4B MTP component. It has 48 layers and a native 262,144-token context; local frameworks can apply YaRN for longer contexts. The hosted service advertises a 1M-token context, which should not be confused with the open-weight model's native window.

The large n-gram/PLE table is a major part of the hardware problem. Community measurements describe approximately 126 GiB for a single NVFP4 checkpoint against approximately 121.63 GiB usable on a Spark. The recipes therefore rely on engine-specific memory handling, such as mmap-backed storage or pinned/offloaded tables, rather than simply loading every tensor as an ordinary resident allocation.

## DGX Spark Hardware

NVIDIA documents each DGX Spark as a GB10 Grace Blackwell system with:

| Property | Official value |
|---|---:|
| Unified memory | 128 GB LPDDR5x |
| Memory bandwidth | 273 GB/s |
| GPU | Blackwell, 6,144 CUDA cores listed in the user guide |
| GB10 TDP | 140 W |
| Included power supply | 240 W |
| External cluster link | ConnectX-7, up to 200 Gb/s per QSFP port |
| Native context target in the model | 262,144 tokens |

Two-Spark tensor parallel serving uses a direct ConnectX-7 link in the published recipes. NVIDIA's clustering documentation confirms that multiple Sparks can be connected to run workloads that do not fit on one device, but it does not publish Qwen3.8-Flash-Next throughput.

The 140 W figure is a platform specification, not measured power during these benchmarks. The benchmark repositories did not report watts, total system draw, or energy per generated token.

## Published Measurements

| Systems | Engine and artifact | Workload | Decode | Prompt / TTFT | Concurrency | Context | Confidence |
|---|---|---|---:|---|---|---|---|
| 1x GB10 (ASUS GX10) | vLLM, NVFP4, MTP=3 | Free prose | **32.2 tok/s** | **2,183-2,463 tok/s** to 195k; short TTFT about 0.3 s | 16 requests: 96-109 aggregate tok/s; TTFT under 2.7 s | 262k | Medium-high community measurement; hardware-equivalent, not DGX-branded |
| 1x GB10 (ASUS GX10) | vLLM, NVFP4, MTP=3 | Coding tasks | 33.6-39.1 tok/s | Same prefill result | Same | 262k | Medium-high community measurement; hardware-equivalent, not DGX-branded |
| 1x GB10 (ASUS GX10) | llama.cpp, Q4_K_XL with n-gram drafting | File reproduction, bug fix, new function, prose | 88.5, 46.1, 32.2, 27.8 tok/s respectively | Cold llama.cpp prefill about 486 tok/s at 10k, 448 at 40k, 253 at 161k | One slot | 262k | Medium; highly task-dependent and hardware-equivalent |
| 1x Spark | SGLang, NVFP4, NEXTN speculative decoding | Code | **41.5 tok/s**, range 40.3-42.3 | 8k prompt TTFT 12.1 s; 128k 144.3 s; 240k 331.9 s | One request in long-context test | 262k | Medium; separate recipe and task |
| 2x Spark | SGLang TP2, NVFP4, NEXTN 3/1/4, patched SM121 image | Structural serving / mixed concurrency | **64.4 tok/s** | 117 ms TTFT | C2: **116.8 aggregate**; C4: **114.1 aggregate** | 1M YaRN; single-prompt retrieval reliable through 128K | Medium; detailed recipe and live-cluster measurements, but no independently verified host receipt |
| 2x Spark | SGLang TP2, NVFP4, MTP4, CUDA graphs | Code/structured peak and mixed prompts | **69.7-70.2 peak**, about 47 typical mixed | Warmed TTFT about 0.2 s | Not a comparable concurrency sweep | 262k native; larger pool reported | Low-medium; different recipe and peak-oriented result |
| 2x Spark | SGLang TP2, NVFP4, NEXTN 3/1/4, patched SM121 image | Prose / code | **48.1 / 63.8 tok/s** | 0.166-0.172 s | C4: 119.7 / 163.0; C8: **126.1 / 159.9 aggregate** | 262k | Medium-high; named pair, raw battery and sweep reports, recipe derives from the day-0 lineage |
| 2x Spark | SGLang TP2, NVFP4, NEXTN/MTP profile | Coding | **47.54 tok/s** | Not reported as a separate TTFT measurement | C4: 87.55; C8: **158.17**; C16: **275.37 aggregate** | 262k | Medium-high; pinned model/image, direct rank-zero API timing, zero restarts after validation |
| 2x Spark | SGLang TP2, NVFP4, NEXTN/MTP profile | Uncached prefill | N/A | 1K: **2,327.78** (0.4524 s); 4K: **2,758.65** (1.4924 s); 16K: **2,960.12** (5.5729 s) input tok/s | One request at a time; one output token | 262k | Medium-high; pinned model/image revisions, unique prefixes, three-run medians, and server-side cache-zero reports |
| 2x Spark | vLLM TP2+EP, NVFP4, MTP3, official day-0 image plus PLE resolver patch | Code/reasoning/math/C# / prose | **55.8 tok/s fresh median**, 63 warmed counter reading | 0.26-0.31 s fresh; 221 ms warmed | C8: **126.1 fresh**, **203 warmed counter reading** | 262k | Medium; detailed launcher and methodology, but warmed and fresh metrics use different methods |
| 2x Spark | SGLang TP2, NEXTN, custom SM121 QSA kernel | Prose / code | **41.7 / 49.8 tok/s** | Not consistently reported | **149.5 aggregate at C8** | 262k; YaRN 524k degraded above about 50k | Low-medium; named recipe and own kernel, but its TRT-LLM gate bypass conflicts with later long-context corruption findings |
| 2x Spark | SGLang TP2, custom SM121 repair, ReplaySSM exact-fold | Prose / coding-agent traffic | **47.33 tok/s** | Mean 0.204 s | C4: **155.60**; C6: **210.25 aggregate** | 262k | Medium; extensive stability narrative, but current candidate remains open after prior real-workload crashes |

### How to Read the Numbers

- The 88.5 tok/s llama.cpp result is for reproducing a file with one change, not general generation. The same setup measured 27.8 tok/s for free-form prose. The source explicitly warns that a single unlabeled tok/s number is not meaningful for this model.
- The 41.5 tok/s SGLang result is a code result. Its prose result was 22.8 tok/s. It should not be used as a general single-request average.
- The vLLM recipe is the most balanced published one-Spark result: prose stays near 32 tok/s, decode remains approximately flat from 1k to 128k context, and prefill stays roughly in the 2,030-2,460 tok/s range across independent harnesses.
- The two-Spark 64.4 tok/s and 69.7-70.2 tok/s results use different kernels, MTP settings, CUDA graph settings, memory policies, and prompt shapes. Their agreement establishes a useful performance band, not a controlled comparison.
- PixelML's two-Spark prefill ladder is the strongest uncached prefill evidence found: it uses unique randomized prefixes, exactly one output token, three measured runs per target, and reports `#cached-token: 0` for all 50 server-side batches. Its input tok/s is end-to-end client-observed TTFT throughput, not continuous batched prefill capacity.
- PixelML's 47.54 C1 and 275.37 C16 decode figures use identical 192-token coding requests. The C16 number is useful short-output aggregate stress evidence, but should not be compared directly with longer mixed-agent concurrency tests or used as a sustained service-planning rate.
- Chishiki37's battery is the cleanest additional apples-to-apples two-Spark result: the same q0 configuration is measured across C1/C4/C8 and prose/code, with three-run medians and raw JSON. It gives a practical structured-workload range of 48-64 tok/s per request and 126-160 tok/s aggregate at C8.
- Getrefined's vLLM numbers must keep their two measurement modes separate. The fresh request-level table reports 55.8 tok/s at C1 and 126.1 aggregate at C8; the later 63/203 figures come from Prometheus counter sampling after warm traffic and are not directly interchangeable with the fresh table.
- Community 2x results measure a system with tensor parallelism. They should not be described as two independent 1x endpoints or as a linear throughput guarantee.

### Provenance and Exclusions

- `chishiki37/qwen3.8-flash-next-nvfp4-2x-dgx-spark` names the pair (`cb98` and `3b24`), publishes raw result files, and credits the day-0 recipe while documenting its own sweep and patched image. Count it as a separate measured run, but not as an independent implementation lineage.
- `MiaAI-Lab/Qwen3.8-Flash-Next-Dual-DGX-Sparks` publishes a complete TP2 launcher, custom SM121 QSA fallback, memory/cliff post-mortem, and live-cluster throughput of 64.4 C1, 116.8 C2 aggregate, and 114.1 C4 aggregate. Its passkey suite is reliable through a single 128K prompt; 256K still requires a fresh validation after the fallback rebuild. Count it as direct two-Spark evidence, but the README does not independently identify the physical hosts.
- `getrefined/Qwen3.8-Flash-Next-NVFP4-vLLM-DGX-Spark` is a separate vLLM implementation and benchmark on two Sparks. It derives its launcher from an NVIDIA-forum FP8 configuration and uses a one-gate PLE patch; no prefill result is reported.
- `Weschera/qwen38-flashnext-dgx-spark` claims a clean-room QSA kernel and reports 41.7 single-stream / 149.5 C8, but its shipped path force-enables the TRT-LLM sparse decoder. That conflicts with the later repeated corruption finding in `cglab-public/dgx-spark-flashnext`, so retain the numbers as a performance claim, not a correctness-qualified result.
- `cglab-public/dgx-spark-flashnext` first reported 41-42 single-stream and 153 C8 after a 30-minute soak, then corrected its own recommendation: the forced TRT-LLM path collapsed at 120k-210k, while the MiaAI Triton fallback passed six repeated 210k probes. Its later ReplaySSM candidate passed selected real-workload replays but remained open after additional failures.
- `jamesmcarthur115555/qwen38-flash-next-dgx-spark-stable` publishes extensive current-candidate evidence: 47.33 single-stream, 155.60 C4, and 210.25 C6, with exact long-context and tool/vision regressions. It is useful stability evidence, but its current NEXTN path is explicitly still awaiting extended real-coding qualification.
- `pocharlies/qwen38-flash-next-dgx-spark-sglang` reports a 30-minute two-Spark soak at about 41-42 single-stream and 153 aggregate C8, plus an approximately 1.37M-token KV configuration. Treat it as a separate operational recipe, not a matched benchmark against the other rows.
- `maci0/qwen3.8-flash-next-spark` reports a live 2x SGLang TP2 deployment and 183-234 aggregate tok/s at 24 concurrency with ReplaySSM, but the reported 81-103 single-stream range is unusually high and has a large stated +/-25% variance. Keep it as a late, high-variance claim pending a raw harness artifact.
- `outstandly/twinspark-qwen-flash` is a companion to the MiaAI recipe. Its main contribution is operational and correctness testing, not a new throughput benchmark; later commits document that minimal probes passed while real agent payloads still triggered token-zero loops before the cited upstream fix.
- `PixelML/qwen3-8-flash-next-sglang-2x-dgx-spark` names the two-node topology, model revision, image digest, direct RoCE link, and exact NEXTN/MTP profile. Its decode table and uncached prefill report are direct measurements; the prefill result includes HTTP/tokenization/scheduling/first-decode overhead by design.
- `letsinferlabs/runtimes` packages a candidate execution contract derived materially from Tony2wild's recipe and requires independent qualification, but publishes no completed benchmark result. Treat its SM121 corrections and schema as an implementation proposal, not measured evidence.
- `0xBakeer/inference-atlas` is not a two-Spark source. Its current Qwen vLLM records use `hardware.count: 1`, a single ASUS Ascent GX10/GB10, and self-reported provenance. The 33.6-40.2 tok/s decode and approximately 2,056 tok/s 128K prefill figures belong in the one-Spark comparison only.

## What 2x Spark Changes

With tensor parallelism, each request is distributed across both GB10 systems. This can provide:

- More aggregate memory and room for KV cache, MTP state, runtime workspaces, and the PLE table.
- Higher single-stream throughput when the multi-node engine and interconnect are efficient.
- A way to serve models or quantization choices that are operationally uncomfortable on one Spark.

It also introduces:

- Per-token synchronization over the ConnectX-7 fabric.
- More sensitivity to NCCL, RoCE, rank startup, NIC selection, and container versioning.
- Failure of the whole tensor-parallel service when one node or the interconnect fails.
- No automatic 2x speedup. The reported 64.4 tok/s versus 32.2 tok/s is suggestive, but the configurations and workloads differ.

Data parallelism is a different deployment: each Spark serves its own requests. It is the right scaling mode for aggregate throughput and availability, but it does not reduce the latency of an individual request.

## Correctness and Runtime Caveats

The model and Spark software stack were new when these measurements were collected. The most important caveat is the SM121 Qwen Sparse Attention path:

- An early fix widened a FlashInfer TRT-LLM gate to include SM121.
- Independent tests found silent long-context corruption on that path: token-id-0 output occurred at 120k, 190k, and 210k prompts while the server still returned HTTP 200.
- The later SGLang fallback uses a Triton varlen kernel and is the safer path for GB10/SM121.
- Any deployment should repeat exact needle retrieval and tool-call tests at the intended context depth after pinning the image and model revisions.

Other relevant limitations:

- Thinking mode changes wall-clock completion time substantially and can make raw decode tok/s misleading. Several recipes disable thinking for their headline numbers.
- MTP gains depend on output shape. Code, lists, copied text, and tool arguments can accept more drafts than free-form prose.
- Long-context prefill and decode are reported with different methods across repositories. Context cache and prefix cache can make repeated prompts look much faster than cold prompts.
- No source reported a matched quality A/B across the one-Spark and two-Spark configurations.
- No source reported measured operating power, energy per token, or sustained thermal behavior.

### Hermes field experience

The strongest negative Qwen report used Hermes with a single Spark and described cache contamination after several hours plus a `systemd-oomd` service kill; that user retained DeepSeek V4 as the more dependable daily agent. Supporting DeepSeek reports include a dual-Spark installation described as flawless through weeks of 24/7 operation and another dual-Spark setup used through Hermes for remote computer tasks.

The thread is not unanimous. A later single-Spark Hermes Desktop report found Qwen at least as useful as DeepSeek, and possibly better for some agent tasks, after runtime updates eliminated the looping that user had seen earlier. Qwen was described as more concise and slower overall, with native vision as a practical advantage. Another user called DeepSeek slightly faster but still liked Qwen.

These reports support saying **DeepSeek was the safer Hermes daily driver during the Qwen launch period**. They do not support saying the thread proved DeepSeek to be the inherently better model: the evidence is anecdotal, configurations differ, and Qwen's runtime correctness changed during the discussion.

## Recommendation

For an always-on home-server deployment, use the following planning numbers:

| Planning case | Conservative expectation |
|---|---:|
| 1x Spark, general prose | about 28-32 tok/s |
| 1x Spark, favorable coding workload | about 40 tok/s; higher task-specific outliers exist |
| 2x Spark, TP2 single request | about 45-65 tok/s across mixed and structural public reports |
| 2x Spark, favorable code/structured workload | up to about 70 tok/s reported |
| 2x Spark, aggregate service | about 117 tok/s at two concurrent streams in one report |

Two Sparks are justified primarily by model fit, KV-cache headroom, multi-user aggregate throughput, or the desire to experiment with tensor-parallel serving. They are not justified by an expectation of a guaranteed 2x single-user speedup. Before committing to the hardware, run a matched benchmark using the exact checkpoint, runtime image, sampling mode, prompt set, context lengths, and correctness checks intended for production.

## Sources

### Official Model and Hardware

- [Qwen3.8-Flash-Next model card](https://huggingface.co/Qwen/Qwen3.8-Flash-Next) - exact local identifier, architecture, native context, official benchmark context, and serving links.
- [Qwen Cloud Qwen3.8-Flash](https://www.qwencloud.com/models/qwen3.8-flash) - hosted identifier `qwen3.8-flash`, 1M context, and service limits.
- [NVIDIA DGX Spark hardware guide](https://docs.nvidia.com/dgx/dgx-spark/hardware.html) - 128 GB unified memory, 273 GB/s bandwidth, power, and system specifications.
- [NVIDIA DGX Spark product page](https://www.nvidia.com/en-us/products/workstations/dgx-spark/) - GB10, 128 GB coherent memory, ConnectX-7, and cluster positioning.
- [NVIDIA ConnectX-7 clustering guide](https://docs.nvidia.com/dgx/dgx-spark/spark-clustering.html) - physical and network requirements for multi-Spark clusters.

### Community Benchmark Artifacts

- [0xBakeer one-GB10 measurements](https://raw.githubusercontent.com/0xBakeer/qwen38-flash-next-spark/790c0238c46ddba506f33c8b0427e71fd10954db/docs/measurements.md) - ASUS Ascent GX10 common-harness vLLM and llama.cpp results, prefill, TTFT, context-depth, and concurrency measurements.
- [0xBakeer vLLM long-context recipe](https://raw.githubusercontent.com/0xBakeer/qwen38-flash-next-spark/790c0238c46ddba506f33c8b0427e71fd10954db/recipes/vllm-longctx/README.md) - NVFP4/MTP configuration, independent-harness comparison, and concurrency data.
- [hashd1ve one-Spark recipe](https://raw.githubusercontent.com/hashd1ve/qwen38-flash-next-one-dgx-spark/bd16dce2017a498d65ca9370ee27ea929f3781e6/README.md) - SGLang NVFP4 code/prose results, long-context timing, and SM121 correction.
- [tonyd2wild two-Spark TP2 recipe](https://raw.githubusercontent.com/tonyd2wild/Qwen3.8-Flash-Next-NVFP4-DGX-Spark/65ea3883b8dd80438b58ace56eb7979c52fa6ea6/README.md) - 2x Spark MTP4/CUDA-graph results and configuration details.
- [MiaAI-Lab two-Spark TP2 recipe](https://raw.githubusercontent.com/MiaAI-Lab/Qwen3.8-Flash-Next-Dual-DGX-Sparks/0f950012c8d8323acac9a08846a32ef7953f5f62/README.md) - 2x Spark single-stream and concurrent throughput results.
- [chishiki37 two-Spark TP2 recipe](https://github.com/chishiki37/qwen3.8-flash-next-nvfp4-2x-dgx-spark/tree/6510faf829c2986f4a216ca8b3eb3ad8c2beba6c) - named-pair sweep, winner battery, raw results, and packed-FP4 KV capacity experiment.
- [getrefined vLLM two-Spark recipe](https://raw.githubusercontent.com/getrefined/Qwen3.8-Flash-Next-NVFP4-vLLM-DGX-Spark/f736930b636d2dbb4c7f4746311cbac66d8d2a6e/README.md) - vLLM TP2+EP, MTP3, fresh and warmed throughput tables.
- [Weschera two-Spark recipe](https://raw.githubusercontent.com/Weschera/qwen38-flashnext-dgx-spark/545a1810b873127114fe04baf72940cc08bce7b5/README.md) - alternate QSA kernel, benchmark claims, and long-context caveats.
- [cglab-public SM121 field notes](https://raw.githubusercontent.com/cglab-public/dgx-spark-flashnext/31d6fd4e6470d7095d3bf11a0bb58714422690c0/README.md) - repeated long-context corruption tests and corrected kernel recommendation.
- [jamesmcarthur115555 stability recipe](https://raw.githubusercontent.com/jamesmcarthur115555/qwen38-flash-next-dgx-spark-stable/14084f1e8255c8da45221ff1f0d1f21ed4fa357e/BENCHMARKS.md) - current ReplaySSM candidate throughput and stability qualification.
- [pocharlies two-Spark recipe](https://raw.githubusercontent.com/pocharlies/qwen38-flash-next-dgx-spark-sglang/92a3e84c0757b608de3ead2ee9206e4effd0f441/README.md) - 30-minute soak and KV/concurrency tuning table.
- [maci0 two-Spark SGLang recipe](https://raw.githubusercontent.com/maci0/qwen3.8-flash-next-spark/a5b1b8ad87678d3c3ec949ded70e108e39b0dc2f/docs/sglang-perf.md) - late ReplaySSM A/B results and variance notes.
- [PixelML two-Spark decode results](https://raw.githubusercontent.com/PixelML/qwen3-8-flash-next-sglang-2x-dgx-spark/768085e31bb6c2997d9c9ebfe67134e1cab34f5e/results/RESULTS-2026-08-26.md) - pinned TP2 deployment, decode concurrency, and functional validation.
- [PixelML uncached prefill results](https://raw.githubusercontent.com/PixelML/qwen3-8-flash-next-sglang-2x-dgx-spark/af3669b952c77225ffb205f53e3ff9fe00f69033/results/PREFILL-2026-08-27.md) - unique-prefix, cache-zero prefill ladder.
- [Let's Infer candidate runtime](https://raw.githubusercontent.com/letsinferlabs/runtimes/ad7c6da649a492951e8b6371f78c4e30bd08524e/sglang--radixark--qwen3.8-flash-next-nvfp4--dgx-spark-connectx-2/README.md) - derived execution contract and independent qualification requirements; no completed benchmark.
- [Inference Atlas Qwen vLLM result](https://raw.githubusercontent.com/0xBakeer/inference-atlas/6e7e9de700389ab204cd2b34f13d024aa02c6609/results/vllm/Qwen/Qwen3.8-Flash-Next/nvidia-gb10-dgx-spark/cb516ca371e97893--prefill-128k-v1--bfbada.json) - single-GB10 prefill result; hardware count is explicitly 1 and is excluded from 2x conclusions.

### Runtime Correctness

- [SGLang issue #36537](https://github.com/sgl-project/sglang/issues/36537) - token-0 loop/corruption issue.
- [SGLang PR #36806](https://github.com/sgl-project/sglang/pull/36806) - correction to the unsafe SM121 TRT-LLM gate.
- [SGLang PR #36845](https://github.com/sgl-project/sglang/pull/36845) - Triton SM121 varlen fallback used by the corrected recipes.

### Hermes Field Reports

- [Qwen cache and memory failure; DeepSeek called the more dependable daily agent](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/193).
- [Dual-Spark DeepSeek described as flawless over weeks of 24/7 work](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/169).
- [Hermes with DeepSeek on dual Sparks for remote computer administration](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/187).
- [Qwen described as at least as useful as DeepSeek and possibly better for some tasks](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/209).
- [DeepSeek described as slightly faster while the user still liked Qwen](https://forums.developer.nvidia.com/t/qwen3-8-flash-next/381228/166).
