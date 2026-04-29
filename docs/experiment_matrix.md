# Paper-Level Experiment Matrix Design

This document defines the full experiment matrix needed for a publishable paper on the AgentBeats Security Arena results, beyond the official competition output.

The matrix is organized under **QC-Benchmark v1** (see `docs/benchmark_design.md`). The attacker is held fixed at Attacker_quietchaos v23; defenders are the variable being scored. The **MVE that ships with the paper** is a strict subset of the cells listed here — see `docs/task_assignment.md` for the 5-person work split. Cells listed below but not in the MVE are deferred to QC-Benchmark v2.

---

## 1. Independent Variables

| Var | Levels | Why |
|---|---|---|
| **Attacker team** | Attacker_quietchaos (our final, v23) / Attacker_siqi (cross-team baseline) | Test our attacker is portable, not just over-fit to our defender |
| **Defender team** | Defender_quietchaos (our final, v32) / Defender_siqi (cross-team baseline) | Same — defender portability |
| **Scenarios** | 5 public + 5 custom (ours) — supplemented with 5 newly designed "hard" scenarios if needed | Generalization claims; over-fit detection. Private/held-out scenarios from the competition are not accessible. |
| **Model** | gpt-oss-20b (competition default) / gpt-oss-120b / one cross-family | Show results aren't model-specific |
| **Reps per cell** | ≥ 5 (paper-grade), ≥ 10 if compute allows | Sample variance is large in 7-round battles |
| **Defender version (ablation)** | full / no Pass 3 / no Python sanitization / no Pass 4 regen | Identify which defense layer carries weight (deferred to v2) |

Note: attacker-version ablation was originally listed here but was dropped during planning. The benchmark holds the attacker fixed at v23; ablation of the attacker would be a separate research question and is not part of QC-Benchmark v1.

---

## 2. Dependent Variables (Metrics)

- **ASR** (Attack Success Rate): `attacker_wins / total_battles`
- **Manipulation Round** (median, when attacker wins): how fast does attacker break in
- **Normal-user PASS** (binary per scenario): defender helpfulness — must be PASS for ranking validity
- **Defender output length / refusal rate**: proxy for over-defense
- **Compute cost per battle**: # LLM calls × tokens × $/token

---

## 3. The Matrix (full grid)

### 3.1 Core cross-team battles (P0)

| | Defender_quietchaos | Defender_siqi |
|---|---|---|
| **Attacker_quietchaos** | self-battle (baseline) | already in progress |
| **Attacker_siqi** | reverse cross-battle (P0 missing) | self-battle (baseline) |

Per cell: 5 public scenarios × ≥5 reps = **25 battles**.
Total: 4 cells × 25 = **100 battles** (lower bound).

### 3.2 Scenario expansion (P1)

Run each of the 4 cells above on additional scenarios:

| Scenario set (in MVE v1) | Source | Rationale |
|---|---|---|
| 5 public | leaderboard set | Continuity with public ranking; covers indirect_injection / prompt_extraction / insecure_output / pii_leak |
| 1 custom: `automate_safety` | already in repo | Adds the missing primary-jailbreak category. Brings coverage to 5 of 6 competition categories. |

So 6 scenarios × 5 reps × N defenders. For the v1 MVE, N = 4 headline defenders + 2 calibration cells; see `docs/task_assignment.md` for the per-person split.

Additional in-repo custom scenarios (`airline_pii`, `safety_override`, `secret_keeper`, `healthtrack_hack`, `moneymate_mayhem`) duplicate categories already covered by the 6 above and are deferred to v2.

### 3.3 Normal-user (helpfulness) sweep (P0)

For every defender in {Defender_quietchaos, Defender_siqi, Defender_quietchaos-ablations} × every scenario set:
- Run `--normal-user` mode (no attacker, just helpfulness probes from `normal_user.topics`)
- Record per-scenario PASS/FAIL
- Required: defender PASSES on every scenario it claims to defend, otherwise the battle wins are deployment-invalid

Total: 3-5 defenders × 10–15 scenarios × 1 = **~50–75 normal-user runs**.

### 3.4 Ablation (deferred to QC-Benchmark v2)

The attacker-version ablation is not part of the v1 plan (the attacker is the benchmark's fixed reference; ablating it is a separate question).

The defender-layer ablation remains the strongest candidate to add when v1's data is in:

| Ablation | Cells | Battles |
|---|---|---|
| **Defender_quietchaos full → -Pass3 → -Sanit → -Pass4** | 4 variants × Attacker_quietchaos × 6 scenarios × 5 reps | 120 |

### 3.5 Model generalization (P2, strengthens claim)

Re-run a strategic subset (say 5 public × 2 reps × 4 cross-team cells = 40 battles) on:
- **gpt-oss-120b** — same family, larger
- **Llama-3.1-70B-Instruct** — different family, frontier-class
- (optional) **Qwen2.5-72B-Instruct** or **DeepSeek-V3** — third family

Compute: 3 alt models × 40 battles = **120 battles**.

Why: the paper's claim "this defense pipeline is robust" needs evidence beyond a single 20B model.

### 3.6 External baselines (P1, paper-required)

The paper needs to compare against published red/blue-team baselines:

**Defender baselines** (run as D_baseline_*):
- `D_vanilla` — no defense, just system prompt that says the role
- `D_simple` — system prompt with "refuse harmful requests"
- `D_smoothllm` — input perturbation defense (paper baseline)
- `D_perplexity` — perplexity-filtered input

**Attacker baselines** (run as A_baseline_*):
- `A_pair` — PAIR (Chao et al.)
- `A_gcg` — GCG (Zou et al.) suffix attack
- `A_autodan` — AutoDAN

Per matrix cell: external baselines × {Attacker_quietchaos, Defender_quietchaos} × 5 public × 3 reps ≈ **210 battles**.

---

## 4. Total Compute Estimate (full grid, aspirational)

| Group | Battles | Wall time @ 5 min/battle | Lambda cost @ $0.75/h |
|---|---|---|---|
| 3.1 Core cross-team | 100 | ~8 h | ~$6 |
| 3.2 Scenario expansion | 1200 | ~100 h | ~$75 |
| 3.3 Normal-user | 75 | ~4 h | ~$3 |
| 3.4 Ablation | 120 | ~10 h | ~$8 |
| 3.5 Model generalization | 120 | ~10 h | ~$8 |
| 3.6 External baselines | 210 | ~17 h | ~$13 |
| **Total** | **~1825 battles** | **~150 h** | **~$115** |

Parallelism: each collaborator runs their own Lambda A10. With 5 instances in parallel, full-grid wall time drops to ~30 h.

---

## 5. Minimum Viable Experiment (MVE) — what ships in QC-Benchmark v1

The MVE is locked in for the 2-day arXiv / workshop submission. See `docs/task_assignment.md` for the per-person split.

| Section | What | Battles |
|---|---|---|
| Headline benchmark cells | Attacker_quietchaos × {D-vanilla, D-simple, Defender_quietchaos, Defender_siqi} × 6 scenarios × 5 reps | 120 |
| Cross-team calibration | Attacker_siqi × {Defender_quietchaos, Defender_siqi} × 6 scenarios × 5 reps | 60 |
| Helpfulness gate | 4 defenders × 6 scenarios × 1 normal_user run | 24 (light) |
| Phase A re-clean | Already counted under headline cells (Attacker_quietchaos × Defender_siqi runs as part of the headline at 5 reps with `--max-model-len 16384`) | — |
| **MVE total** | | **180 battles + 24 helpfulness runs** |

MVE wall time: ~5 h with 5 instances in parallel. Cost: ~$13 across all collaborators combined.

Items deferred to QC-Benchmark v2: external attacker baselines (PAIR / GCG / AutoDAN), `Other Team/agents 2/defender/`, defender-layer ablation, gpt-oss-120b, cross-family models, supply_chain scenario, 10-rep tightening.

---

## 6. Open Questions

1. **Do we need extra "hard" scenarios beyond the 10 we already have (5 public + 5 custom)?** Decide after Phase B Group 1 + 2 results — if the 5 custom set turns out to overlap too much with public in attack-vector coverage, the team designs 5 new ones with disjoint vectors.
2. **Is `Defender_siqi` from team rank 2, 3, …, 6, or unknown?** Affects how we frame the comparison. If from rank 6 (as suggested), our story is "even rank-6 defender resists v23 attacker on public, validating our concern about over-fit to public."
3. **Should we test on alternate model families (Claude / Gemini)?** Costs more, but strengthens generalization. Decide before MVE finalized.
4. **External baseline ASR numbers** — do we re-run them locally or cite published numbers? Local is fairer (same model, same prompts) but costlier.
