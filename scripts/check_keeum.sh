#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
log_dir="${KEEUM_CHECK_LOG_DIR:-}"
owns_log_dir=0

if [[ -z "$log_dir" ]]; then
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-check.XXXXXX")"
  owns_log_dir=1
else
  mkdir -p "$log_dir"
fi

# 실행 전용 격리 저장 공간(#17). Godot 의 user:// 는 프로젝트 이름 기준으로 공유되므로
# checkout 을 분리해도 같은 컴퓨터의 실제 플레이 저장을 가리킨다. 매 실행마다 고유
# 디렉터리를 만들어 XDG_DATA_HOME 으로 넘기면 이 실행의 user:// 가 통째로 여기로
# 옮겨간다 — 실제 저장 경로·다른 동시 실행과 절대 겹치지 않는다.
user_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-check-userdir.XXXXXX")"
export KEEUM_TEST_USER_DIR="$user_dir"
export XDG_DATA_HOME="$user_dir"

cleanup() {
  if [[ "$owns_log_dir" -eq 1 && -n "${log_dir:-}" && "$log_dir" != "/" ]]; then
    rm -rf -- "$log_dir"
  fi
  if [[ -n "${user_dir:-}" && "$user_dir" != "/" ]]; then
    rm -rf -- "$user_dir"
  fi
}
trap cleanup EXIT

# 검증 도구 자체가 격리 없이는 실제 저장을 건드리지 않는지 먼저 회귀 검사한다(#17).
bash "$repo_root/scripts/check_save_isolation.sh"

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
  "save-probe" \
  "세이브 검증 통과" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/save_probe.gd

run_godot_check \
  "autoplay" \
  "모든 검증 통과" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/autoplay.gd

run_godot_check \
  "ui-smoke" \
  "UI 스모크 완료" \
  "$godot_bin" --headless --path "$repo_root" -- --ui-smoke

echo "[keeum-check] all checks passed"
