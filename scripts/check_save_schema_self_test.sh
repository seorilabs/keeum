#!/usr/bin/env bash
set -euo pipefail

## #45 self-test: SaveSchema.classify() 의 "이 코드가 아는 것보다 높은 버전은 거부한다"
## 판독 지점을 지운 변이에서 save_probe.gd 의 스키마 회귀 시나리오가 실패하는지 확인한다.
## 이 검사가 없으면 새 회귀 시나리오가 실은 아무것도 검증하지 못하는 공백 통과일 수 있다
## (저장소의 기존 관례 — check_save_isolation.sh 의 run_without_marker 와 같은 취지: 안전
## 장치를 없앤 상태에서 검사가 실제로 잡아내는지 실증한다).
##
## 변이는 이 스크립트 실행 중에만 존재하고, 성공·실패·중단 어떤 경우에도 반드시 원복한다.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
isolated_runner="$repo_root/scripts/run_godot_isolated.sh"
target="$repo_root/core/save_schema.gd"

fail() {
  echo "[schema-self-test] $*" >&2
  exit 1
}

[[ -f "$target" ]] || fail "변이 대상 파일이 없다: $target"
grep -Fq 'return RESULT_REJECT' "$target" \
  || fail "변이 대상 지점을 찾지 못했다: $target 의 'return RESULT_REJECT'"

backup="$(mktemp "${TMPDIR:-/tmp}/keeum-schema-self-test-backup.XXXXXX")"
log_file="$(mktemp "${TMPDIR:-/tmp}/keeum-schema-self-test-log.XXXXXX")"
cp "$target" "$backup"

cleanup() {
  cp "$backup" "$target"
  rm -f "$backup" "$log_file"
}
trap cleanup EXIT

# in-place(-i) 대신 파일로 다시 써서 GNU/BSD sed 차이를 피한다.
sed 's/return RESULT_REJECT/return RESULT_CURRENT/' "$backup" > "$target"

echo "[schema-self-test] 판독 지점(높은 버전 거부)을 지운 변이에서 save-probe가 실패해야 한다" >&2
set +e
GODOT_BIN="$godot_bin" "$isolated_runner" "schema-self-test-mutant" -- \
  --headless --script res://tools/save_probe.gd > "$log_file" 2>&1
mutant_status=$?
set -e

if [[ "$mutant_status" -eq 0 ]]; then
  cat "$log_file" >&2
  fail "판독 지점을 지운 변이에서도 save-probe가 통과했다 — 스키마 회귀 검사가 공백이다"
fi

echo "[schema-self-test] OK — 변이가 새 회귀 시나리오에 잡혔다(exit $mutant_status)"
