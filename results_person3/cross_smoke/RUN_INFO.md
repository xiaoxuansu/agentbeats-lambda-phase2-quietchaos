# Run Info — Cross-Battle Cell A_qc (Phase 2)

| Field              | Value |
|--------------------|-------|
| Date               | 2026-05-01 |
| Runner             | gryffindoraf |
| Repo branch        | paper-experiments |

## Model & Inference

| Field              | Value |
|--------------------|-------|
| Model              | `openai/gpt-oss-20b` |
| Serving framework  | vLLM (Docker `vllm/vllm-openai:latest`) |
| vLLM args          | `--gpu-memory-utilization 0.85 --max-model-len 16384` |
| max_model_len      | 16384 |
| GPU                | Lambda Cloud, 1× A10 (24 GB), IP `129.80.73.45` |

## Agent Versions

| Role        | Agent name                  | Commit hash |
|-------------|-----------------------------|-------------|
| Attacker    | `attacker_quietchaos_v23`   | `342bed6`   |
| Defender_x  | `quietchaos_v4_defender`    | `c9ce039`   |
| Defender_y  | `team_y_defender`           | unknown (cross-team submission, ~206 lines, no hash recorded) |

## Scenarios Run

| Cell dir             | Scenario          | Reps | Notes |
|----------------------|-------------------|------|-------|
| A_qc_vs_D_x          | gymjailbreak      | 5    | main  |
| A_qc_vs_D_y          | gymjailbreak      | 5    | main  |
| A_qc_vs_D_x_backup   | resume_downgrade  | 1    | backup |
| A_qc_vs_D_y_backup   | resume_downgrade  | 1    | backup |
