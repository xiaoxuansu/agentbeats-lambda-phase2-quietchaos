#!/usr/bin/env bash
# Smoke test: A_qc (v23 attacker) vs Defender_latest (strongest submitted defender).
#
# This script mirrors run_smoke.sh/run_smoke_dy.sh, but writes to:
#   results/cross_smoke/A_qc_vs_D_latest/<scenario>_rep<N>/result.json
#
# It derives temporary TOMLs from the Defender_x TOMLs and swaps the defender
# module to scenarios.security_arena.agents.defender.agent. This avoids
# maintaining five near-duplicate scenario files.
#
# Env overrides:
#   MODEL              Shared fallback for attacker, defender, and normal_user.
#                      Default: openai/gpt-oss-20b
#   ATTACKER_MODEL     Attacker model override. Defaults to MODEL.
#   DEFENDER_MODEL     Defender model override. Defaults to MODEL.
#   NORMAL_USER_MODEL  Normal-user model override. Defaults to MODEL.
#   ATTACKER_OPENAI_BASE_URL / ATTACKER_OPENAI_API_KEY
#                      Attacker provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   DEFENDER_OPENAI_BASE_URL / DEFENDER_OPENAI_API_KEY
#                      Defender provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   NORMAL_USER_OPENAI_BASE_URL / NORMAL_USER_OPENAI_API_KEY
#                      Normal-user provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   SCENARIOS          Space-separated scenario list.
#   REPS               Number of reps per scenario.
#   OUTROOT            Output directory. Set this per model when running a sweep.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example and set OPENAI_BASE_URL/OPENAI_API_KEY."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [ -z "${OPENAI_BASE_URL:-}" ]; then
  echo "ERROR: OPENAI_BASE_URL not set in .env"
  exit 1
fi

# PORT_BASE allows parallel runs by remapping the four agent ports.
# Default 9000 produces orchestrator=9010 / defender=9020 / attacker=9021 /
# normal_user=9022 (the original numbers). Each parallel instance must use
# a unique PORT_BASE 100 apart (9100, 9200, 9300, ...).
: "${PORT_BASE:=9000}"

echo "Verifying OpenAI-compatible endpoint at ${OPENAI_BASE_URL}..."
if ! curl -sf --max-time 5 \
  -H "Authorization: Bearer ${OPENAI_API_KEY:-}" \
  "${OPENAI_BASE_URL}/models" > /dev/null; then
  echo "ERROR: Cannot reach ${OPENAI_BASE_URL}/models"
  echo "Check OPENAI_BASE_URL and OPENAI_API_KEY in .env."
  exit 1
fi
echo "OpenAI-compatible endpoint reachable"

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
: "${MODEL:=openai/gpt-oss-20b}"
: "${ATTACKER_MODEL:=$MODEL}"
: "${DEFENDER_MODEL:=$MODEL}"
: "${NORMAL_USER_MODEL:=$MODEL}"

OUTROOT="${OUTROOT:-results/cross_smoke/A_qc_vs_D_latest}"
TMPROOT="${TMPROOT:-results/tmp/dlatest_tomls}"
mkdir -p "$OUTROOT" "$TMPROOT"

START_TIME=$(date +%s)
TOTAL=$((${#SCENARIOS[@]} * REPS))
COUNT=0

for scenario in "${SCENARIOS[@]}"; do
  BASE_TOML="scenarios/security_arena/scenario_${scenario}_acq_vs_dx.toml"
  TOML="${TMPROOT}/scenario_${scenario}_acq_vs_dlatest.toml"

  if [ ! -f "$BASE_TOML" ]; then
    echo "ERROR: missing base TOML: ${BASE_TOML}"
    exit 1
  fi

  python - "$BASE_TOML" "$TOML" "$ATTACKER_MODEL" "$DEFENDER_MODEL" "$NORMAL_USER_MODEL" "$PORT_BASE" <<'PY'
import os
import re
import sys
from pathlib import Path

(base_toml, toml, attacker_model, defender_model,
 normal_user_model, port_base) = sys.argv[1:]
port_base = int(port_base)
content = Path(base_toml).read_text(encoding="utf-8")
content = re.sub(
    r"attacker_quietchaos_v23 vs Defender_x.*",
    "attacker_quietchaos_v23 vs Defender_latest (strongest submitted defender)",
    content,
)
content = content.replace(
    "scenarios.security_arena.agents.quietchaos_v4_defender.agent",
    "scenarios.security_arena.agents.defender.agent",
)

# Port remapping: original 9010/9020/9021/9022 → PORT_BASE+10/20/21/22.
# Default PORT_BASE=9000 leaves the original numbers untouched.
PORT_OFFSETS = {9010: 10, 9020: 20, 9021: 21, 9022: 22}
for old_port, off in PORT_OFFSETS.items():
    new_port = port_base + off
    if new_port == old_port:
        continue
    content = content.replace(f":{old_port}", f":{new_port}")
    content = content.replace(f"--port {old_port}", f"--port {new_port}")


def set_agent_model(content: str, module: str, model: str) -> str:
    pattern = rf'(cmd\s*=\s*"[^"]*{re.escape(module)}[^"]*--model\s+)[^"\s]+'
    return re.sub(pattern, lambda match: match.group(1) + model, content)


def set_agent_env(content: str, module: str, role_prefix: str) -> str:
    entries = []
    base_url_var = f"{role_prefix}_OPENAI_BASE_URL"
    api_key_var = f"{role_prefix}_OPENAI_API_KEY"
    if os.environ.get(base_url_var):
        entries.append(f'OPENAI_BASE_URL = "${{{base_url_var}}}"')
    if os.environ.get(api_key_var):
        entries.append(f'OPENAI_API_KEY = "${{{api_key_var}}}"')
    if not entries:
        return content

    env_line = "env = { " + ", ".join(entries) + " }"
    pattern = rf'(cmd\s*=\s*"[^"]*{re.escape(module)}[^"]*")'
    return re.sub(pattern, lambda match: match.group(1) + "\n" + env_line, content)


content = set_agent_model(content, "scenarios.security_arena.agents.attacker.agent", attacker_model)
content = set_agent_model(content, "scenarios.security_arena.agents.defender.agent", defender_model)
content = set_agent_model(content, "scenarios.security_arena.agents.normal_user.agent", normal_user_model)
content = set_agent_env(content, "scenarios.security_arena.agents.attacker.agent", "ATTACKER")
content = set_agent_env(content, "scenarios.security_arena.agents.defender.agent", "DEFENDER")
content = set_agent_env(content, "scenarios.security_arena.agents.normal_user.agent", "NORMAL_USER")
Path(toml).write_text(content, encoding="utf-8")
PY

  for rep in $(seq 1 "$REPS"); do
    COUNT=$((COUNT + 1))
    OUTDIR="${OUTROOT}/${scenario}_rep${rep}"

    echo ""
    echo "============================================================"
    echo "[${COUNT}/${TOTAL}] ${scenario} rep ${rep}"
    echo "         output: ${OUTDIR}"
    echo "============================================================"

    if [ -f "${OUTDIR}/result.json" ]; then
      echo "result.json already exists, skipping (delete to rerun)"
      continue
    fi

    mkdir -p "$OUTDIR"
    AGENTBEATS_RESULTS_DIR="$OUTDIR" \
      uv run agentbeats-run "$TOML" 2>&1 | tail -40 || {
        echo "WARNING: battle failed, continuing with next"
      }
  done
done

ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "============================================================"
echo "DONE. Elapsed: ${ELAPSED}s"
echo "Refresh tables with:"
echo "  python -X utf8 scripts/tag_patterns.py results/cross_smoke"
echo "  python -X utf8 scripts/aggregate_benchmark.py results/cross_smoke"
echo "============================================================"
