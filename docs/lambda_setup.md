# Lambda Cloud vLLM Setup (One-Time, Per Team Member)

For our paper experiments, we **do not use the competition's Lambda-hosted endpoint** —
that resource is for the official event only. Each team member must spin up their
**own** Lambda Cloud GPU instance with their **own** credit.

---

## Why "your own credit"?

- The original Lambda endpoint is post-competition; reusing it for personal research is not appropriate.
- Compute is individually billed — credits are not shareable.
- Each member runs experiments independently using their own instance.

---

## One-Time Setup (~15 minutes)

### 1. Launch a GPU instance

1. Login to https://cloud.lambdalabs.com (your own account).
2. Click **Launch Instance**.
3. Choose **`gpu_1x_a10`** (1× A10, 24 GB VRAM — enough for `openai/gpt-oss-20b`).
4. Region: pick whichever has stock (us-east, us-west typically).
5. OS: **Ubuntu 22.04**. Storage: 100 GB default.
6. Attach an SSH key (existing or new).
7. Click **Launch**. Wait ~2 minutes for boot.

> 💰 Cost: ~$0.75/hour. The full smoke experiment (10 battles) takes <1 hour.

### 2. SSH into the instance

```bash
ssh ubuntu@<your-instance-ip>
```

### 3. Start vLLM (one command)

```bash
sudo docker run -d --name vllm-server \
    --gpus all \
    -v ~/.cache/huggingface:/root/.cache/huggingface \
    -p 8000:8000 \
    --ipc=host \
    vllm/vllm-openai:latest \
    --model openai/gpt-oss-20b
```

### 4. Wait for model to load (~5 minutes first time)

```bash
docker logs -f vllm-server
# Wait until you see:
#   INFO:     Uvicorn running on http://0.0.0.0:8000
```

`Ctrl+C` to exit logs once you see this line.

### 5. Get the public IP

```bash
curl ifconfig.me
# Or use the IP shown in Lambda Cloud dashboard
```

### 6. Configure your local `.env`

In your local repo:

```bash
cp .env.example .env
```

Edit `.env`:

```env
OPENAI_BASE_URL=http://<lambda-instance-ip>:8000/v1
OPENAI_API_KEY=anything
```

### 7. Verify connectivity from your laptop

```bash
curl ${OPENAI_BASE_URL}/models
# Should return: {"data":[{"id":"openai/gpt-oss-20b",...}]}
```

---

## Running the Smoke Experiment

```bash
# From repo root, with .env configured:
bash scripts/run_smoke.sh

# After it finishes (~30 min):
python scripts/aggregate_smoke.py
```

---

## ⚠️ When Done — TERMINATE (not Stop)

| Action | Billing? |
|---|---|
| **Terminate** | ✅ Stops billing |
| **Stop** | ⚠️ Still charged for storage |

In Lambda Cloud dashboard → Instances → your instance → **Terminate**.

Re-launching later will re-download the model (the persistent `~/.cache/huggingface`
volume is local to the instance and is destroyed on terminate). To avoid this, use
Lambda's *Persistent Filesystem* feature.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `connection refused` from local | Check Lambda firewall allows 8000 inbound (default does) |
| `OOM` in vLLM logs | Add `--gpu-memory-utilization 0.85 --max-model-len 4096` |
| `model not found` | You started with a different `--model` flag — restart container |
| Local agents fail with timeout | vLLM may still be loading; check `docker logs vllm-server` |
