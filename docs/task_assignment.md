# Task Assignment (5 collaborators, 2-day window)

This is the working split for the Cross-Team Defender Benchmark experiment described in `docs/benchmark_design.md`. The Person 1–5 labels are unassigned slots; claim one in coordination.

## ⚠️ Critical vLLM configuration (READ BEFORE RUNNING)

Every collaborator who starts a vLLM instance must use:

```
vllm serve openai/gpt-oss-20b \
    --gpu-memory-utilization 0.85 \
    --max-model-len 16384
```

**Do NOT use `--max-model-len 8192` or lower.** Our attacker generates prompts up to about 8,800 tokens (planner + generator + critic + battle history). The Phase A pilot ran at 8192 and lost 8 of its 70 attack rounds to HTTP 400 "Input length exceeds context length" errors. Those crashed rounds were silently scored as defender wins, contaminating the data. 16384 is the lowest acceptable value; A10 24 GB fits 16384 at 0.85 utilization.

If your `result.err` shows `Input length (XXXX) exceeds model's maximum context length`, stop the run, restart vLLM with the correct args, and rerun the affected scenario.

## Naming convention

- **attacker_quietchaos_v23** — our attacker, commit `e8386d1`. Frozen across every cell.
- **Defender_x** — Quiet Chaos's *early-iteration* defender (v4, commit `c9ce039`). ~190 lines, "goal-aware intent analysis": one intent-classification layer plus the LLM call. Source code at `scenarios/security_arena/agents/quietchaos_v4_defender/`.
- **Defender_y** — cross-team simple defender, ~206 lines, single-LLM-call pipeline with `detect.j2` and `verify.j2` templates, no `<untrusted_data>` wrapper in `templates/user.j2`. Source code at `scenarios/security_arena/agents/team_y_defender/`.

Other defender variants on disk that are NOT part of this benchmark (preserved for possible later use):
- `agents/team_x_defender_433line_unused/` — 433-line multi-pass cross-team defender (would risk floor-effect ASR)
- `agents/team_x_defender_206wrapped_unused/` — 206-line cross-team defender with `<untrusted_data>` wrapper

The 5 scenarios: portfolioiq, thingularity, gymjailbreak, resume_downgrade, medical_records.

## Assignment table

Each collaborator owns **one main scenario** (5 reps × 2 defenders = 10 battles) and runs **1 backup rep on the next person's scenario** (1 rep × 2 defenders = 2 battles). Each person totals **12 battles**; each (defender, scenario) cell collects **6 reps** (5 from primary owner + 1 from the previous person as backup).

The backup rotation is round-robin so every scenario gets exactly 1 backup rep from a different person:

| Slot | Main scenario | Backup scenario | Battles | Side task | Total time |
|---|---|---|---|---|---|
| **Person 1 (Xiaoxuan)** | portfolioiq | thingularity | 10 + 2 = **12** | Write `scripts/tag_patterns.py` (~80 lines) | ~1.2 h compute + 3 h coding |
| **Person 2 (Qingdou)** | thingularity | gymjailbreak | 12 | Write `scripts/aggregate_benchmark.py` (~60 lines) | ~1.2 h compute + 2 h coding |
| **Person 3** | gymjailbreak | resume_downgrade | 12 | Qualitative analysis lead: collate everyone's hand-picked attack examples into `docs/qualitative_examples.md` | ~1.2 h compute + 3–4 h analysis |
| **Person 4 (Siqi)** | resume_downgrade | medical_records | 12 | Paper writing: methodology + related-work survey | ~1.2 h compute + 4 h writing |
| **Person 5 (Hui)** | medical_records | portfolioiq | 12 | Paper writing lead: abstract, intro, discussion, table-rendering scripts | ~1.2 h compute + 6 h writing |
| **Total** | | | **60 battles** = 6 reps per (defender, scenario) cell | | ~1.5 h parallel compute + side tasks |

Lambda cost: each person spins up their own A10 for ~1.2 h, runs their cell, terminates. About $0.90 per person, **~$5 total**.

The backup design protects against single-point-of-failure: if a person mis-configures vLLM and contaminates their 5 main reps on (e.g.) portfolioiq, the previous person's backup rep on portfolioiq survives, and the team can confirm the contamination by comparing the lone backup to the contaminated 5. Re-run only the affected slot.

Beyond their own side task, every collaborator does **battle-log analysis on their own main + backup scenarios** (12 battles total): read each round in the `battle_log.md` files, pick 2–3 representative attack rounds per pattern (a mix of successes and failures), and write a short paragraph per pick. Submit picks to Person 3 to collate into the appendix.

## Per-slot detail

Every collaborator runs the same compute pattern: their main scenario × both defenders × 5 reps = 10 battles, plus their backup scenario × both defenders × 1 rep = 2 battles. Total 12 battles per person.

### How to run your 12-battle cell

For your main scenario `<M>` and backup scenario `<B>`, run four batches back-to-back on a single Lambda instance:

```bash
# Main: 5 reps on each defender for your assigned scenario <M>
SCENARIOS="<M>" REPS=5 bash scripts/run_smoke.sh        # against Defender_x
SCENARIOS="<M>" REPS=5 bash scripts/run_smoke_dy.sh     # against Defender_y

# Backup: 1 rep on each defender for the next person's scenario <B>
SCENARIOS="<B>" REPS=1 OUTROOT="results/cross_smoke/A_qc_vs_D_x_backup" bash scripts/run_smoke.sh
SCENARIOS="<B>" REPS=1 OUTROOT="results/cross_smoke/A_qc_vs_D_y_backup" bash scripts/run_smoke_dy.sh
```

The `SCENARIOS` env var is a space-separated string (single scenario in this case), `REPS` is an int, `OUTROOT` overrides the default output directory so backup runs land in a separate folder. About 1.2 hours total compute for all four batches. Terminate the Lambda instance immediately after.

Output directory layout (the scripts handle this automatically):

```
results/cross_smoke/A_qc_vs_D_x/<M>_rep1...rep5/      ← main, Defender_x
results/cross_smoke/A_qc_vs_D_y/<M>_rep1...rep5/      ← main, Defender_y
results/cross_smoke/A_qc_vs_D_x_backup/<B>_rep1/      ← backup, Defender_x
results/cross_smoke/A_qc_vs_D_y_backup/<B>_rep1/      ← backup, Defender_y
```

Per battle, each `<scenario>_repN/` directory contains files the orchestrator writes automatically:
- `result.json` — battle outcome including `winner`, `manipulation_round`, full `battle_log` per round, crash counts. **A successful attack means `winner == "attacker"` in this file.**
- `battle_log.md` — human-readable transcript
- `battle_log.html` — rendered version of the same
- `attack_succeeded.json` — automatically written when the attacker wins; lists what was successfully extracted / manipulated
- `result.err` — only present if there were crashes; the error log

Drop a `RUN_INFO.md` at each of the four cell-root directories with: who ran it, when, model name, exact vLLM args, attacker commit hash, defender path used, anomalies noticed.

These directories ARE committed to git (the `.gitignore` excludes only `results/scratch/` and `results/tmp/`). Do `git add results/cross_smoke/` after your run to stage everything; commit and push to `paper-experiments`.

### Person 1 — portfolioiq + write `tag_patterns.py`

Compute: 10 battles on portfolioiq.

Side task: `scripts/tag_patterns.py` (~80 lines). Reads a `result.json`, runs each round's `attack_output` through five regex / heuristic detectors (OPF, CCBOS, RFCM, FA, MD — see `docs/scoring.md`), and adds a `patterns: [...]` list to each `battle_log` entry. Idempotent. Once written, run it against your own portfolioiq battle data first to sanity-check (portfolioiq rounds should mostly tag as OPF and MD).

### Person 2 — thingularity + write `aggregate_benchmark.py`

Compute: 10 battles on thingularity.

Side task: `scripts/aggregate_benchmark.py` (~60 lines). Reads the `results/` tree, computes Defender × Scenario ASR plus Pattern × Defender heatmap, writes markdown tables to `results/tables/` and a `benchmark_summary.json`. Verify on your own thingularity data first (thingularity rounds should mostly tag as CCBOS once long-context attacks fire).

### Person 3 — gymjailbreak + qualitative analysis lead

Compute: 10 battles on gymjailbreak.

Side task: as soon as the other four collaborators commit their `battle_log.md` files, collate everyone's hand-picked attack examples (each person picks 2–3 per pattern from their own scenario) into `docs/qualitative_examples.md`. The result is the paper's qualitative-examples appendix.

### Person 4 — resume_downgrade + paper methodology

Compute: 10 battles on resume_downgrade.

Side task: write the paper's Methodology section (including the disclosure paragraph quoted in `docs/benchmark_design.md`) and the Related Work survey. Both can be drafted in parallel with your compute.

### Person 5 — medical_records + paper writing lead

Compute: 10 battles on medical_records.

Side task: write the paper's Abstract, Intro, and Discussion. Build the table-rendering scripts. As results come in from all five collaborators, fill in the headline Defender × Scenario ASR table and the Pattern × Defender heatmap. Coordinate with Person 3 to incorporate the qualitative-examples appendix.

### Battle-log analysis (everyone)

After running their 10 battles, every collaborator reads each round in their own `battle_log.md` files and picks **2–3 representative attack rounds per pattern that appears in their scenario**, mixing successful breakthroughs and resisted attacks. For each pick, write a short paragraph: what the attack does, why it works or fails, and which defender it targeted. Submit picks to Person 3, who collates into `docs/qualitative_examples.md`.

Expect different scenarios to surface different patterns:
- portfolioiq → mostly OPF and MD
- thingularity → mostly CCBOS, some FA
- gymjailbreak → mostly FA (intensity tables) and OPF
- resume_downgrade → mostly OPF and RFCM
- medical_records → mostly FA


## Coordination items

1. **Branch**: all work goes on `paper-experiments`. No commits to `main`.
2. **Result directory naming**: handled by the run scripts via the `OUTROOT` env var. Default `results/cross_smoke/A_qc_vs_D_x/` for Defender_x main, `results/cross_smoke/A_qc_vs_D_y/` for Defender_y main; backups go to `..._backup/` (set explicitly via `OUTROOT=...` for the backup runs as shown above).
3. **Per-cell `RUN_INFO.md`**: at the root of each cell directory, a small markdown file noting model, vLLM args, max-model-len, attacker commit hash, defender commit hash, who ran it, when. Required for reproducibility.
4. **Execution order**: Person 1 first (tooling unblocks aggregation). Persons 2, 3, 4 in parallel after tooling lands. Person 5 starts paper writing in parallel from hour 0.
5. **API key hygiene**: every person uses their own Lambda API key, never shares it in chat or commits, and revokes it after their cell finishes.

## What to commit back when your cell is done

```
results/<cell-name>/
├── <scenario>_repN/
│   ├── result.json
│   ├── battle_log.md
│   └── battle_log.html
├── summary.json            (from aggregate_benchmark.py)
└── RUN_INFO.md
```

`RUN_INFO.md` contents: who ran it, date, model name + tag, exact vLLM args, attacker commit hash, defender commit hash, anomalies noticed (timeouts, crashes, etc.). Two paragraphs is plenty.
