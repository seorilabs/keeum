#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="${KEEUM_CHECK_LOG_DIR:-}"
owns_log_dir=0

if [[ -z "$log_dir" ]]; then
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-check.XXXXXX")"
  owns_log_dir=1
else
  mkdir -p "$log_dir"
fi

cleanup() {
  if [[ "$owns_log_dir" -eq 1 && -n "${log_dir:-}" && "$log_dir" != "/" ]]; then
    rm -rf -- "$log_dir"
  fi
}
trap cleanup EXIT

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
  bash "$repo_root/scripts/godot_quality_gate.sh" --project "$repo_root"

run_godot_check \
  "autoplay" \
  "모든 검증 통과" \
  godot --headless --path "$repo_root" --script res://tools/autoplay.gd

run_godot_check \
  "ui-smoke" \
  "UI 스모크 완료" \
  godot --headless --path "$repo_root" -- --ui-smoke

echo "[keeum-check] all checks passed"
