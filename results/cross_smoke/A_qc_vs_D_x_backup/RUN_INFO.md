# RUN_INFO

- **Person**: 1 (xiaoxuansu)
- **When**: 2026-04-30 (00:22 - 02:04 local time, ~102 min wall clock)
- **Cell type**: backup (1 rep)
- **Defender**: `scenarios/security_arena/agents/quietchaos_v4_defender/`
- **Hardware**: 1× A10 (24 GB) on Lambda Cloud, us-west-1, instance `d32870e50081418989966d7f45ccebca`
- **Model**: openai/gpt-oss-20b (vLLM v0.x in Docker)
- **vLLM args**: `--gpu-memory-utilization 0.85 --max-model-len 16384`
- **Attacker**: `scenarios/security_arena/agents/attacker/`, repo HEAD at run time = `05ed37c` on branch `paper-experiments`
- **Run script**: `scripts/run_smoke.sh` (Defender_x) or `scripts/run_smoke_dy.sh` (Defender_y)
- **Anomalies**: none — 0 attacker_crash_errors and 0 defender_crash_errors across all battles in this cell. Full 7 rounds completed for every rep that did not produce an early manipulation.
