# Experiment Environment Setup

This guide gets your machine and a fresh Lambda Cloud GPU instance ready to
run any matrix cell from `docs/experiment_matrix.md`. Run it once per
collaborator; thereafter you only re-launch a fresh Lambda instance per
experiment session.

---

## ⚠️ Important: We do NOT use the competition's host endpoint

The OPENAI_BASE_URL the host gave us during the official competition is **post-competition**. We **must not** reuse it for paper experiments because:

1. The endpoint is not guaranteed to remain available, and may be revoked.
2. Using post-competition host compute for personal research is inappropriate; the credit was provisioned for the event only.
3. We cannot reproduce results months later if the endpoint is gone — paper-grade work needs reproducibility under our own control.

**Each collaborator runs their own Lambda Cloud GPU instance with their own credit.** Credits are individual, not shareable.

---

## What you need before starting

- [ ] Your own Lambda Cloud account with billing set up — https://cloud.lambdalabs.com
- [ ] An SSH key on the Lambda account (generate one in their dashboard if you don't have one — make sure to download the private key)
- [ ] This repo cloned **and on branch `paper-experiments`** (NOT main): `git clone <repo-url> && cd <repo> && git checkout paper-experiments`
- [ ] Python 3.13+ and `uv` installed locally (the repo uses `uv`)
- [ ] ~$5–30 of Lambda credit per matrix cell you're assigned (see `docs/experiment_matrix.md` for budgets)
- [ ] The repo includes the cross-team agent code at `scenarios/security_arena/agents/team_x_defender/` (Defender_x, ~433 lines, multi-pass pipeline) and `scenarios/security_arena/agents/team_y_defender/` (Defender_y, ~206 lines, single-pass pipeline). Both are referenced throughout the docs.

---

## Step 1: Launch your A10 instance

1. https://cloud.lambdalabs.com → **Launch instance**
2. Instance type: **`gpu_1x_a10`** (1× A10, 24 GB VRAM, $0.75/h). This is what the competition used; matches our results.
   - If A10 is sold out, fall back to `gpu_1x_a100_pcie_40gb` ($1.29/h, also works).
3. Region: any with stock (us-west, us-east).
4. Base image: **Lambda Stack 22.04** (preinstalled CUDA + Docker).
5. Filesystem: **None** (not needed for short experiments; saves $).
6. Firewall:
   - Add a custom ruleset that opens **TCP port 8000** to **your own IP only** (`<your.ipv4>/32`).
   - Get your IPv4 with `curl -4 ifconfig.me` from your machine.
   - Don't use `0.0.0.0/0` — vLLM has no auth, anyone could use your GPU.
7. SSH key: select your existing one.
8. Click **Launch instance**. Wait 2–10 min until status = **Running** and a Public IP appears.

---

## Step 2: SSH in and start vLLM

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@<public-ip>
```

Inside the instance:

```bash
sudo docker run -d --name vllm-server \
    --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    -p 8000:8000 \
    --ipc=host \
    vllm/vllm-openai:latest \
    --model openai/gpt-oss-20b \
    --gpu-memory-utilization 0.85 \
    --max-model-len 16384
```

> **Important**: `--max-model-len 16384` (not the smaller defaults). Our attacker generates prompts up to ~8800 tokens; running with 8192 caused crashes in the first round of experiments. 16384 is safe and still fits on A10 24GB at 0.85 utilization.

Wait for the model to load (first time ~5 min for download + load):

```bash
sudo docker logs -f vllm-server
# Look for: "INFO:     Uvicorn running on http://0.0.0.0:8000"
# Ctrl+C to detach
```

Verify from the instance:

```bash
curl -s http://localhost:8000/v1/models
```

---

## Step 3: Configure your local repo

In your local repo root (e.g. on your MacBook, not the Lambda instance):

```bash
cp .env.example .env
```

Edit `.env`:

```env
OPENAI_BASE_URL=http://<your-lambda-ip>:8000/v1
OPENAI_API_KEY=anything
```

(`OPENAI_API_KEY` is not validated by vLLM; any string works.)

Verify connectivity from your laptop:

```bash
curl -s ${OPENAI_BASE_URL}/models
```

If you get a JSON response with `openai/gpt-oss-20b`, you're set.

---

## Step 4: Run your assigned matrix cell

Each matrix cell is an attacker × defender × scenario set × reps. Pick the one your project lead has assigned and adapt the existing scripts:

| Script | What it does | Adapt for |
|---|---|---|
| `scripts/run_smoke.sh` | Runs `attacker_quietchaos_v23 × Defender_x` × 5 public × 2 reps | Change `SCENARIOS=(...)` and `REPS` |
| `scripts/aggregate_benchmark.py` | Aggregates results into ASR table | Change `ROOT` path |
| `scripts/watchdog.sh` | Cost protection + auto-terminate | Always run alongside `run_smoke.sh` |

Common adaptations:

```bash
# 5 reps instead of 2 (paper-grade)
sed -i '' 's/^REPS=2$/REPS=5/' scripts/run_smoke.sh

# Different team pairing — first generate the cross-battle TOMLs:
#   <your_attacker_dir> = scenarios/security_arena/agents/<X>_attacker
#   <your_defender_dir> = scenarios/security_arena/agents/<Y>_defender
# Then sed-replace the agent module paths in scenario tomls (see existing
# scenario_*_acq_vs_dx.toml for the pattern).
```

Run:

```bash
bash scripts/run_smoke.sh
```

---

## Step 5: Cost protection (mandatory)

The watchdog auto-terminates the Lambda instance if your batch hangs. Always start it after you start `run_smoke.sh`:

```bash
LAMBDA_API_KEY=<your-lambda-api-key> \
LAMBDA_INSTANCE_ID=<your-instance-id> \
HARD_TIMEOUT_MIN=180 \
bash scripts/watchdog.sh &
```

Get your instance ID:

```bash
curl -s -u "<api-key>:" https://cloud.lambdalabs.com/api/v1/instances
```

It will:
- Notify you (macOS speech + popup) when the batch ends
- Give you 5 minutes to manually terminate via the Lambda dashboard
- Auto-terminate via the Lambda API if you don't respond
- Hard-terminate at `HARD_TIMEOUT_MIN` minutes from start regardless

---

## Step 6: When done — TERMINATE THE INSTANCE

Lambda bills by **instance uptime**, not GPU usage. Stopping vLLM doesn't stop the bill. Only **terminating the instance** stops it.

| Action | Billing? |
|---|---|
| **Terminate** | ✅ Stops billing |
| Stop | ⚠️ Still charged for storage |

In Lambda Cloud dashboard → Instances → your instance → **Terminate**.

---

## Reproducibility checklist

When committing your results to the repo:
- [ ] `results/<cell-name>/result.json` for each battle
- [ ] `results/<cell-name>/battle_log.md` for human inspection
- [ ] `results/<cell-name>/summary.json` from `aggregate_benchmark.py`
- [ ] Note the model, vLLM args, max_model_len, attacker version (commit hash), defender version (commit hash) in a `RUN_INFO.md` next to the results

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `connection refused` from laptop | Firewall doesn't allow port 8000 from your IP | Add rule with current `curl -4 ifconfig.me` |
| `Input length (xxxx) exceeds context length (8192)` in `result.err` | `--max-model-len` too small | Restart vLLM with `--max-model-len 16384` |
| `OOM` on vLLM startup with 16384 ctx | A10 24GB is tight | Lower `--gpu-memory-utilization` to 0.80, or fall back to 12288 ctx |
| Battles taking 10+ min each | Long-context scenarios (resume_downgrade, thingularity) | Normal — these have larger doc-style payloads |
| Lambda dashboard says instance is "Booting" for >20 min | Region capacity issue | Terminate, switch region, retry |
| API key showed up in chat / committed file | Compromised | Revoke immediately at https://cloud.lambdalabs.com/api-keys, generate a new one |

---

## What NOT to do

- ❌ Don't use the original host's endpoint for paper experiments
- ❌ Don't commit `.env`, `*.pem`, or any file containing API keys
- ❌ Don't skip the watchdog — Lambda instances left running overnight cost real money
- ❌ Don't run the same experiment without re-coordinating: we want non-redundant compute spend
