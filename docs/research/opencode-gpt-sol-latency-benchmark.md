# OpenCode model latency benchmark

**Run:** 2026-08-29T22:36:13.768722+00:00  
**OpenCode:** `1.18.23`  
**Representative OpenCode context fixture:** 34,852 bytes  
**Long prompt payload:** 100,489 bytes

## Results (median where repeated)

| Target | Scenario | Runs | Exact | Input tokens | Cache-read tokens | TTFT | Generation | End-to-end | Generated tok/s |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gpt-sol | fixed-output | 3 | 3/3 | 9180 | 0 | 2.86s | 3.53s | 6.44s | 55.30 |
| gpt-sol | long-cold | 1 | 1/1 | 20509 | 1792 | 2.62s | 0.35s | 3.02s | 48.85 |
| gpt-sol | long-warm | 1 | 1/1 | 22337 | 0 | 2.67s | 0.21s | 2.93s | 37.74 |

## Interpretation

- GPT Sol sustained **55.3 generated tok/s** on the fixed 195-token response and reached visible output in a median **2.86 seconds**.
- In the single long-prompt sample, increasing total context from about 9.2k to 22.3k tokens barely changed TTFT (**2.86 to 2.62 seconds**). The latter comprised 20,509 uncached plus 1,792 cache-read tokens. This suggests cloud prompt ingestion was not the dominant delay in that run, but it is not a distribution estimate.
- The follow-up reported **22,337 input tokens and no cache read**, yet reached visible output in **2.67 seconds**. Provider-internal behavior may not be fully represented by usage accounting, but this result does not demonstrate a billed prompt-cache hit.
- The fixed-output results were tightly grouped: TTFT ranged **2.78-2.92 seconds** and generation **3.39-3.57 seconds**.

## Projected 2x DGX Spark comparison

Qwen3.8-Flash-Next was not run because no Spark endpoint is available. The following comparison applies the public measurements collected in [the DGX Spark research note](./qwen38-flash-dgx-spark-benchmarks.md); it is a projection, not an A/B result.

| Metric | Measured GPT Sol | Projected 2x Spark Qwen3.8 |
|---|---:|---:|
| Fixed structured output | 55.3 tok/s | about 64-70 tok/s reported for favorable structured output |
| Fresh ~9.2k-token TTFT | 2.86 s, including OpenCode startup and cloud overhead | about 1.9-4.2 s of server-side prefill from ideal-to-no TP2 scaling, plus unmeasured OpenCode/client overhead |
| Fresh ~22.3k-token total-context TTFT | 2.62 s, including OpenCode startup and cloud overhead; 20.5k uncached + 1.8k cache-read | about 4.5-10.2 s of server-side prefill if all 22.3k tokens are uncached, plus unmeasured OpenCode/client overhead |
| ~22.3k-token follow-up | 2.67 s with no reported cache read | unknown: no validated cache-enabled 2x Spark result was found |

At equal tokenization, 195 output tokens would take about **2.8-3.0 seconds** at the reported 64-70 tok/s dual-Spark rate, versus GPT Sol's measured **3.53 seconds**. Qwen should therefore stream this predictable output somewhat faster once generation begins. This comparison assumes a structured, non-thinking response like the benchmark; the public Qwen figures mix task shapes and runtime settings and do not predict reasoning-heavy wall time. GPT Sol's measured end-user TTFT is lower than even the idealized Qwen server-side prefill estimate at ~22.3k tokens; because the measurement domains differ, this is directional rather than an A/B result. No defensible warm-session comparison is possible until a stable dual-Spark configuration demonstrates correct radix/prefix caching.

The public single-GB10 vLLM prefill rate was 2,183-2,463 tok/s. The 22.3k-token benchmark prompt would therefore take about 9.1-10.2 seconds on one system; an ideal 2x prefill speedup would reduce that to 4.5-5.1 seconds, but no matched TP2 long-prompt measurement establishes that scaling.

## Method

- `fixed-output`: a fresh OpenCode session receives inert context sized to approximate this workspace's normal tool-rich prompt, then emits the same 64-item sequence.
- `long-cold`: a fresh session receives synthetic inert context containing one retrieval needle and a per-run nonce to prevent reuse of the user-prompt prefix across benchmark runs.
- `long-warm`: a short follow-up continues the long-cold session, exposing effective provider-side or local prefix caching.
- TTFT is measured from process launch to OpenCode's recorded start of the visible text part. It includes OpenCode startup, prompt assembly, network/queue delay, prompt ingestion, and any hidden reasoning before visible output.
- Generated tok/s uses provider-reported visible-output plus reasoning-token count divided by OpenCode's recorded generation interval. This run reported zero reasoning tokens. Tokenizers differ, so fixed response text and wall time are the stronger cross-model comparison.

## Caveats

- This is a latency and instruction-following smoke test, not a coding-quality benchmark.
- A local target only represents the configured endpoint and model. It does not predict untested DGX Spark hardware.
- Cloud results vary with provider load, account routing, and prompt-cache state.
- The long-cold and long-warm rows are one exploratory run each.
- The OpenCode CLI starts a process per request; persistent interactive sessions avoid part of that overhead.
- A dedicated no-tool benchmark agent denies file, shell, and network tool execution. The inert context fixture preserves representative prompt size without exposing live tools.
- Machine-readable evidence for this run is in [`results/opencode-gpt-sol-latency-benchmark.json`](./results/opencode-gpt-sol-latency-benchmark.json).

## Reproduce

```sh
python3 scripts/benchmark_opencode_models.py \
  --config scripts/opencode-model-benchmark.json \
  --output-json /tmp/opencode-gpt-sol-latency-benchmark.json \
  --output-markdown /tmp/opencode-gpt-sol-latency-benchmark.md
```
