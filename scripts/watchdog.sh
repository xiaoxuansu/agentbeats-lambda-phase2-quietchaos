#!/usr/bin/env bash
# Cross-battle watchdog (Plan C: notify + hard-timeout auto-terminate)
#
# Behavior:
#   1. Polls every 60s for run_smoke.sh process
#   2. When it exits → aggregates results, notifies via macOS say + alert
#   3. If wall-clock since watchdog start exceeds HARD_TIMEOUT_MIN
#      → calls Lambda API to terminate instance (emergency brake)
#
# Environment variables (required):
#   LAMBDA_API_KEY    — secret_... from Lambda dashboard
#   LAMBDA_INSTANCE_ID — instance ID to terminate
#
# Optional:
#   HARD_TIMEOUT_MIN  — default 150 (2.5 hours)
#   POLL_SEC          — default 60
#
# Usage:
#   LAMBDA_API_KEY=secret_... LAMBDA_INSTANCE_ID=... bash scripts/watchdog.sh

set -uo pipefail

cd "$(dirname "$0")/.."

: "${LAMBDA_API_KEY:?need LAMBDA_API_KEY}"
: "${LAMBDA_INSTANCE_ID:?need LAMBDA_INSTANCE_ID}"
HARD_TIMEOUT_MIN="${HARD_TIMEOUT_MIN:-150}"
POLL_SEC="${POLL_SEC:-60}"

LOG="watchdog.log"
START_EPOCH=$(date +%s)

echo "[$(date +%H:%M:%S)] watchdog started (hard timeout: ${HARD_TIMEOUT_MIN}min)" | tee -a "$LOG"

# --- Helpers ---
notify() {
  local msg="$1"
  echo "[$(date +%H:%M:%S)] $msg" | tee -a "$LOG"
  # macOS native notification + voice
  osascript -e "display notification \"$msg\" with title \"Cross-battle watchdog\" sound name \"Glass\"" 2>/dev/null || true
  say "$msg" 2>/dev/null &
  printf '\a'
}

terminate_lambda() {
  echo "[$(date +%H:%M:%S)] calling Lambda API to terminate ${LAMBDA_INSTANCE_ID}..." | tee -a "$LOG"
  resp=$(curl -s -w "\n%{http_code}" -u "${LAMBDA_API_KEY}:" \
    https://cloud.lambdalabs.com/api/v1/instance-operations/terminate \
    -H "Content-Type: application/json" \
    -d "{\"instance_ids\": [\"${LAMBDA_INSTANCE_ID}\"]}")
  echo "$resp" | tee -a "$LOG"
}

# --- Main loop ---
while true; do
  ELAPSED_MIN=$(( ($(date +%s) - START_EPOCH) / 60 ))

  # Hard timeout check
  if [ "$ELAPSED_MIN" -ge "$HARD_TIMEOUT_MIN" ]; then
    notify "HARD TIMEOUT (${HARD_TIMEOUT_MIN}min). Auto-terminating Lambda instance."
    terminate_lambda
    notify "Lambda terminated. Watchdog exiting."
    exit 2
  fi

  # Process check
  if pgrep -f "bash scripts/run_smoke" > /dev/null 2>&1 || \
     pgrep -f "agentbeats-run scenarios/security_arena/scenario_.*_acq_vs_d[xy]" > /dev/null 2>&1; then
    # still running
    sleep "$POLL_SEC"
    continue
  fi

  # Process gone — smoke finished
  echo "[$(date +%H:%M:%S)] run_smoke.sh appears finished" | tee -a "$LOG"

  # Run aggregation
  echo "" | tee -a "$LOG"
  python3 scripts/aggregate_smoke.py --json 2>&1 | tee -a "$LOG"

  # Count completed battles
  COMPLETED=$(find results/cross_smoke/A_qc_vs_D_x -name "result.json" 2>/dev/null | wc -l | tr -d ' ')
  notify "Smoke test done. ${COMPLETED}/10 battles. Terminate Lambda manually within 5 min, or watchdog will auto-terminate."

  # Wait 5 min for user to manually terminate
  for i in $(seq 1 5); do
    sleep 60
    notify "[$i/5 min] Lambda still running. Terminate via dashboard or wait."
  done

  notify "5 min elapsed. Auto-terminating Lambda."
  terminate_lambda
  notify "Lambda terminated. Watchdog exiting normally."
  exit 0
done
