# Paper-Level Experiment Matrix Design

This document defines the full experiment matrix needed for a publishable paper on the AgentBeats Security Arena results, beyond the official competition output.

---

## 1. Independent Variables

| Var | Levels | Why |
|---|---|---|
| **Attacker team** | Attacker_quietchaos (Quiet Chaos v23) / Attacker_siqi (Other Team) | Test our attacker is portable, not just over-fit to our defender |
| **Defender team** | Defender_quietchaos (Quiet Chaos v23) / Defender_siqi (Other Team, 433-line) | Same — defender portability |
| **Scenarios** | 5 public / 5 custom (ours) / 5 private (held-out, if accessible) | Generalization claims; over-fit detection |
| **Model** | gpt-oss-20b (competition default) / gpt-oss-120b / one cross-family | Show results aren't model-specific |
| **Reps per cell** | ≥ 5 (paper-grade), ≥ 10 if compute allows | Sample variance is large in 7-round battles |
| **Attacker version (ablation)** | v23 (final) / v21 (pre-FITD/StegoAttack) / v19 (pre-leaked-info) | Show which v23 additions actually moved ASR |
| **Defender version (ablation)** | full / no Pass 3 / no Python sanitization / no Pass 4 regen | Identify which defense layer carries weight |

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

| Scenario set | Source | Rationale |
|---|---|---|
| 5 public | leaderboard set | Continuity with public ranking |
| 5 custom (ours) | `scenario_automate_safety.toml`, `scenario_airline_pii.toml`, `scenario_safety_override.toml`, `scenario_secret_keeper.toml`, `scenario_healthtrack_hack.toml` (or similar) | Show defenses generalize beyond public |
| 5 private (held-out) | If we can recover them, otherwise design 5 new ones with different attack vector mix (PII, jailbreak, tool-extraction, ranking-tamper, format-lock) | The actual leaderboard rationale; central paper claim |

Per cell × 15 scenarios × 5 reps = **300 battles** per cell × 4 cells = **1200 battles**.

### 3.3 Normal-user (helpfulness) sweep (P0)

For every defender in {Defender_quietchaos, Defender_siqi, Defender_quietchaos-ablations} × every scenario set:
- Run `--normal-user` mode (no attacker, just helpfulness probes from `normal_user.topics`)
- Record per-scenario PASS/FAIL
- Required: defender PASSES on every scenario it claims to defend, otherwise the battle wins are deployment-invalid

Total: 3-5 defenders × 15 scenarios × 1 = **~75 normal-user runs**.

### 3.4 Ablation (P1, paper-required)

| Ablation | Cells | Battles |
|---|---|---|
| **Attacker v23 → v21 → v19** | 3 versions × Defender_siqi × 5 public × 5 reps | 75 |
| **Defender Defender_quietchaos full → -Pass3 → -Sanit → -Pass4** | 4 variants × Attacker_siqi × 5 public × 5 reps | 100 |
| Sub-total | | **175** |

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

## 4. Total Compute Estimate

| Group | Battles | Wall time @ 5 min/battle | Lambda cost @ $0.75/h |
|---|---|---|---|
| 3.1 Core cross-team | 100 | ~8 h | ~$6 |
| 3.2 Scenario expansion | 1200 | ~100 h | ~$75 |
| 3.3 Normal-user | 75 | ~4 h | ~$3 |
| 3.4 Ablation | 175 | ~15 h | ~$12 |
| 3.5 Model generalization | 120 | ~10 h | ~$8 |
| 3.6 External baselines | 210 | ~17 h | ~$13 |
| **Total** | **~1880 battles** | **~155 h** | **~$120** |

Per teammate budget: ~$30 (split 4 ways).

Parallelism: each teammate runs their own Lambda A10. With 4 instances in parallel, wall time drops to ~40h.

---

## 5. Minimum Viable Experiment (MVE) for first paper draft

If compute is tight, the absolute minimum to make a paper claim:

| Section | What | Battles |
|---|---|---|
| Core | 4 cells (A×D) × 5 public × 3 reps | 60 |
| Generalization | Same 4 cells × 5 custom × 2 reps | 40 |
| Helpfulness | All defenders × 10 scenarios | 30 |
| Ablation light | 2 attacker versions, 2 defender variants × Attacker_siqi × 5 public × 3 reps | 30 |
| 1 alt model | 4 cells × 5 public × 2 reps on gpt-oss-120b | 40 |
| **MVE total** | | **~200 battles** |

MVE wall time: ~17 h, cost ~$13.

---

## 6. Open Questions

1. **Can we get the 5 private scenarios?** If host released them, fetch. Otherwise, design 5 new "hard" scenarios with disjoint attack vectors.
2. **Is `Defender_siqi` from team rank 2, 3, …, 6, or unknown?** Affects how we frame the comparison. If from rank 6 (as suggested), our story is "even rank-6 defender resists v23 attacker on public, validating our concern about over-fit to public."
3. **Should we test on alternate model families (Claude / Gemini)?** Costs more, but strengthens generalization. Decide before MVE finalized.
4. **External baseline ASR numbers** — do we re-run them locally or cite published numbers? Local is fairer (same model, same prompts) but costlier.
