# Hermes local Qwen thinking-mode A/B

**Date:** 2026-09-03  
**Model:** `Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf`, live llama.cpp service on kube5  
**Question:** Should Hermes disable Qwen thinking mode to improve Open WebUI responsiveness?

## Method

The harness called the live OpenAI-compatible endpoint directly using the current `SOUL.md` plus representative mock Hermes tools. It exercised eight scenarios twice in each mode: concise general Q&A, supportive guidance, current cluster status, Prometheus query construction, pull-request selection, destructive-action restraint, conversation continuity, and a multi-step unhealthy-pod diagnosis.

Thinking mode used Qwen's recommended thinking sampling (`temperature=1.0`, `top_p=0.95`, `top_k=20`); non-thinking used `temperature=0.7`, `top_p=0.8`, `top_k=20`, `presence_penalty=1.5`. Each request set `cache_prompt: false`, so timings exclude prefix-cache gains. Both modes used MTP and a 2,048-token output ceiling.

This is a small targeted test, not a full Hermes/Open WebUI end-to-end benchmark. Mock tool results were deterministic, and output quality was checked against task-specific criteria.

## Results

| Metric (16 runs/mode) | Thinking | Non-thinking | Change |
|---|---:|---:|---:|
| Mean end-to-end model-call time | 10.51 s | 6.30 s | **40% lower** |
| Mean decode time | 7.42 s | 3.27 s | **56% lower** |
| Mean completion tokens | 328 | 116 | **64% fewer** |
| Mean prompt-processing time | 3.05 s | 3.00 s | effectively equal |
| Automated pass rate | 87.5% | 93.75% | favors non-thinking |
| Manual valid-task rate | 93.75% | 100% | favors non-thinking in this sample |

The automated scorer produced one false negative for each mode on a RAID/backup answer: both answers were substantively correct but omitted a literal keyword required by the heuristic. After correcting those, thinking failed one supportive-guidance run by making two unnecessary tool calls and stopping before delivering advice. Non-thinking completed every task acceptably.

Both modes achieved:

- Correct initial tool selection on all six single-tool trials.
- Correct Prometheus CPU-query intent and open-PR argument selection.
- No destructive `delete_pod` call when the user explicitly said they were exploring.
- Correct conversation continuity on both trials.

Thinking did show one meaningful quality advantage: it fetched pod logs in both multi-step diagnosis trials and identified the exact missing `DATABASE_URL`. Non-thinking fetched logs in one trial; in the other it correctly identified `CrashLoopBackOff` and recommended logs as the next step, but paused instead of autonomously continuing.

Task-level mean wall time:

| Task | Thinking | Non-thinking |
|---|---:|---:|
| RAID/backup explanation | 15.31 s | 5.57 s |
| Cluster tool selection | 3.52 s | 2.62 s |
| Conversation continuity | 4.30 s | 2.97 s |
| Destructive-action restraint | 16.63 s | 6.94 s |
| Metrics tool selection | 5.66 s | 2.94 s |
| Multi-step diagnosis | 19.58 s | 11.54 s |
| Pull-request tool selection | 5.39 s | 3.22 s |
| Supportive guidance | 13.66 s | 14.58 s |

## Bounded-thinking follow-up

A controlled follow-up compared llama.cpp reasoning budgets of 256 tokens, 512 tokens, and unlimited reasoning. Each variant received the same prompts and random seeds, again with two repetitions per task. `thinking_budget_tokens` limits the reasoning block only; answer or tool-call tokens can follow it.

| Metric (16 runs/variant) | 256 tokens | 512 tokens | Unlimited |
|---|---:|---:|---:|
| Automated pass rate | 68.75% | **100%** | **100%** |
| Reasoning leakage | 3 runs | **0** | **0** |
| Mean model-call time | 11.48 s | **13.52 s** | 16.45 s |
| Median model-call time | 10.24 s | **13.80 s** | 14.67 s |
| Mean decode time | 8.28 s | **10.07 s** | 11.82 s |
| Mean completion tokens | 326 | **460** | 510 |

The 256-token cutoff was too abrupt. Three outputs exposed a closing `</think>` tag or fragments of internal reasoning. One multi-step diagnosis spent all three allowed tool rounds gathering evidence and never produced a final answer. One automatically failed backup explanation was actually correct, but that scorer false negative does not change the cutoff-safety finding.

The 512-token budget matched unlimited reasoning on task completion, tool correctness, destructive-action restraint, and output cleanliness. Compared with the controlled unlimited baseline, it reduced:

- Mean model-call time by 17.8%.
- Mean decode time by 14.8%.
- Mean completion tokens by 10.0%.

Median wall time improved by a more modest 5.9%; the larger mean improvement includes queue and prompt-processing outliers. Prompt-processing time was effectively identical, so decode time and completion-token reductions are the more reliable signals. Many easy tasks completed naturally below the ceiling, while the limit constrained only longer reasoning runs.

## Decision guidance

A 512-token reasoning ceiling is the best tested compromise. It retains thinking's deeper multi-step behavior, avoids the malformed output observed at 256 tokens, and limits pathological internal monologues without loading a classifier model or maintaining separate Fast and Deep profiles.

Apply the budget to Hermes requests rather than globally to llama.cpp so direct Qwen sessions can remain unlimited. Hermes supports request-level `extra_body` on named custom providers; the relevant llama.cpp request field is `thinking_budget_tokens: 512`.

This remains a small direct-endpoint benchmark with deterministic mock tools. After deployment, validate several real Hermes sessions with actual tools, memory retrieval, compression, and Open WebUI streaming. Switchyard remains useful later if one fixed budget cannot cover both routine chat and genuinely difficult autonomous work.
