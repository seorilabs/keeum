#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
export GODOT_BIN="$godot_bin"
log_dir="${KEEUM_CHECK_LOG_DIR:-}"
owns_log_dir=0
isolation_cache_dir="${KEEUM_ISOLATION_CACHE_DIR:-}"
owns_isolation_cache=0

if [[ -z "$log_dir" ]]; then
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-check.XXXXXX")"
  owns_log_dir=1
else
  mkdir -p "$log_dir"
fi

if [[ -z "$isolation_cache_dir" ]]; then
  isolation_cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-cache.XXXXXX")"
  owns_isolation_cache=1
fi
export KEEUM_ISOLATION_CACHE_DIR="$isolation_cache_dir"

cleanup() {
  if [[ "$owns_log_dir" -eq 1 && -n "${log_dir:-}" && "$log_dir" != "/" ]]; then
    rm -rf -- "$log_dir"
  fi
  if [[ "$owns_isolation_cache" -eq 1 && -n "${isolation_cache_dir:-}" \
      && "$isolation_cache_dir" == "${TMPDIR:-/tmp}/keeum-isolation-cache."* ]]; then
    rm -rf -- "$isolation_cache_dir"
  fi
}
trap cleanup EXIT

# 검증 도구 자체가 격리 없이는 실제 저장을 건드리지 않는지 먼저 회귀 검사한다(#17).
bash "$repo_root/scripts/check_save_isolation.sh"

# 세이브 스키마 버전 판독 지점을 지운 변이에서 회귀 검사가 실패하는지 확인한다(#45).
bash "$repo_root/scripts/check_save_schema_self_test.sh"

run_godot_check() {
  local label="$1"
  local success_marker="$2"
  shift 2
  local log_file="$log_dir/$label.log"

  echo "[keeum-check] running $label: $*" >&2
  set +e
  "$@" 2>&1 | tee "$log_file"
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "[keeum-check] $label failed with exit $status" >&2
    exit "$status"
  fi
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log_file"; then
    echo "[keeum-check] $label emitted a Godot error" >&2
    grep -E '^(SCRIPT ERROR|ERROR):' "$log_file" >&2 || true
    exit 1
  fi
  if ! grep -Fq "$success_marker" "$log_file"; then
    echo "[keeum-check] $label did not emit its success marker" >&2
    exit 1
  fi
}

GODOT_QUALITY_GATE_LOG_DIR="$log_dir/quality" \
  bash "$repo_root/scripts/godot_quality_gate.sh" --project "$repo_root" --isolate-user-data

run_godot_check \
  "save-probe" \
  "세이브 검증 통과" \
  "$repo_root/scripts/run_godot_isolated.sh" "save-probe" -- \
    --headless --script res://tools/save_probe.gd

run_godot_check \
  "autoplay" \
  "모든 검증 통과" \
  "$repo_root/scripts/run_godot_isolated.sh" "autoplay" -- \
    --headless --script res://tools/autoplay.gd

run_godot_check \
  "ui-smoke" \
  "UI 스모크 완료" \
  "$repo_root/scripts/run_godot_isolated.sh" "ui-smoke" -- \
    --headless -- --ui-smoke

echo "[keeum-check] all checks passed"
