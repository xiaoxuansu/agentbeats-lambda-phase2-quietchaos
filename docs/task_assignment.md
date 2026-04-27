# Phase B — Task Assignment (5 people)

This is the working split for the Phase B paper experiments. Each person is responsible for one cell of the experimental matrix plus a small auxiliary task. Names are placeholders — claim a slot in our group chat. The first run uses MVE-level reps; we expand later only if results require it.

## Naming convention used in the assignment

- **Attacker_quietchaos**: our team's attacker (final v23, commit `e8386d1`).
- **Defender_quietchaos**: our team's defender (final v23).
- **Attacker_siqi**: the other team's attacker (placeholder name; their team identity is not yet confirmed).
- **Defender_siqi**: the other team's defender (the 433-line, 4-pass pipeline copied to `scenarios/security_arena/agents/team_x_defender/`).

The 5 public scenarios referenced throughout: portfolioiq, thingularity, gymjailbreak, resume_downgrade, medical_records.

---

## Assignment table

| Slot | Task | Battles / Tests | Compute | Cost |
|---|---|---|---|---|
| **Person 1** | Phase A clean-up + helpfulness sweep | Re-run thingularity × 2 with `--max-model-len 16384`; Defender_siqi normal_user × 5 scenarios; Defender_quietchaos normal_user × 5 scenarios | ~1.5 h | ~$1 |
| **Person 2** | Reverse cross-battle | Attacker_siqi × Defender_quietchaos × 5 public × 5 reps = **25 battles** | ~2 h | ~$2 |
| **Person 3** | Self-baselines | Attacker_quietchaos × Defender_quietchaos × 5 × 5 + Attacker_siqi × Defender_siqi × 5 × 5 = **50 battles** | ~4 h | ~$3 |
| **Person 4** | Attacker version ablation | Attacker_quietchaos v23 vs v22 (vs v21 if time) × Defender_siqi × 5 public × 5 reps = **50 battles** | ~4 h | ~$3 |
| **Person 5** | Scenario expansion + 1 external baseline | 4 cross-team cells × 5 custom scenarios × 3 reps + 1 external attacker (PAIR) × Defender_quietchaos × 5 public × 3 reps = **75 battles** | ~5 h | ~$4 |
| **Total** | | ~200 battles + 10 helpfulness runs | ~16 h sequential / ~5 h parallel | ~$13 |

---

## Detailed responsibilities per slot

### Person 1 — Phase A clean-up and helpfulness sweep

Person 1 inherits the work-in-progress from the Phase A pilot (already ran the Attacker_quietchaos × Defender_siqi cell with too-small context window). The deliverables are: re-run the contaminated thingularity battles with `--max-model-len 16384` so the cell is reportable; run the binary normal-user (helpfulness) check on Defender_siqi for all 5 public scenarios — recall that this is an absolute pass/fail, not a comparative metric; and run the same normal-user check on Defender_quietchaos as a sanity check on our own defender. After the other four people commit their results, Person 1 also produces the cross-cell comparison tables for the paper (this is mostly markdown / pandas, not compute-bound).

### Person 2 — Reverse cross-battle (Attacker_siqi × Defender_quietchaos)

Person 2 fills the symmetric cell to the Phase A pilot. Adapt `scripts/run_smoke.sh` by swapping the agent module paths: in the cross-battle TOMLs, set the defender to point at our `agents/defender/` (Defender_quietchaos) and the attacker to point at `agents/team_x_attacker/` (Attacker_siqi). Keep the SCENARIOS list the same and bump REPS from 2 to 5. The expected result is that Attacker_siqi rarely wins against Defender_quietchaos (Defender_quietchaos public ASR-against was 81.1% on the leaderboard). Even confirming that expectation is paper-grade evidence.

### Person 3 — Self-baselines (Attacker_quietchaos × Defender_quietchaos and Attacker_siqi × Defender_siqi)

Person 3 runs both teams' self-battles. These calibrate every cross-team number we report. If Attacker_siqi can't beat its own Defender_siqi, that helps explain why Defender_siqi swept the Phase A pilot — the attacker is weak, not the defender uniquely strong. Conversely, if Attacker_quietchaos beats Defender_quietchaos, that's evidence Attacker_quietchaos is genuinely strong (and its 0/6 against Defender_siqi reflects Defender_siqi's actual hardness, not our attacker's weakness).

### Person 4 — Attacker version ablation

Person 4 quantifies how much each successive attacker iteration moved ASR. Check out the relevant earlier commits — v23 = `e8386d1`, v22 ≈ `e8e7576` or `1beefaf` (use `git log --grep="submit-attacker"` to confirm), and v21 = an even earlier commit on the same lineage — and re-run Attacker_quietchaos × Defender_siqi × 5 public × 5 reps for each version. The recommendation is to start with just v23 vs v22 (50 battles) and only add v21 if the v23-v22 delta is small, since the delta of interest will inform whether earlier ablation is needed.

### Person 5 — Scenario expansion + one external baseline

Person 5 carries the heaviest cell, but it's also the one that contributes the most to the paper's headline claim. The scenario-expansion half runs all four cross-team cells on the 5 custom scenarios already in the repo (automate_safety, airline_pii, safety_override, secret_keeper, healthtrack_hack) at 3 reps each — 60 battles. This shows our claims are not specific to the public 5. The external-baseline half runs one published red-team attack (PAIR is the simplest to integrate; see github.com/RICommunity/PAIR) against Defender_quietchaos on the 5 public scenarios at 3 reps — 15 battles. This gives the paper a comparison point against published work.

---

## Coordination items (decide before anyone starts)

1. **Branch**: all Phase B work goes on `paper-experiments`. No commits to `main`.
2. **Result directory naming**: `results/phaseB_<cell-name>/<scenario>_repN/`. Example: `results/phaseB_Attacker_siqi_vs_Defender_quietchaos/portfolioiq_rep1/`.
3. **Per-cell `RUN_INFO.md`**: at the root of each cell directory, drop a small markdown file noting the model, vLLM args, max-model-len, attacker commit hash, defender commit hash. This is what makes the paper reproducible.
4. **Execution order**: Person 1 first (the helpfulness check shapes the paper's framing). Person 2 and Person 3 in parallel (low coordination cost). Person 4 and Person 5 after, since they benefit from seeing Person 2 and 3's findings before deciding how deep to go.
5. **Private scenarios**: Person 1 (or whoever has the contact) should email the host to ask whether the 5 private scenarios from the leaderboard can be released for reproducibility. If no, the team designs 5 new "hard" scenarios collectively before Person 5 starts the scenario expansion.
6. **API key hygiene**: every person uses their own Lambda API key, never shares it in chat or commits, and revokes it after their cell finishes.

---

## What to commit back when your cell is done

For each cell, push a directory tree like:

```
results/phaseB_<cell-name>/
├── <scenario>_repN/
│   ├── result.json         (mandatory)
│   ├── battle_log.md       (mandatory; for human inspection)
│   └── battle_log.html     (mandatory)
├── summary.json            (mandatory; from aggregate_smoke.py)
└── RUN_INFO.md             (mandatory)
```

`RUN_INFO.md` should include at minimum: who ran it, when (date), the model name + tag, the exact vLLM args used, the attacker code commit hash, the defender code commit hash, and any anomalies you noticed (timeouts, crashes, etc.). Two paragraphs is plenty.
