#!/usr/bin/env bash
# Sweep multiple model configurations through run_smoke_dlatest.sh in parallel.
#
# Same-model sweep:
#   MODELS="openai/gpt-oss-20b inclusionai/ling-2.6-1t:free" \
#   bash scripts/run_smoke_dlatest_sweep.sh
#
# Per-role sweep:
#   MODEL_RUNS="attacker-model|defender-model|normal-user-model;attacker2|defender2|normal2" \
#   bash scripts/run_smoke_dlatest_sweep.sh
#
# Parallel controls:
#   MAX_PARALLEL_MODELS  Number of model runs active at once. Default: 2.
#   FIRST_PORT_OFFSET    First run adds this offset to ports 9010/9020/9021/9022. Default: 100.
#   PORT_STEP            Offset step for each additional parallel run. Default: 100.
#   LOG_POLL_SECONDS     Seconds between job status checks. Default: 5.
#
# Other env vars are passed through to run_smoke_dlatest.sh:
#   SCENARIOS, REPS, SHOW_LOGS, STARTUP_TIMEOUT, REP_PAUSE_SECONDS,
#   OPENAI_BASE_URL/OPENAI_API_KEY and per-role provider overrides.

set -euo pipefail

cd "$(dirname "$0")/.."

RUNNER="scripts/run_smoke_dlatest.sh"
if [ ! -f "$RUNNER" ]; then
  echo "Missing runner: $RUNNER" >&2
  exit 1
fi

: "${REPS:=5}"
: "${REP_PAUSE_SECONDS:=0}"
: "${STARTUP_TIMEOUT:=90}"
: "${MAX_PARALLEL_MODELS:=2}"
: "${FIRST_PORT_OFFSET:=100}"
: "${PORT_STEP:=100}"
: "${LOG_POLL_SECONDS:=5}"
: "${SHOW_LOGS:=0}"

require_non_negative_int() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "ERROR: $name must be a non-negative integer" >&2
    exit 1
  fi
}

require_positive_int() {
  local name="$1"
  local value="$2"
  require_non_negative_int "$name" "$value"
  if [ "$value" -lt 1 ]; then
    echo "ERROR: $name must be at least 1" >&2
    exit 1
  fi
}

require_positive_int "MAX_PARALLEL_MODELS" "$MAX_PARALLEL_MODELS"
require_non_negative_int "FIRST_PORT_OFFSET" "$FIRST_PORT_OFFSET"
require_positive_int "PORT_STEP" "$PORT_STEP"
require_positive_int "LOG_POLL_SECONDS" "$LOG_POLL_SECONDS"

if [ "$PORT_STEP" -lt 10 ]; then
  echo "ERROR: PORT_STEP must be at least 10" >&2
  exit 1
fi

CONFIG_NAMES=()
CONFIG_KINDS=()
CONFIG_MODELS=()
CONFIG_ATTACKERS=()
CONFIG_DEFENDERS=()
CONFIG_NORMAL_USERS=()
CONFIG_PORT_OFFSETS=()

add_config() {
  local index="$1"
  local kind="$2"
  local model="$3"
  local attacker="$4"
  local defender="$5"
  local normal_user="$6"
  local name
  printf -v name "sweep_%03d" "$((index + 1))"

  CONFIG_NAMES+=("$name")
  CONFIG_KINDS+=("$kind")
  CONFIG_MODELS+=("$model")
  CONFIG_ATTACKERS+=("$attacker")
  CONFIG_DEFENDERS+=("$defender")
  CONFIG_NORMAL_USERS+=("$normal_user")
  CONFIG_PORT_OFFSETS+=("$((FIRST_PORT_OFFSET + index * PORT_STEP))")
}

index=0
if [ -n "${MODELS:-}" ]; then
  # shellcheck disable=SC2206
  MODEL_LIST=($MODELS)
  for model in "${MODEL_LIST[@]}"; do
    add_config "$index" "same" "$model" "" "" ""
    index=$((index + 1))
  done
fi

if [ -n "${MODEL_RUNS:-}" ]; then
  IFS=';' read -r -a RUN_LIST <<< "$MODEL_RUNS"
  for raw_run in "${RUN_LIST[@]}"; do
    run="${raw_run#"${raw_run%%[![:space:]]*}"}"
    run="${run%"${run##*[![:space:]]}"}"
    if [ -z "$run" ]; then
      continue
    fi

    IFS='|' read -r attacker defender normal_user extra <<< "$run"
    if [ -n "${extra:-}" ] || [ -z "${attacker:-}" ] || [ -z "${defender:-}" ] || [ -z "${normal_user:-}" ]; then
      echo "ERROR: Invalid MODEL_RUNS entry '$run'. Expected: attacker|defender|normal" >&2
      exit 1
    fi

    add_config "$index" "roles" "" "$attacker" "$defender" "$normal_user"
    index=$((index + 1))
  done
fi

if [ "${#CONFIG_NAMES[@]}" -eq 0 ]; then
  add_config 0 "same" "openai/gpt-oss-20b" "" "" ""
fi

echo "Prepared ${#CONFIG_NAMES[@]} sweep run(s)"
echo "Max parallel model runs: $MAX_PARALLEL_MODELS"
echo "First port offset: $FIRST_PORT_OFFSET"
echo "Port step: $PORT_STEP"

ACTIVE_PIDS=()
ACTIVE_NAMES=()
ACTIVE_STATUS_FILES=()
HAD_SWEEP_FAILURE=0
SWEEP_STATUS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dlatest_sweep.XXXXXX")"
trap 'rm -rf "$SWEEP_STATUS_DIR"' EXIT

start_sweep_job() {
  local i="$1"
  local name="${CONFIG_NAMES[$i]}"
  local kind="${CONFIG_KINDS[$i]}"
  local model="${CONFIG_MODELS[$i]}"
  local attacker="${CONFIG_ATTACKERS[$i]}"
  local defender="${CONFIG_DEFENDERS[$i]}"
  local normal_user="${CONFIG_NORMAL_USERS[$i]}"
  local port_offset="${CONFIG_PORT_OFFSETS[$i]}"
  local status_file="${SWEEP_STATUS_DIR}/${name}.status"

  echo ""
  echo "Launching $name with PORT_OFFSET=$port_offset"
  if [ "$kind" = "same" ]; then
    echo "  model: $model"
  else
    echo "  attacker:    $attacker"
    echo "  defender:    $defender"
    echo "  normal_user: $normal_user"
  fi

  (
    set -o pipefail
    unset OUTROOT
    export REPS REP_PAUSE_SECONDS STARTUP_TIMEOUT SHOW_LOGS
    export PORT_OFFSET="$port_offset"
    if [ -n "${SCENARIOS:-}" ]; then
      export SCENARIOS
    fi

    if [ "$kind" = "same" ]; then
      export MODEL="$model"
      export ATTACKER_MODEL="$model"
      export DEFENDER_MODEL="$model"
      export NORMAL_USER_MODEL="$model"
    else
      unset MODEL
      export ATTACKER_MODEL="$attacker"
      export DEFENDER_MODEL="$defender"
      export NORMAL_USER_MODEL="$normal_user"
    fi

    bash "$RUNNER" 2>&1 | sed -u "s/^/[$name] /"
    status=$?
    printf "%s\n" "$status" > "$status_file"
    exit "$status"
  ) &

  ACTIVE_PIDS+=("$!")
  ACTIVE_NAMES+=("$name")
  ACTIVE_STATUS_FILES+=("$status_file")
}

reap_completed_jobs() {
  local block="$1"

  while true; do
    local next_pids=()
    local next_names=()
    local next_status_files=()
    local reaped=0

    for i in "${!ACTIVE_PIDS[@]}"; do
      local pid="${ACTIVE_PIDS[$i]}"
      local name="${ACTIVE_NAMES[$i]}"
      local status_file="${ACTIVE_STATUS_FILES[$i]}"

      if [ ! -f "$status_file" ]; then
        next_pids+=("$pid")
        next_names+=("$name")
        next_status_files+=("$status_file")
      else
        reaped=1
        status="$(cat "$status_file")"
        wait "$pid" || true
        if [ "$status" -eq 0 ]; then
          echo ""
          echo "============================================================"
          echo "Finished $name with state Completed"
          echo "============================================================"
        else
          echo ""
          echo "============================================================"
          echo "Finished $name with state Failed (exit $status)"
          echo "============================================================"
          HAD_SWEEP_FAILURE=1
        fi
      fi
    done

    ACTIVE_PIDS=("${next_pids[@]}")
    ACTIVE_NAMES=("${next_names[@]}")
    ACTIVE_STATUS_FILES=("${next_status_files[@]}")

    if [ "${#ACTIVE_PIDS[@]}" -lt "$MAX_PARALLEL_MODELS" ] || [ "$block" = "false" ]; then
      return
    fi

    if [ "$reaped" -eq 0 ]; then
      sleep "$LOG_POLL_SECONDS"
    fi
  done
}

for i in "${!CONFIG_NAMES[@]}"; do
  while [ "${#ACTIVE_PIDS[@]}" -ge "$MAX_PARALLEL_MODELS" ]; do
    reap_completed_jobs true
  done
  start_sweep_job "$i"
done

while [ "${#ACTIVE_PIDS[@]}" -gt 0 ]; do
  reap_completed_jobs true
done

if [ "$HAD_SWEEP_FAILURE" -ne 0 ]; then
  echo "One or more sweep jobs failed" >&2
  exit 1
fi

echo ""
echo "All sweep jobs completed"
