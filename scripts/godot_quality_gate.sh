#!/usr/bin/env bash
set -euo pipefail

project="."
smoke_scene=""
godot_bin="${GODOT_BIN:-godot}"
log_dir="${GODOT_QUALITY_GATE_LOG_DIR:-}"
run_import=1
isolate_user_data=0
isolation_cache_dir="${KEEUM_ISOLATION_CACHE_DIR:-}"
owns_isolation_cache=0

usage() {
  cat <<'USAGE'
Usage:
  godot_quality_gate.sh [--project PATH] [--smoke-scene RES://SCENE] [--godot-bin PATH] [--skip-import] [--isolate-user-data]

Checks:
  1. Runs: godot --headless --path <project> --import --quit
  2. Runs: godot --headless --path <project> --quit
  3. Fails when Godot exits non-zero
  4. Fails when Godot logs lines beginning with SCRIPT ERROR or ERROR:
  5. Optionally runs a smoke scene with the same log rules
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      project="${2:?missing value for --project}"
      shift 2
      ;;
    --smoke-scene)
      smoke_scene="${2:?missing value for --smoke-scene}"
      shift 2
      ;;
    --godot-bin)
      godot_bin="${2:?missing value for --godot-bin}"
      shift 2
      ;;
    --skip-import)
      run_import=0
      shift
      ;;
    --isolate-user-data)
      isolate_user_data=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$isolate_user_data" -eq 1 && -z "$isolation_cache_dir" ]]; then
  isolation_cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-cache.XXXXXX")"
  owns_isolation_cache=1
fi
if [[ -n "$isolation_cache_dir" ]]; then
  export KEEUM_ISOLATION_CACHE_DIR="$isolation_cache_dir"
fi

cleanup() {
  if [[ "$owns_isolation_cache" -eq 1 && -n "${isolation_cache_dir:-}" \
      && "$isolation_cache_dir" == "${TMPDIR:-/tmp}/keeum-isolation-cache."* ]]; then
    rm -rf -- "$isolation_cache_dir"
  fi
}
trap cleanup EXIT

if [ -z "${log_dir}" ]; then
  log_dir="$(mktemp -d)"
else
  mkdir -p "${log_dir}"
fi

run_godot_check() {
  local label="$1"
  shift
  local log_file="${log_dir}/${label}.log"

  echo "[godot-quality] running ${label}: $*" >&2
  set +e
  if [[ "$isolate_user_data" -eq 1 ]]; then
    local command_bin="$1"
    shift
    GODOT_BIN="$command_bin" "$project/scripts/run_godot_isolated.sh" "quality-$label" -- "$@" 2>&1 | tee "${log_file}"
  else
    "$@" 2>&1 | tee "${log_file}"
  fi
  local status="${PIPESTATUS[0]}"
  set -e

  if [ "${status}" -ne 0 ]; then
    echo "[godot-quality] ${label} failed with exit ${status}. Log: ${log_file}" >&2
    exit "${status}"
  fi

  if grep -E "^(SCRIPT ERROR|ERROR):" "${log_file}" >/dev/null; then
    echo "[godot-quality] ${label} reported Godot errors. Log: ${log_file}" >&2
    grep -E "^(SCRIPT ERROR|ERROR):" "${log_file}" >&2 || true
    exit 1
  fi

  echo "[godot-quality] ${label} passed. Log: ${log_file}" >&2
}

if [ "${run_import}" -eq 1 ]; then
  run_godot_check "import" "${godot_bin}" --headless --path "${project}" --import --quit
fi

run_godot_check "compile" "${godot_bin}" --headless --path "${project}" --quit

if [ -n "${smoke_scene}" ]; then
  run_godot_check "smoke" "${godot_bin}" --headless --path "${project}" --scene "${smoke_scene}"
fi
