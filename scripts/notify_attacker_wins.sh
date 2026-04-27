#!/usr/bin/env bash
# Real-time notifier: alert when any battle ends with winner=attacker.
# Polls results dir every 30s. Tracks notified files in /tmp to avoid duplicate alerts.

set -uo pipefail
cd "$(dirname "$0")/.."

ROOT="results/cross_smoke/A_qc_vs_D_x"
SEEN="/tmp/attacker_win_notified.txt"
LOG="attacker_wins.log"
touch "$SEEN" "$LOG"

echo "[$(date +%H:%M:%S)] notifier started — watching for attacker wins" | tee -a "$LOG"

while true; do
  # Stop if smoke, agentbeats-run, AND watchdog are all gone (experiment over)
  if ! pgrep -f "run_smoke.sh" > /dev/null 2>&1 \
     && ! pgrep -f "agentbeats-run scenarios/security_arena" > /dev/null 2>&1 \
     && ! pgrep -f "watchdog.sh" > /dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)] no smoke/watchdog running — exiting" | tee -a "$LOG"
    exit 0
  fi

  for f in "$ROOT"/*/result.json; do
    [ -f "$f" ] || continue
    grep -qxF "$f" "$SEEN" && continue

    winner=$(python3 -c "import json,sys; print(json.load(open('$f')).get('winner','?'))" 2>/dev/null)
    if [ "$winner" = "attacker" ]; then
      scenario=$(basename "$(dirname "$f")")
      mr=$(python3 -c "import json; print(json.load(open('$f')).get('manipulation_round'))" 2>/dev/null)
      msg="ATTACKER WIN! ${scenario}, manipulation round ${mr}"
      echo "[$(date +%H:%M:%S)] $msg" | tee -a "$LOG"
      osascript -e "display notification \"$msg\" with title \"A_qc victory\" sound name \"Hero\"" 2>/dev/null || true
      say "Attacker won on $scenario" 2>/dev/null &
      printf '\a\a\a'
    fi
    echo "$f" >> "$SEEN"
  done

  sleep 30
done
