# Experiment Matrix

Quick-reference matrix view of what gets run. The full plan is in `docs/benchmark_design.md`; the per-person split is in `docs/task_assignment.md`.

## Variables

| Var | Levels | Notes |
|---|---|---|
| Attacker | attacker_quietchaos_v23 (commit `e8386d1`) | Frozen across all cells. |
| Defender | Defender_x / Defender_y | Two structurally simple defenders. Defender_x = Quiet Chaos v4 early defender (~190 lines, intent-classifier-only, commit `c9ce039`). Defender_y = cross-team ~206-line single-LLM-call defender. Heterogeneous architectures; both deliberately weak to avoid floor-effect ASR. |
| Scenario | portfolioiq, thingularity, gymjailbreak, resume_downgrade, medical_records | 5 public scenarios from the leaderboard set. Covers 4 of 6 categories as primary scenarios (jailbreak co-tag on gymjailbreak; supply_chain not in the public set). |
| Reps per cell | 5 | Minimum for any cell we report on. |
| Model | openai/gpt-oss-20b | vLLM with `--gpu-memory-utilization 0.85 --max-model-len 16384`. |

## Cells

```
                            Defender_x       Defender_y
attacker_quietchaos_v23     5 × 6 = 30       5 × 6 = 30
```

Total: **60 battles** = 6 reps per (defender, scenario) cell (5 main + 1 backup; see `docs/task_assignment.md`). No helpfulness-gate runs (defenders trusted from their original AgentBeats submission tests).

## Metrics reported

- Battle-level ASR per (defender, scenario) cell
- Defender aggregate ASR across the 5 scenarios
- Pattern × defender heatmap (5 attack-pattern tags from `docs/scoring.md`)
- Helpfulness gate PASS / FAIL per (defender, scenario)
- Manipulation round (median, when attacker wins)

## Compute envelope

- 60 battles × ~6 min/battle = ~6 h sequential.
- With each of 5 collaborators running 12 battles on their own Lambda instance in parallel, wall time is about **1.5 hours of compute** plus tooling and writing side tasks.
- Total Lambda cost across all collaborators: about **$5**.

## Out of scope (deferred)

These are explicitly not part of the current matrix. They would be additions to a v2, not changes to v1:

- D-vanilla / D-simple baseline defenders
- Defender_quietchaos (our own defender) as a reference row
- External attacker baselines (PAIR / GCG / AutoDAN)
- Forced single-strategy ablation
- Defender-layer ablation on Defender_quietchaos
- Model variation (gpt-oss-120b, Llama, Qwen)
- A supply_chain scenario
- Increased reps (5 → 10) for tighter confidence intervals
