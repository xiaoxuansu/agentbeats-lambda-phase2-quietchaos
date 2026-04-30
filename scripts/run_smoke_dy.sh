#!/usr/bin/env bash
# Smoke test: A_qc (your v23 attacker) vs D_y (team_y defender)
# 5 scenarios × 2 reps = 10 battles total
# Each rep writes to a separate output dir to prevent overwrite.
#
# Prerequisites:
#   1. .env populated with OPENAI_BASE_URL pointing to YOUR Lambda vLLM
#   2. vLLM serving openai/gpt-oss-20b is reachable
#   3. Ports 9010, 9020, 9021, 9022 are free locally
#
# Usage:
#   bash scripts/run_smoke.sh
#
# Output:
#   results/cross_smoke/A_qc_vs_D_y/<scenario>_rep<N>/result.json

set -euo pipefail

cd "$(dirname "$0")/.."

# --- 0. Sanity checks ---
if [ ! -f .env ]; then
  echo "❌ .env not found. Copy .env.example and set your Lambda endpoint."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ -z "${OPENAI_BASE_URL:-}" ]; then
  echo "❌ OPENAI_BASE_URL not set in .env"
  exit 1
fi

echo "→ Verifying vLLM endpoint at ${OPENAI_BASE_URL}..."
if ! curl -sf --max-time 5 "${OPENAI_BASE_URL}/models" > /dev/null; then
  echo "❌ Cannot reach ${OPENAI_BASE_URL}/models"
  echo "   Did you start your Lambda vLLM instance?"
  echo "   See docs/lambda_setup.md"
  exit 1
fi
echo "✓ vLLM endpoint reachable"

# --- 1. Run matrix ---
# Env overrides: pass SCENARIOS as a space-separated string and REPS as an int.
# Example: SCENARIOS="portfolioiq" REPS=5 bash scripts/run_smoke_dy.sh
if [ -n "${SCENARIOS+x}" ]; then
  read -r -a SCENARIOS <<< "$SCENARIOS"
else
  SCENARIOS=(
    "portfolioiq"
    "thingularity"
    "gymjailbreak"
    "resume_downgrade"
    "medical_records"
  )
fi
: "${REPS:=2}"

OUTROOT="${OUTROOT:-results/cross_smoke/A_qc_vs_D_y}"
mkdir -p "$OUTROOT"

START_TIME=$(date +%s)
TOTAL=$((${#SCENARIOS[@]} * REPS))
COUNT=0

for scenario in "${SCENARIOS[@]}"; do
  for rep in $(seq 1 $REPS); do
    COUNT=$((COUNT + 1))
    OUTDIR="${OUTROOT}/${scenario}_rep${rep}"
    TOML="scenarios/security_arena/scenario_${scenario}_acq_vs_dy.toml"

    echo ""
    echo "============================================================"
    echo "[${COUNT}/${TOTAL}] ${scenario} rep ${rep}"
    echo "         output: ${OUTDIR}"
    echo "============================================================"

    if [ -f "${OUTDIR}/result.json" ]; then
      echo "↪  result.json already exists, skipping (delete to rerun)"
      continue
    fi

    mkdir -p "$OUTDIR"
    AGENTBEATS_RESULTS_DIR="$OUTDIR" \
      uv run agentbeats-run "$TOML" 2>&1 | tail -40 || {
        echo "⚠️  battle failed — continuing with next"
      }
  done
done

ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "============================================================"
echo "DONE. Elapsed: ${ELAPSED}s"
echo "Aggregate with:  python scripts/aggregate_smoke.py"
echo "============================================================"
