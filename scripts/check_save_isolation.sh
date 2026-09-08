#!/usr/bin/env bash
set -euo pipefail

## 검증 도구가 실제 사용자 저장을 건드리지 않는지 확인하는 회귀 테스트(#20).
## Linux에서는 XDG_DATA_HOME을 임시 경로로 바꾸고, macOS에서는 HOME을 바꾸지
## 않은 채 고유한 config/name을 가진 임시 프로젝트로 user://를 분리한다.
## 원래 프로젝트의 실제 user://는 실행 전후 스냅샷이 동일해야 한다.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
isolated_runner="$repo_root/scripts/run_godot_isolated.sh"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-check-log.XXXXXX")"
isolation_cache_dir="${KEEUM_ISOLATION_CACHE_DIR:-}"
owns_isolation_cache=0

if [[ -z "$isolation_cache_dir" ]]; then
  isolation_cache_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-cache.XXXXXX")"
  owns_isolation_cache=1
fi
export KEEUM_ISOLATION_CACHE_DIR="$isolation_cache_dir"

cleanup() {
  if [[ -n "${log_dir:-}" && "$log_dir" == "${TMPDIR:-/tmp}/keeum-isolation-check-log."* ]]; then
    rm -rf -- "$log_dir"
  fi
  if [[ "$owns_isolation_cache" -eq 1 && -n "${isolation_cache_dir:-}" \
      && "$isolation_cache_dir" == "${TMPDIR:-/tmp}/keeum-isolation-cache."* ]]; then
    rm -rf -- "$isolation_cache_dir"
  fi
}
trap cleanup EXIT

fail() {
  echo "[save-isolation-check] $*" >&2
  exit 1
}

project_name="$(sed -nE 's/^config\/name="(.*)"$/\1/p' "$repo_root/project.godot" | head -n1)"
[[ -n "$project_name" ]] || fail "project.godot에서 config/name을 읽지 못했다"
real_user_dir="$("$isolated_runner" --print-real-user-dir "$project_name")" \
  || fail "실제 user:// 경로를 계산하지 못했다"

snapshot_real_user_dir() {
  if [[ ! -e "$real_user_dir" ]]; then
    printf 'ABSENT\n'
    return
  fi

  printf 'PRESENT\n'
  (
    cd "$real_user_dir"
    find . -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' path; do
      if [[ -L "$path" ]]; then
        printf 'LINK %s -> %s\n' "$path" "$(readlink "$path")"
      elif [[ -d "$path" ]]; then
        printf 'DIR %s\n' "$path"
      elif [[ -f "$path" ]]; then
        printf 'FILE %s ' "$path"
        shasum -a 256 "$path"
      else
        printf 'OTHER %s\n' "$path"
      fi
    done
  )
}

real_before="$(snapshot_real_user_dir)" \
  || fail "검증 전 실제 user:// 스냅샷을 만들지 못했다"

assert_real_user_dir_untouched() {
  local label="$1"
  local real_after
  real_after="$(snapshot_real_user_dir)" \
    || fail "$label 후 실제 user:// 스냅샷을 만들지 못했다"
  [[ "$real_after" == "$real_before" ]] \
    || fail "$label 실행이 실제 user://를 변경했다"
}

run_without_marker() {
  local label="$1"
  shift
  local log_file="$log_dir/$label.log"

  echo "[save-isolation-check] $label: 마커 없이 실행 — 거부해야 한다" >&2
  set +e
  GODOT_BIN="$godot_bin" "$isolated_runner" "$label" --without-marker --protect-fixtures -- \
    "$@" > "$log_file" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] \
    || { cat "$log_file" >&2; fail "${label}이 격리 마커 없이 성공했다"; }
  [[ "$status" -ne 97 ]] \
    || { cat "$log_file" >&2; fail "${label}이 보호 픽스처를 변경했다"; }
  grep -Fq "KEEUM_PROTECTED_FIXTURES_UNTOUCHED=1" "$log_file" \
    || { cat "$log_file" >&2; fail "${label}의 보호 픽스처 보존을 확인하지 못했다"; }
  assert_real_user_dir_untouched "$label"
}

run_without_marker "save-probe-no-marker" --headless --script res://tools/save_probe.gd
run_without_marker "ui-smoke-no-marker" --headless -- --ui-smoke
run_without_marker "ui-play-no-marker" --headless -- --ui-play

echo "[save-isolation-check] 격리된 save_probe가 통과하는지 확인" >&2
GODOT_BIN="$godot_bin" "$isolated_runner" "save-probe-positive" -- \
  --headless --script res://tools/save_probe.gd \
  > "$log_dir/save-probe-positive.log" 2>&1 \
  || { cat "$log_dir/save-probe-positive.log" >&2; fail "격리된 save_probe가 실패했다"; }
grep -Fq "세이브 검증 통과" "$log_dir/save-probe-positive.log" \
  || fail "격리된 save_probe가 성공 마커를 남기지 않았다"
assert_real_user_dir_untouched "격리된 save_probe"

echo "[save-isolation-check] 동시 실행 두 개가 서로 다른 user://를 쓰는지 확인" >&2
conc_log_a="$log_dir/concurrent-a.log"
conc_log_b="$log_dir/concurrent-b.log"

GODOT_BIN="$godot_bin" "$isolated_runner" "concurrent-a" -- \
  --headless --script res://tools/save_probe.gd > "$conc_log_a" 2>&1 &
conc_pid_a=$!
GODOT_BIN="$godot_bin" "$isolated_runner" "concurrent-b" -- \
  --headless --script res://tools/save_probe.gd > "$conc_log_b" 2>&1 &
conc_pid_b=$!

conc_status_a=0; wait "$conc_pid_a" || conc_status_a=$?
conc_status_b=0; wait "$conc_pid_b" || conc_status_b=$?
[[ "$conc_status_a" -eq 0 ]] \
  || { cat "$conc_log_a" >&2; fail "동시 실행 A가 실패했다(exit $conc_status_a)"; }
[[ "$conc_status_b" -eq 0 ]] \
  || { cat "$conc_log_b" >&2; fail "동시 실행 B가 실패했다(exit $conc_status_b)"; }
grep -Fq "세이브 검증 통과" "$conc_log_a" || fail "동시 실행 A의 성공 마커가 없다"
grep -Fq "세이브 검증 통과" "$conc_log_b" || fail "동시 실행 B의 성공 마커가 없다"
conc_user_dir_a="$(sed -n 's/^KEEUM_ISOLATED_USER_DIR=//p' "$conc_log_a" | head -n1)"
conc_user_dir_b="$(sed -n 's/^KEEUM_ISOLATED_USER_DIR=//p' "$conc_log_b" | head -n1)"
[[ -n "$conc_user_dir_a" && -n "$conc_user_dir_b" && "$conc_user_dir_a" != "$conc_user_dir_b" ]] \
  || fail "동시 실행 A/B의 격리 경로가 비어 있거나 같다"
assert_real_user_dir_untouched "동시 실행"

echo "[save-isolation-check] 정리가 성공·실패·중단에서도 소유한 경로로 제한되는지 확인" >&2

run_cleanup_ownership_case() {
  local label="$1" outcome="$2"
  local outside_marker
  outside_marker="$(mktemp "${TMPDIR:-/tmp}/keeum-cleanup-outside.XXXXXX")"
  printf 'untouched\n' > "$outside_marker"

  local script
  script="$(mktemp "${TMPDIR:-/tmp}/keeum-cleanup-case.XXXXXX.sh")"
  cat > "$script" <<EOS
#!/usr/bin/env bash
set -euo pipefail
own_dir="\$(mktemp -d "\${TMPDIR:-/tmp}/keeum-cleanup-own.XXXXXX")"
trap 'rm -rf -- "\$own_dir"' EXIT
echo "\$own_dir" > "${outside_marker}.owned"
: > "\$own_dir/marker"
case "$outcome" in
  success) exit 0 ;;
  failure) exit 1 ;;
  sigterm) kill -TERM \$\$ ; sleep 5 ;;
esac
EOS
  chmod +x "$script"

  if [[ "$outcome" == "sigterm" ]]; then
    bash "$script" & local case_pid=$!
    sleep 0.3
    kill -TERM "$case_pid" 2>/dev/null || true
    wait "$case_pid" 2>/dev/null || true
  else
    bash "$script" || true
  fi

  local owned_dir
  owned_dir="$(cat "${outside_marker}.owned" 2>/dev/null || true)"
  [[ -n "$owned_dir" ]] || fail "$label: 소유 디렉터리 경로를 기록하지 못했다"
  [[ ! -e "$owned_dir" ]] || fail "${label} 뒤에도 소유 디렉터리가 남았다: $owned_dir"
  [[ -f "$outside_marker" && "$(cat "$outside_marker")" == "untouched" ]] \
    || fail "${label}이 소유 범위 밖 파일을 변경했다: $outside_marker"

  rm -f -- "$outside_marker" "${outside_marker}.owned" "$script"
}

run_cleanup_ownership_case "정리 성공 종료" success
run_cleanup_ownership_case "정리 실패 종료" failure
run_cleanup_ownership_case "정리 SIGTERM 중단" sigterm

echo "[save-isolation-check] 평범한 --quit 실행의 기존 손상 격리 동작을 확인" >&2
GODOT_BIN="$godot_bin" "$isolated_runner" "plain-run" --without-marker --expect-quarantine -- \
  --headless --quit > "$log_dir/plain-run.log" 2>&1 \
  || { cat "$log_dir/plain-run.log" >&2; fail "평범한 --quit 실행이 실패했다"; }
grep -Fq "KEEUM_CORRUPT_QUARANTINED=1" "$log_dir/plain-run.log" \
  || { cat "$log_dir/plain-run.log" >&2; fail "기존 손상 격리 동작을 확인하지 못했다"; }
assert_real_user_dir_untouched "평범한 --quit"

echo "[save-isolation-check] OK — macOS/Linux 격리와 실제 user:// 보존을 확인했다"
