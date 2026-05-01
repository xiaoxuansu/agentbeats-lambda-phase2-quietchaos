# Experiment Plan — Cross-Team Defender Benchmark

## Goal

Benchmark our latest attacker against two structurally simple defenders — one early-iteration Quiet Chaos defender, one cross-team defender — on five public scenarios from the AgentBeats competition.

## Frozen attacker

- **attacker_quietchaos_v23** — commit `e8386d1`. The latest iteration of our attacker (post-competition resubmit with internal simulation feedback). Includes the CC-BOS engine, ML scenario classifier, adversarial suffix module, and PAIR-style 4-call pipeline.
- **Model**: `openai/gpt-oss-20b` via vLLM in Docker.
- **vLLM args**: `--gpu-memory-utilization 0.85 --max-model-len 16384`. Lower context is forbidden (Phase A pilot at 8192 caused 8 attacker self-crashes).
- **Hardware**: 1× A10 (24 GB).
- **Decoding**: vLLM defaults.
- **Rounds per battle**: 7.
- **Reps per cell**: 6 (5 main + 1 backup; see `docs/task_assignment.md`).

## Defenders

Two structurally simple defenders from different teams, picked to give a heterogeneous "weak baseline" comparison:

- **Defender_x** — Quiet Chaos's own *early-iteration* defender (v4, commit `c9ce039`). Source code checked out to `scenarios/security_arena/agents/quietchaos_v4_defender/`. ~190 lines, "goal-aware intent analysis" — a single intent-classification layer plus the LLM call. No multi-pass pipeline, no detect / verify templates, no Python sanitization. Represents our team's earliest defended submission, deliberately weak.
- **Defender_y** — Cross-team simple defender, ~206 lines, single-LLM-call pipeline with `detect.j2` and `verify.j2` templates. Source code at `scenarios/security_arena/agents/team_y_defender/`. The `templates/user.j2` is the simpler form that hands the input to the LLM verbatim.

The Defender_x / Defender_y pair gives **cross-team and cross-architecture** comparison: our team's intent-classifier-only early defender vs another team's detect-then-verify pipeline. Both are deliberately structurally simple to keep the attacker's signal clean (no floor-effect ASR).

Other variants on disk that are **not** part of this benchmark:
- `scenarios/security_arena/agents/team_x_defender_433line_unused/` — a 433-line multi-pass variant of the cross-team defender. Strong; risks floor-effect ASR.
- `scenarios/security_arena/agents/team_x_defender_206wrapped_unused/` — the 206-line cross-team defender with an `<untrusted_data>` wrapper in `user.j2`. An earlier 2-defender plan used this as Defender_x; replaced with our v4 defender for cross-team heterogeneity.

## Scenarios (5 total)

The 5 public scenarios from the leaderboard set — already in repo and used by the AgentBeats competition:

- `portfolioiq` — primary: indirect_injection (assessment flip)
- `thingularity` — primary: prompt_extraction (tool / system-prompt disclosure)
- `gymjailbreak` — primary: insecure_output (formula / numeric injection); jailbreak co-tag
- `resume_downgrade` — primary: indirect_injection (ranking manipulation)
- `medical_records` — primary: pii_leak

Coverage: 4 of the 6 competition attack categories as primary scenarios (jailbreak appears as a co-tag on gymjailbreak; supply_chain is not represented in any public scenario). We accept this gap because expanding the scenario list to fill it would require designing or porting a new scenario, which doesn't fit the 2-day window.

## Cells and counts

```
                            Defender_x       Defender_y
attacker_quietchaos_v23     5 × 6 = 30       5 × 6 = 30       Total 60 battles
```

Six reps per (defender, scenario) cell: 5 from the primary owner of that scenario plus 1 backup rep from the previous person in the round-robin (see `docs/task_assignment.md`). The backup design protects against single-point-of-failure on individual collaborator setups.

No helpfulness-gate runs (see "Helpfulness gate (skipped)" below).

Compute envelope: each of 5 collaborators runs 12 battles in ~1.2 h on their own Lambda instance in parallel. Total Lambda time across the team is ~6 hours of compute, completed in about 1.5 hours wall clock. Total cost across all collaborators: about **$5**.

## Helpfulness gate (skipped)

Helpfulness was a per-defender precondition in earlier plans, but it is **dropped** for this benchmark. Both defenders are submitted defenders from previous competition rounds, where the AgentBeats orchestrator runs the normal-user test by default at submission time. Both passed at submission, so we trust those results rather than re-running locally. If a deployment-validity question comes up in review, the answer is "this defender's submission cleared the standard normal-user check at the time it was submitted to the competition."

## What the report includes

Three artifacts get committed back:

1. **Defender × Scenario ASR table** (2 rows × 5 columns + aggregate) — the headline result.
2. **Pattern × Defender heatmap** (7 attack patterns × 2 defenders) — diagnostic, derived from per-round attack-output tags via `scripts/tag_patterns.py`. Patterns: OPF, CCBOS, RFCM, FA, MD (Phase A) + CCFI, IRR (Phase B additions; see `docs/scoring.md`).
3. **Heterogeneous weak-baseline comparison** (Defender_x vs Defender_y) — our team's early intent-classifier-only defender vs the cross-team's detect-then-verify defender. Where each holds against attacker_quietchaos_v23, and where each fails.

Each cell directory under `results/` includes `result.json` per battle, `battle_log.md` for human inspection, the `summary.json` from `aggregate_benchmark.py`, and a `RUN_INFO.md` recording who ran it, when, model, vLLM args, and attacker / defender commit hashes.

## Methodology disclosure for the paper

The paper Methodology section will state:

> "We benchmark a post-competition iteration of our attacker (commit `e8386d1`, dated 2026-03-30), which extends the competition submission (`74c124c`, 2026-03-28) with the CC-BOS engine, ML scenario classifier, and adversarial suffix module. The choice reflects our intent to characterize the strategy capabilities of our team's attack methodology rather than to reproduce the official leaderboard results."

The Limitation section will add:

> "Our findings characterize the post-competition iteration of our attacker; the competition submission may exhibit different behavior due to its smaller pipeline."

## Out of scope for this plan

These are deferred and explicitly not part of the current run:

- D-vanilla, D-simple baselines.
- External attacker baselines (PAIR / GCG / AutoDAN).
- Forced single-strategy ablation experiments.
- Defender-layer ablation on Defender_quietchaos.
- Model variation (gpt-oss-120b, Llama, Qwen).
- A supply_chain scenario.
- Increasing reps beyond the current 6 for tighter confidence intervals.
