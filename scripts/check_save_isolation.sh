#!/usr/bin/env bash
set -euo pipefail
## 검증 도구 자신이 실제 사용자 저장을 건드리지 않는지 확인하는 회귀 테스트(#17).
## Godot 의 user:// 는 프로젝트 이름 기준으로 공유되므로, 격리(XDG_DATA_HOME/
## KEEUM_TEST_USER_DIR) 없이 save_probe 나 --ui-smoke 를 직접 실행하면 같은 컴퓨터의
## 실제 플레이 저장을 지울 수 있었다. 가짜 "실제 사용자" 저장 루트를 만들어 두고,
## 격리 없는 실행이 안전하게 거부하는지·격리를 걸면 그 가짜 파일이 바이트 단위로
## 그대로인지를 검사한다.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"

fake_real_root="$(mktemp -d "${TMPDIR:-/tmp}/keeum-fake-real.XXXXXX")"
isolated_root="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-check.XXXXXX")"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-check-log.XXXXXX")"

cleanup() {
  rm -rf -- "$fake_real_root" "$isolated_root" "$log_dir"
}
trap cleanup EXIT

fail() {
  echo "[save-isolation-check] $*" >&2
  exit 1
}

project_name="$(sed -nE 's/^config\/name="(.*)"$/\1/p' "$repo_root/project.godot" | head -n1)"
[[ -n "$project_name" ]] || fail "project.godot 에서 config/name 을 읽지 못했다"

fake_real_userdir="$fake_real_root/godot/app_userdata/$project_name"
mkdir -p "$fake_real_userdir"
fake_save="$fake_real_userdir/keeum_save.json"
printf '%s' '{"profile": {"collected_endings": ["automation_audit_sentinel"], "premium": 791}, "run": {}}' \
  > "$fake_save"
before_sha="$(sha256sum "$fake_save" | awk '{print $1}')"

assert_untouched() {
  local label="$1"
  [[ -f "$fake_save" ]] || fail "$label 이후 가짜 실제 저장 파일 자체가 사라졌다"
  local after_sha
  after_sha="$(sha256sum "$fake_save" | awk '{print $1}')"
  [[ "$after_sha" == "$before_sha" ]] \
    || fail "$label 이 가짜 실제 저장을 건드렸다 (전 $before_sha 후 $after_sha)"
}

run_unisolated() {
  local label="$1"
  local log_file="$log_dir/$label.log"
  shift
  echo "[save-isolation-check] $label: 격리 없이 실행 — 거부해야 한다" >&2
  if env -u KEEUM_TEST_USER_DIR XDG_DATA_HOME="$fake_real_root" \
      "$godot_bin" --headless --path "$repo_root" "$@" > "$log_file" 2>&1; then
    cat "$log_file" >&2
    fail "$label 이 격리 없이도 거부하지 않고 성공했다(마지막 방어선까지 뚫렸다)"
  fi
  assert_untouched "$label"
}

run_unisolated "save_probe-no-isolation" --script res://tools/save_probe.gd
run_unisolated "ui-smoke-no-isolation" -- --ui-smoke

echo "[save-isolation-check] 격리를 걸면 save_probe 가 통과한다" >&2
env XDG_DATA_HOME="$isolated_root" KEEUM_TEST_USER_DIR="$isolated_root" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/save_probe.gd \
  > "$log_dir/save_probe-isolated.log" 2>&1 \
  || { cat "$log_dir/save_probe-isolated.log" >&2; fail "격리된 save_probe 가 실패했다"; }
grep -Fq "세이브 검증 통과" "$log_dir/save_probe-isolated.log" \
  || fail "격리된 save_probe 가 성공 마커를 남기지 않았다"
assert_untouched "격리된 save_probe"

echo "[save-isolation-check] OK — 가짜 실제 저장이 실행 전후로 바이트 단위로 동일했다"
