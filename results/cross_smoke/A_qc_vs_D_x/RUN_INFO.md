# RUN_INFO

- **Person**: 1 (xiaoxuansu)
- **When**: 2026-04-30 (00:22 - 02:04 local time, ~102 min wall clock)
- **Cell type**: main
- **Defender**: `scenarios/security_arena/agents/quietchaos_v4_defender/`
- **Hardware**: 1× A10 (24 GB) on Lambda Cloud, us-west-1, instance `d32870e50081418989966d7f45ccebca`
- **Model**: openai/gpt-oss-20b (vLLM v0.x in Docker)
- **vLLM args**: `--gpu-memory-utilization 0.85 --max-model-len 16384`
- **Attacker**: `scenarios/security_arena/agents/attacker/`, repo HEAD at run time = `05ed37c` on branch `paper-experiments`
- **Run script**: `scripts/run_smoke.sh` (Defender_x) or `scripts/run_smoke_dy.sh` (Defender_y)
- **Anomalies**: none — 0 attacker_crash_errors and 0 defender_crash_errors across all battles in this cell. Full 7 rounds completed for every rep that did not produce an early manipulation.

---

## Person 2 (Sarah) — thingularity main, 5 reps

- **When**: 2026-04-30 (~ 23:54 PDT 2026-04-29 → 01:43 PDT 2026-04-30 local time, including a forced redeploy mid-run)
- **Hardware**: 1× A10 24 GB on Lambda Cloud, us-west-1
  - `thingularity_rep1` produced on instance `159.54.190.192`
  - `thingularity_rep2..rep5` produced on a fresh instance `146.235.195.58` (id `687a190551834cf8a06e13de19871ba4`)
- **Model / vLLM args**: same as above (`openai/gpt-oss-20b`, `--gpu-memory-utilization 0.85 --max-model-len 16384`)
- **Attacker**: `attacker_quietchaos_v23` (commit `e8386d1` per docs; current paper-experiments HEAD at run = `8841af0`)
- **Anomalies**: a custom firewall ruleset change between `rep1` and `rep2` made the original instance's vLLM endpoint temporarily unreachable from the runner laptop, contaminating two interim reps with `defender_crash_errors > 0`. Those contaminated reps were deleted before commit. The committed `thingularity_rep1` is from the original instance (clean: `attacker_crash_errors=0, defender_crash_errors=0`); reps 2–5 are from the fresh instance, also clean. Both instances ran identical model + vLLM args.
