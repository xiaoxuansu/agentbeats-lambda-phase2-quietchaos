# Running Latest Attacker vs Latest Defender with OpenAI API

This guide is for Linux. It runs the current strongest attacker harness against the current strongest defender using an official OpenAI API key.

The protocol here uses the same LLM endpoint for attacker, defender, and normal user. That matches the paper's deployment-facing setup: for each model row, only the shared model changes.

## What This Runs

- Attacker: `scenarios.security_arena.agents.attacker.agent`
- Defender: `scenarios.security_arena.agents.defender.agent`
- Runner: `scripts/run_smoke_dlatest.sh`
- Default scenarios:
  - `portfolioiq`
  - `thingularity`
  - `gymjailbreak`
  - `resume_downgrade`
  - `medical_records`

The script derives temporary TOML files from the existing `*_acq_vs_dx.toml` files, swaps in the latest defender module, and replaces the model argument for all three agents.

## 1. Configure OpenAI API

Create `.env`:

```bash
cp .env.example .env
nano .env
```

Set:

```bash
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_API_KEY=sk-...
```

Do not commit `.env`.

## 2. Verify Available Models

Check that the key works and list model IDs available to your account:

```bash
set -a
source .env
set +a

curl -s https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  | jq -r '.data[].id' | sort | grep -E 'gpt-5|gpt-oss'
```

As of 2026-05-03, the OpenAI model docs list `gpt-5.5` as the latest flagship model ID. Account access can vary, so use the exact ID returned by `/models`.

Reference: https://developers.openai.com/api/docs/models

## 3. First Cheap Smoke Test

Start with one medical-records run before launching a full sweep:

```bash
MODEL=gpt-5.5 \
SCENARIOS="medical_records" \
REPS=1 \
bash scripts/run_smoke_dlatest.sh
```

This writes to:

```text
results/cross_smoke/A_qc_vs_D_latest/medical_records_rep1/result.json
```

If `result.json` already exists, the runner skips that rep. Delete the specific rep directory if you intentionally want to rerun it.

## 4. Full Five-Scenario Run

For a full same-model run with 10 repetitions per scenario:

```bash
MODEL=gpt-5.5 \
REPS=10 \
OUTROOT="results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

This produces:

```text
results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest/<scenario>_rep<N>/result.json
```

Use a different `OUTROOT` for each model so results do not overwrite or skip each other.

## 5. Aggregate Results

After the run finishes:

```bash
python -X utf8 scripts/tag_patterns.py results/model_sweep/gpt_5_5/cross_smoke
python -X utf8 scripts/aggregate_benchmark.py results/model_sweep/gpt_5_5/cross_smoke
```

The aggregate script writes:

```text
results/model_sweep/gpt_5_5/benchmark_summary.json
results/model_sweep/gpt_5_5/tables/defender_scenario_asr.md
results/model_sweep/gpt_5_5/tables/pattern_defender_heatmap.md
```

## 6. Run Only One Scenario

For medical records with 10 runs:

```bash
MODEL=gpt-5.5 \
SCENARIOS="medical_records" \
REPS=10 \
OUTROOT="results/model_sweep/gpt_5_5_medical/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh

python -X utf8 scripts/tag_patterns.py results/model_sweep/gpt_5_5_medical/cross_smoke
python -X utf8 scripts/aggregate_benchmark.py results/model_sweep/gpt_5_5_medical/cross_smoke
```

## 7. Suggested Model Sweep Pattern

Run one model at a time. Start each model with `REPS=1`; then increase to `REPS=10` after it succeeds.

```bash
MODEL=gpt-5.5 \
REPS=1 \
OUTROOT="results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

For a second model, change both `MODEL` and `OUTROOT`:

```bash
MODEL=gpt-5.4-mini \
REPS=1 \
OUTROOT="results/model_sweep/gpt_5_4_mini/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

Keep the attacker, defender, scenarios, and repetition count fixed when comparing models. Otherwise the rows are not directly comparable.

## Troubleshooting

If the endpoint check fails:

```bash
curl -i https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

Common causes:

- `OPENAI_API_KEY` is not exported or `.env` was not sourced.
- The key has no access to the requested model.
- `MODEL` is not the exact API model ID.
- The run is expensive or slow because `REPS` is high; use `REPS=1` first.

If a run fails mid-way, inspect the specific output directory and rerun. Existing successful `result.json` files are skipped automatically.
