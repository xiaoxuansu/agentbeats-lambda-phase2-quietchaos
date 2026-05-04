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
#   REP_PAUSE_SECONDS  Seconds to sleep between reps. Default: 0.
#   PORT_OFFSET        Add this value to local ports 9010/9020/9021/9022.
#                      Use a different offset for parallel runs.
#   STARTUP_TIMEOUT    Seconds to wait for agent startup. Default: 90.
#   SHOW_LOGS          If set and not 0, pass --show-logs to agentbeats-run.
#   OUTROOT            Output directory. If unset, a role/model slug is appended.
#   TMPROOT            Temporary TOML output directory.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example and set OPENAI_BASE_URL/OPENAI_API_KEY."
  exit 1
fi

declare -A CALLER_ENV=()
for name in \
  MODEL ATTACKER_MODEL DEFENDER_MODEL NORMAL_USER_MODEL \
  ATTACKER_OPENAI_BASE_URL ATTACKER_OPENAI_API_KEY \
  DEFENDER_OPENAI_BASE_URL DEFENDER_OPENAI_API_KEY \
  NORMAL_USER_OPENAI_BASE_URL NORMAL_USER_OPENAI_API_KEY \
  SCENARIOS REPS REP_PAUSE_SECONDS PORT_OFFSET STARTUP_TIMEOUT SHOW_LOGS \
  OUTROOT TMPROOT
do
  if [[ -v "$name" ]]; then
    CALLER_ENV["$name"]="${!name}"
  fi
done

set -a
# shellcheck disable=SC1091
source .env
set +a

for name in "${!CALLER_ENV[@]}"; do
  printf -v "$name" "%s" "${CALLER_ENV[$name]}"
  export "$name"
done

if [ -z "${OPENAI_BASE_URL:-}" ]; then
  echo "ERROR: OPENAI_BASE_URL not set in .env"
  exit 1
fi

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
: "${REP_PAUSE_SECONDS:=0}"
: "${PORT_OFFSET:=0}"
: "${STARTUP_TIMEOUT:=90}"
: "${SHOW_LOGS:=0}"
: "${MODEL:=openai/gpt-oss-20b}"
: "${ATTACKER_MODEL:=$MODEL}"
: "${DEFENDER_MODEL:=$MODEL}"
: "${NORMAL_USER_MODEL:=$MODEL}"

if ! [[ "$PORT_OFFSET" =~ ^[0-9]+$ ]]; then
  echo "ERROR: PORT_OFFSET must be a non-negative integer"
  exit 1
fi
if ! [[ "$STARTUP_TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: STARTUP_TIMEOUT must be a non-negative integer"
  exit 1
fi

slugify() {
  python - "$1" <<'PY'
import re
import sys

slug = re.sub(r"[^a-z0-9]+", "_", sys.argv[1].lower()).strip("_")
print(slug or "unset")
PY
}

ATTACKER_SLUG="$(slugify "$ATTACKER_MODEL")"
DEFENDER_SLUG="$(slugify "$DEFENDER_MODEL")"
NORMAL_USER_SLUG="$(slugify "$NORMAL_USER_MODEL")"
RUN_SLUG="A_${ATTACKER_SLUG}__D_${DEFENDER_SLUG}__N_${NORMAL_USER_SLUG}"

if [ -z "${OUTROOT:-}" ]; then
  OUTROOT="results/cross_smoke/A_qc_vs_D_latest/${RUN_SLUG}"
fi
TMPROOT="${TMPROOT:-results/tmp/dlatest_tomls/${RUN_SLUG}/ports_${PORT_OFFSET}}"
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

  python - "$BASE_TOML" "$TOML" "$ATTACKER_MODEL" "$DEFENDER_MODEL" "$NORMAL_USER_MODEL" "$PORT_OFFSET" <<'PY'
import os
import re
import sys
from pathlib import Path

base_toml, toml, attacker_model, defender_model, normal_user_model, port_offset = sys.argv[1:]
port_offset = int(port_offset)
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


def set_port_offset(content: str, offset: int) -> str:
    if offset == 0:
        return content

    port_map = {
        "9010": str(9010 + offset),
        "9020": str(9020 + offset),
        "9021": str(9021 + offset),
        "9022": str(9022 + offset),
    }
    port_pattern = "|".join(port_map)
    content = re.sub(
        rf"(127\.0\.0\.1|localhost):({port_pattern})\b",
        lambda match: f"{match.group(1)}:{port_map[match.group(2)]}",
        content,
    )
    content = re.sub(
        rf"(\s--port\s+)({port_pattern})\b",
        lambda match: match.group(1) + port_map[match.group(2)],
        content,
    )
    return content


content = set_agent_model(content, "scenarios.security_arena.agents.attacker.agent", attacker_model)
content = set_agent_model(content, "scenarios.security_arena.agents.defender.agent", defender_model)
content = set_agent_model(content, "scenarios.security_arena.agents.normal_user.agent", normal_user_model)
content = set_agent_env(content, "scenarios.security_arena.agents.attacker.agent", "ATTACKER")
content = set_agent_env(content, "scenarios.security_arena.agents.defender.agent", "DEFENDER")
content = set_agent_env(content, "scenarios.security_arena.agents.normal_user.agent", "NORMAL_USER")
content = set_port_offset(content, port_offset)
Path(toml).parent.mkdir(parents=True, exist_ok=True)
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
    AGENTBEATS_ARGS=("$TOML" "--startup-timeout" "$STARTUP_TIMEOUT")
    if [ -n "${SHOW_LOGS:-}" ] && [ "$SHOW_LOGS" != "0" ]; then
      AGENTBEATS_ARGS+=("--show-logs")
    fi
    AGENTBEATS_RESULTS_DIR="$OUTDIR" \
      uv run agentbeats-run "${AGENTBEATS_ARGS[@]}" 2>&1 | tail -40 || {
        echo "WARNING: battle failed, continuing with next"
      }

    if [ "$REP_PAUSE_SECONDS" -gt 0 ] && [ "$COUNT" -lt "$TOTAL" ]; then
      echo "Pausing ${REP_PAUSE_SECONDS}s before next rep..."
      sleep "$REP_PAUSE_SECONDS"
    fi
  done
done

ELAPSED=$(( $(date +%s) - START_TIME ))
AGGREGATE_ROOT="$(dirname "$OUTROOT")"
echo ""
echo "============================================================"
echo "DONE. Elapsed: ${ELAPSED}s"
echo "Refresh tables with:"
echo "  python -X utf8 scripts/tag_patterns.py \"${AGGREGATE_ROOT}\""
echo "  python -X utf8 scripts/aggregate_benchmark.py \"${AGGREGATE_ROOT}\""
echo "============================================================"
