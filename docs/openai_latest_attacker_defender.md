# Running Latest Attacker vs Latest Defender with OpenAI API

This guide is for Linux and Windows. It runs the current strongest attacker harness against the current strongest defender using an official OpenAI API key.

The protocol here uses the same LLM endpoint for attacker, defender, and normal user. That matches the paper's deployment-facing setup: for each model row, only the shared model changes.

## 0. Install `uv`

The runners use `uv run agentbeats-run`, so install `uv` before running experiments.

Linux or Git Bash:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"
uv --version
uv sync
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
$env:Path = "$HOME\.local\bin;$env:Path"
uv --version
uv sync
```

If `uv` is still not found on Windows, close and reopen PowerShell, then run:

```powershell
uv --version
uv sync
```

Alternative Windows install methods:

```powershell
winget install --id=astral-sh.uv -e
```

or:

```powershell
python -m pip install --user uv
```

Do not run `curl ... | sh && source ~/.profile` in Windows PowerShell. That is a Bash command. Windows PowerShell 5 does not support `&&` as a command separator, and `source` is not a PowerShell command.

## What This Runs

- Attacker: `scenarios.security_arena.agents.attacker.agent`
- Defender: `scenarios.security_arena.agents.defender.agent`
- Linux/Git Bash runner: `scripts/run_smoke_dlatest.sh`
- Windows PowerShell runner: `scripts/run_smoke_dlatest.ps1`
- Default scenarios:
  - `portfolioiq`
  - `thingularity`
  - `gymjailbreak`
  - `resume_downgrade`
  - `medical_records`

The script derives temporary TOML files from the existing `*_acq_vs_dx.toml` files, swaps in the latest defender module, and replaces the model argument for all three agents.

## 1. Configure OpenAI API

On Linux or Git Bash, create `.env`:

```bash
cp .env.example .env
nano .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
notepad .env
```

Set:

```bash
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_API_KEY=sk-...
```

Do not commit `.env`.

### Optional: Mixed Providers

The runners accept OpenAI-compatible endpoints per role. Keep `OPENAI_BASE_URL` and `OPENAI_API_KEY` as the shared fallback, then add role-specific overrides only where a role should use a different provider. Use the exact model IDs returned by the provider you are calling.

Example A: all roles use OpenRouter, but each role can use a different OpenRouter model.

```bash
OPENAI_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=sk-or-...
```

Linux or Git Bash:

```bash
ATTACKER_MODEL="anthropic/claude-3.5-sonnet" \
DEFENDER_MODEL="openai/gpt-5.5" \
NORMAL_USER_MODEL="openai/gpt-5.5" \
SCENARIOS="medical_records" \
REPS=1 \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:ATTACKER_MODEL = "anthropic/claude-3.5-sonnet"
$env:DEFENDER_MODEL = "openai/gpt-5.5"
$env:NORMAL_USER_MODEL = "openai/gpt-5.5"
$env:SCENARIOS = "medical_records"
$env:SHOW_LOGS = "1" 
$env:REPS = "1"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
```

Example B: attacker uses OpenRouter, while defender and normal user use the official OpenAI API.

```bash
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_API_KEY=sk-...
ATTACKER_OPENAI_BASE_URL=https://openrouter.ai/api/v1
ATTACKER_OPENAI_API_KEY=sk-or-...
```

Linux or Git Bash:

```bash
ATTACKER_MODEL="anthropic/claude-3.5-sonnet" \
DEFENDER_MODEL="gpt-5.5" \
NORMAL_USER_MODEL="gpt-5.5" \
SCENARIOS="medical_records" \
REPS=1 \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:ATTACKER_OPENAI_BASE_URL = "https://openrouter.ai/api/v1"
$env:ATTACKER_OPENAI_API_KEY = "sk-or-..."
$env:ATTACKER_MODEL = "anthropic/claude-3.5-sonnet"
$env:DEFENDER_MODEL = "gpt-5.5"
$env:NORMAL_USER_MODEL = "gpt-5.5"
$env:SCENARIOS = "medical_records"
$env:SHOW_LOGS = "1" 
$env:REPS = "1"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
```

The generated temporary TOMLs reference variables such as `${ATTACKER_OPENAI_API_KEY}` and do not write raw API keys into the scenario files.

## 2. Verify Available Models

On Linux or Git Bash, check that the key works and list model IDs available to your account:

```bash
set -a
source .env
set +a

curl -s https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  | jq -r '.data[].id' | sort | grep -E 'gpt-5|gpt-oss'
```

On Windows PowerShell:

```powershell
$OpenAIKey = (Get-Content .env | Where-Object { $_ -match '^OPENAI_API_KEY=' }) -replace '^OPENAI_API_KEY=', ''
$Headers = @{ Authorization = "Bearer $OpenAIKey" }
(Invoke-RestMethod -Uri "https://api.openai.com/v1/models" -Headers $Headers).data.id |
  Sort-Object |
  Select-String "gpt-5|gpt-oss"
```

As of 2026-05-03, the OpenAI model docs list `gpt-5.5` as the latest flagship model ID. Account access can vary, so use the exact ID returned by `/models`.

Reference: https://developers.openai.com/api/docs/models

## 3. First Cheap Smoke Test

Start with one medical-records run before launching a full sweep.

Linux or Git Bash:

```bash
MODEL=gpt-5.5 \
SCENARIOS="medical_records" \
REPS=1 \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:MODEL = "gpt-5.5"
$env:SCENARIOS = "medical_records"
$env:REPS = "1"
$env:SHOW_LOGS = "1"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:SCENARIOS, Env:REPS -ErrorAction SilentlyContinue
```

This writes to:

```text
results/cross_smoke/A_qc_vs_D_latest/medical_records_rep1/result.json
```

If `result.json` already exists, the runner skips that rep. Delete the specific rep directory if you intentionally want to rerun it.

## 4. Full Five-Scenario Run

For a full same-model run with 10 repetitions per scenario.

Linux or Git Bash:

```bash
MODEL=gpt-5.5 \
REPS=10 \
OUTROOT="results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:MODEL = "gpt-5.5"
$env:REPS = "10"
$env:SHOW_LOGS = "1" 
$env:OUTROOT = "results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:REPS, Env:OUTROOT -ErrorAction SilentlyContinue
```

This produces:

```text
results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest/<scenario>_rep<N>/result.json
```

Use a different `OUTROOT` for each model so results do not overwrite or skip each other.

## 5. Aggregate Results

After the run finishes.

Linux, Git Bash, or Windows PowerShell:

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

For medical records with 10 runs.

Linux or Git Bash:

```bash
MODEL=gpt-5.5 \
SCENARIOS="medical_records" \
REPS=10 \
OUTROOT="results/model_sweep/gpt_5_5_medical/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh

python -X utf8 scripts/tag_patterns.py results/model_sweep/gpt_5_5_medical/cross_smoke
python -X utf8 scripts/aggregate_benchmark.py results/model_sweep/gpt_5_5_medical/cross_smoke
```

Windows PowerShell:

```powershell
$env:MODEL = "gpt-5.5"
$env:SCENARIOS = "medical_records"
$env:REPS = "10"
$env:SHOW_LOGS = "1" 
$env:OUTROOT = "results/model_sweep/gpt_5_5_medical/cross_smoke/A_qc_vs_D_latest"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:SCENARIOS, Env:REPS, Env:OUTROOT -ErrorAction SilentlyContinue

python -X utf8 scripts/tag_patterns.py results/model_sweep/gpt_5_5_medical/cross_smoke
python -X utf8 scripts/aggregate_benchmark.py results/model_sweep/gpt_5_5_medical/cross_smoke
```

## 7. Suggested Model Sweep Pattern

Run one model at a time. Start each model with `REPS=1`; then increase to `REPS=10` after it succeeds.

Linux or Git Bash:

```bash
MODEL=gpt-5.5 \
REPS=1 \
OUTROOT="results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:MODEL = "gpt-5.5"
$env:REPS = "1"
$env:SHOW_LOGS = "1" 
$env:OUTROOT = "results/model_sweep/gpt_5_5/cross_smoke/A_qc_vs_D_latest"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:REPS, Env:OUTROOT -ErrorAction SilentlyContinue
```

For a second model, change both `MODEL` and `OUTROOT`:

Linux or Git Bash:

```bash
MODEL=gpt-5.4-mini \
REPS=1 \
OUTROOT="results/model_sweep/gpt_5_4_mini/cross_smoke/A_qc_vs_D_latest" \
bash scripts/run_smoke_dlatest.sh
```

Windows PowerShell:

```powershell
$env:MODEL = "gpt-5.4-mini"
$env:REPS = "1"
$env:SHOW_LOGS = "1" 
$env:OUTROOT = "results/model_sweep/gpt_5_4_mini/cross_smoke/A_qc_vs_D_latest"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:REPS, Env:OUTROOT -ErrorAction SilentlyContinue
```

Keep the attacker, defender, scenarios, and repetition count fixed when comparing models. Otherwise the rows are not directly comparable.

## Windows Notes

Use `scripts/run_smoke_dlatest.ps1` from PowerShell. Do not call `bash scripts/run_smoke_dlatest.sh` unless you intentionally installed Git Bash or WSL and know that `bash` points to that shell.

If PowerShell blocks script execution, use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
```

If you see an error like `execvpe(/bin/bash) failed`, Windows is launching the WSL `bash` shim and WSL is not configured with `/bin/bash`. The native `.ps1` runner avoids that dependency.

The Windows runner waits 90 seconds for the four agent servers to start. To increase this:

```powershell
$env:STARTUP_TIMEOUT = "180"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:STARTUP_TIMEOUT -ErrorAction SilentlyContinue
```

To see child-agent startup logs when debugging readiness failures:

```powershell
$env:SHOW_LOGS = "1"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:SHOW_LOGS -ErrorAction SilentlyContinue
```

## Troubleshooting

If the endpoint check fails:

```bash
curl -i https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

Windows PowerShell equivalent:

```powershell
$OpenAIKey = (Get-Content .env | Where-Object { $_ -match '^OPENAI_API_KEY=' }) -replace '^OPENAI_API_KEY=', ''
Invoke-WebRequest -Uri "https://api.openai.com/v1/models" -Headers @{ Authorization = "Bearer $OpenAIKey" }
```

Common causes:

- `OPENAI_API_KEY` is not exported or `.env` was not sourced.
- The key has no access to the requested model.
- `MODEL` is not the exact API model ID.
- The run is expensive or slow because `REPS` is high; use `REPS=1` first.

If Windows PowerShell prints a `uv` warning about `tool.uv.dev-dependencies`, it is only a dependency metadata warning from `pyproject.toml`. It is not an OpenAI or AgentBeats failure. The PowerShell runner captures this warning and should continue unless `agentbeats-run` exits with a nonzero status.

If AgentBeats reports `Timeout: Only 0/4 agents became ready`, rerun with logs and a longer startup timeout:

```powershell
$env:MODEL = "gpt-5.5"
$env:SCENARIOS = "medical_records"
$env:REPS = "1"
$env:SHOW_LOGS = "1"
$env:STARTUP_TIMEOUT = "180"
powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest.ps1
Remove-Item Env:MODEL, Env:SCENARIOS, Env:REPS, Env:SHOW_LOGS, Env:STARTUP_TIMEOUT -ErrorAction SilentlyContinue
```

If a run fails mid-way, inspect the specific output directory and rerun. Existing successful `result.json` files are skipped automatically.
