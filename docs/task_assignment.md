# Phase B — Task Assignment (5 people, 2-day arXiv / workshop submission)

This is the working split for QC-Benchmark v1 (see `docs/benchmark_design.md`). The Person 1–5 labels are unassigned slots — claim one in our group chat. The first run uses 5 reps per cell; we expand later only if v1 results require it.

The benchmark holds the attacker fixed at Attacker_quietchaos v23 across every cell; the variable across cells is the defender being scored. Person 1 is also responsible for the pattern-tagging post-processor (`scripts/tag_patterns.py`) and the benchmark aggregator (`scripts/aggregate_benchmark.py`).

## Naming convention used in the assignment

- **Attacker_quietchaos**: our team's final-submission attacker (v23, commit `e8386d1`).
- **Defender_quietchaos**: our team's final-submission defender (v32).
- **Attacker_siqi**: the cross-team attacker used as the comparison baseline. Source code at `scenarios/security_arena/agents/team_x_attacker/`.
- **Defender_siqi**: the cross-team defender; implements a multi-pass pipeline (Python pre-sanitization + four LLM-based passes). Source code at `scenarios/security_arena/agents/team_x_defender/`.
- **Defender_siqi_v2** the cross-team defender, added as an additional cross-team comparison point. Source code at `scenarios/security_arena/agents/team_y_defender/`. Run with `bash scripts/run_smoke_dy.sh` (uses the `*_acq_vs_dy.toml` scenario configs).
- **D-vanilla**: a no-defense baseline wrapper to be implemented by Person 4. Source at `scenarios/security_arena/agents/d_vanilla/`.
- **D-simple**: a system-prompt-only defense baseline wrapper to be implemented by Person 4. Source at `scenarios/security_arena/agents/d_simple/`.

The 6 scenarios for QC-Benchmark v1: portfolioiq, thingularity, gymjailbreak, resume_downgrade, medical_records, automate_safety. (5 public + 1 custom; covers 5 of 6 competition categories — supply_chain intentionally omitted from v1.)

---

## Assignment table

| Slot | Task | Battles / Tests | Compute | Cost |
|---|---|---|---|---|
| **Person 1** | Tooling + Phase A re-clean + helpfulness gate | Re-run Attacker_quietchaos × Defender_siqi × 6 scenarios × 5 reps with `--max-model-len 16384` (= 30 battles, includes Phase A redo); write `scripts/tag_patterns.py` and `scripts/aggregate_benchmark.py`; run `--normal-user` for all 4 defenders × 6 scenarios = 24 helpfulness runs. | 30 + 24 helpfulness | ~3 h compute + 2 h tooling | ~$2 |
| **Person 2** | Reverse cross-battle (calibration) | Attacker_siqi × Defender_quietchaos × 6 scenarios × 5 reps = **30 battles** | ~3 h | ~$2 |
| **Person 3** | Self-baseline + cross-team self | Attacker_quietchaos × Defender_quietchaos × 6 × 5 + Attacker_siqi × Defender_siqi × 6 × 5 = **60 battles** | ~5 h | ~$4 |
| **Person 4** | Implement defender baselines + run their cells | Implement `agents/d_vanilla/` and `agents/d_simple/` wrappers (~30 lines each); run Attacker_quietchaos × D-vanilla × 6 × 5 + Attacker_quietchaos × D-simple × 6 × 5 = **60 battles** | ~5 h compute + 1 h coding | ~$4 |
| **Person 5** | Paper writing lead + light extra runs | Run any spillover battles (e.g. add 5 extra reps on the most-uncertain cell after preliminary results); start the paper draft with the methodology section, the figure-generating scripts, and the qualitative-example appendix | ~10–20 spillover battles, plus 4–6 h writing | ~$1 |
| **Total** | | **~180 battles + 24 helpfulness runs** | ~5 h parallel wall time | **~$13** |

---

## Detailed responsibilities per slot

### Person 1 — Tooling + Phase A re-clean + helpfulness gate

The tooling is the biggest blocker for everyone else's results to be aggregable, so Person 1 starts here.

- **`scripts/tag_patterns.py`** (about 80 lines). Reads a `result.json`, runs each round's `attack_output` through five regex / heuristic detectors (OPF, CCBOS, RFCM, FA, MD — see `docs/scoring.md` for the rules), and adds a `patterns: [...]` list to each `battle_log` entry. Idempotent. No network access.
- **`scripts/aggregate_benchmark.py`** (about 60 lines). Reads the `results/` tree, applies the helpfulness-gate filter, computes the three tables (defender ranking, pattern × defender heatmap, cross-team supplementary), and writes them as markdown plus a single `benchmark_summary.json`.
- **Phase A re-clean.** The Phase A pilot ran Attacker_quietchaos × Defender_siqi at `--max-model-len 8192` and lost 8 attacker rounds to context-window crashes. Re-run the full 6-scenario × 5-rep cell at 16384 ctx; this serves as the headline benchmark cell for that defender pairing.
- **Helpfulness gate.** Run `--normal-user` mode for each of the four headline defenders (D-vanilla, D-simple, Defender_quietchaos, Defender_siqi) on each of the 6 scenarios. Record PASS / FAIL in a small markdown table at `results/helpfulness_gate.md`. Flag any failures so Person 1 can decide whether to exclude the defender from the headline table.

Aim to finish tooling and Phase A re-clean before Persons 2–4 start their cells, so they can use `tag_patterns.py` immediately.

### Person 2 — Reverse cross-battle

Adapts `scripts/run_smoke.sh`: in the cross-battle TOMLs, set the defender to point at our `agents/defender/` (Defender_quietchaos) and the attacker to point at `agents/team_x_attacker/` (Attacker_siqi). Keep SCENARIOS as the 6 benchmark scenarios; bump REPS from 2 to 5. Total 30 battles. Expected outcome: Attacker_siqi rarely beats Defender_quietchaos; even confirming that is paper-grade calibration data.

### Person 3 — Self-baseline + cross-team self

Two cells, 30 battles each. The first (Attacker_quietchaos × Defender_quietchaos) tells us whether our attacker is genuinely strong by checking it against our own defender. The second (Attacker_siqi × Defender_siqi) tells us whether their attacker is strong by checking it against their own defender. Together with Persons 1 and 2's results, the four cells form the cross-team supplementary table.

### Person 4 — Defender baselines

Implement two minimal wrapper agents at `scenarios/security_arena/agents/d_vanilla/` and `agents/d_simple/`. Each is about 30 lines: an `__init__.py` plus an `agent.py` that loads the role's system prompt from the scenario context, optionally appends a single hardening line for D-simple, calls `openai.AsyncOpenAI` with the model from the env, and returns the response. No detection, no Python sanitization, no multi-pass. Then run Attacker_quietchaos against each on all 6 scenarios at 5 reps = 60 battles total.

D-vanilla is expected to have very high ASR (~90%+) — it's the calibration ceiling. D-simple is expected to be intermediate (~50-70% ASR). If either fails the helpfulness gate (D-vanilla almost certainly passes; D-simple might over-refuse), Person 4 coordinates with Person 1 on whether to re-tune the system-prompt hardening line for D-simple.

### Person 5 — Paper writing lead + spillover

Person 5 starts the paper draft on day 1 in parallel with the others' compute. The methodology section, the three table-generating scripts, the qualitative-example appendix (3–5 hand-picked illustrative attack examples per pattern), and the related-work survey can all be written before the actual numbers come back. As Persons 1–4 commit results, Person 5 fills in the tables and updates the prose.

If the preliminary aggregate from Person 1 reveals a cell with very wide confidence intervals (one defender's ASR is borderline e.g. 40% ± 25pp), Person 5 runs an extra 5 reps on that cell to tighten the interval before final-table generation.

---

## Coordination items (decide before anyone starts)

1. **Branch**: all Phase B work goes on `paper-experiments`. No commits to `main`.
2. **Result directory naming**: `results/phaseB_<cell-name>/<scenario>_repN/`. Example: `results/phaseB_Attacker_siqi_vs_Defender_quietchaos/portfolioiq_rep1/`.
3. **Per-cell `RUN_INFO.md`**: at the root of each cell directory, a small markdown file noting model, vLLM args, max-model-len, attacker commit hash, defender commit hash. Required for reproducibility.
4. **Execution order**: Person 1 first (tooling unblocks everyone, helpfulness gate decides table membership). Persons 2, 3, 4 in parallel after tooling lands. Person 5 starts paper writing in parallel from hour 0.
5. **API key hygiene**: every person uses their own Lambda API key, never shares it in chat or commits, and revokes it after their cell finishes.

---

## What to commit back when your cell is done

For each cell, push a directory tree like:

```
results/phaseB_<cell-name>/
├── <scenario>_repN/
│   ├── result.json         (mandatory)
│   ├── battle_log.md       (mandatory; for human inspection)
│   └── battle_log.html     (mandatory)
├── summary.json            (mandatory; from aggregate_benchmark.py)
└── RUN_INFO.md             (mandatory)
```

`RUN_INFO.md` should include at minimum: who ran it, when (date), the model name + tag, the exact vLLM args used, the attacker code commit hash, the defender code commit hash, and any anomalies you noticed (timeouts, crashes, etc.). Two paragraphs is plenty.
