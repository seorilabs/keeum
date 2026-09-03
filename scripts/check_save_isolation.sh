#!/usr/bin/env bash
set -euo pipefail
## 검증 도구 자신이 실제 사용자 저장을 건드리지 않는지 확인하는 회귀 테스트(#17).
## Godot 의 user:// 는 프로젝트 이름 기준으로 공유되므로, 격리(XDG_DATA_HOME/
## KEEUM_TEST_USER_DIR) 없이 save_probe 나 --ui-smoke/--ui-play 를 직접 실행하면
## 같은 컴퓨터의 실제 플레이 저장을 지우거나 손상 격리로 덮어썼다. 이 스크립트는
## 이슈 #17 의 인수조건 6개를 각각 자동으로 재현·검사한다.
##
## AC-1  이 파일의 assert_fixtures_untouched() — 정상/백업/손상 3종 가짜 실제
##       저장을 미리 심고, 아래 모든 시나리오 전후로 세 파일의 SHA-256 이 그대로인지 검사.
## AC-2  run_unisolated 세 호출(save_probe/--ui-smoke/--ui-play) — 격리 없이 직접
##       실행하면 거부(0이 아닌 종료)하고 가짜 저장을 건드리지 않는지 검사.
## AC-3  "동시 실행" 절 — 서로 다른 격리 루트를 쓰는 두 실행을 병렬로 돌려 서로
##       간섭 없이 각자 통과하고 경로가 겹치지 않는지 검사.
## AC-4  "정리 소유권" 절 — 같은 mktemp+trap 관용구를 성공/실패/SIGTERM 세 경로로
##       돌려, 소유한 디렉터리만 지우고 그 바깥 파일은 안 건드리는지 검사.
## AC-5  "격리된 save_probe" 실행의 성공 마커 — save_probe.gd 의 기존 손상·복구·
##       쓰기실패 시나리오(_run_scenarios 2/3/4/6/7)가 격리 공간에서 그대로
##       통과하는지 검사(스크립트 자체는 수정하지 않았다).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"

fail() {
  echo "[save-isolation-check] $*" >&2
  exit 1
}

project_name="$(sed -nE 's/^config\/name="(.*)"$/\1/p' "$repo_root/project.godot" | head -n1)"
[[ -n "$project_name" ]] || fail "project.godot 에서 config/name 을 읽지 못했다"

fake_real_root="$(mktemp -d "${TMPDIR:-/tmp}/keeum-fake-real.XXXXXX")"
isolated_root="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-check.XXXXXX")"
log_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-isolation-check-log.XXXXXX")"

cleanup() {
  rm -rf -- "$fake_real_root" "$isolated_root" "$log_dir"
}
trap cleanup EXIT

# ------------------------------------------------------------------ AC-1
# 정상 저장뿐 아니라 백업·손상 격리 파일까지 실존 사용자 상태를 흉내 낸다.
fake_real_userdir="$fake_real_root/godot/app_userdata/$project_name"
mkdir -p "$fake_real_userdir"
printf '%s' '{"profile": {"collected_endings": ["automation_audit_sentinel"], "premium": 791}, "run": {}}' \
  > "$fake_real_userdir/keeum_save.json"
printf '%s' '{"profile": {"collected_endings": ["automation_audit_backup_sentinel"], "premium": 555}, "run": {}}' \
  > "$fake_real_userdir/keeum_save.json.bak"
printf '%s' 'not json at all -- quarantined corrupt sentinel' \
  > "$fake_real_userdir/keeum_save.json.corrupt"

fixture_shas() {
  ( cd "$fake_real_userdir" && sha256sum keeum_save.json keeum_save.json.bak keeum_save.json.corrupt )
}
fixtures_before="$(fixture_shas)"

assert_fixtures_untouched() {
  local label="$1"
  local now
  now="$(fixture_shas)" || fail "$label 이후 가짜 실제 저장 3종(정상/백업/손상) 중 일부가 사라졌다"
  [[ "$now" == "$fixtures_before" ]] \
    || fail "$label 이 가짜 실제 저장(정상/백업/손상)을 건드렸다:
$(diff <(echo "$fixtures_before") <(echo "$now") || true)"
}

# ------------------------------------------------------------------ AC-2
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
  assert_fixtures_untouched "$label"
}

run_unisolated "save_probe-no-isolation" --script res://tools/save_probe.gd
run_unisolated "ui-smoke-no-isolation" -- --ui-smoke
run_unisolated "ui-play-no-isolation" -- --ui-play

echo "[save-isolation-check] 격리를 걸면 save_probe 가 통과한다" >&2
env XDG_DATA_HOME="$isolated_root" KEEUM_TEST_USER_DIR="$isolated_root" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/save_probe.gd \
  > "$log_dir/save_probe-isolated.log" 2>&1 \
  || { cat "$log_dir/save_probe-isolated.log" >&2; fail "격리된 save_probe 가 실패했다"; }
# ------------------------------------------------------------------ AC-5
# save_probe.gd 자체는 바꾸지 않았다 — 이 성공 마커는 그 안의 기존 _run_scenarios()
# 시나리오 2/3/4/6/7(잘린 본 파일 복구·중단 후 재검증·쓰기 실패·백업 승격·손상 격리)이
# 격리된 user:// 안에서 그대로 실행되고 전부 통과했다는 뜻이다.
grep -Fq "세이브 검증 통과" "$log_dir/save_probe-isolated.log" \
  || fail "격리된 save_probe 가 성공 마커를 남기지 않았다"
assert_fixtures_untouched "격리된 save_probe"

# ------------------------------------------------------------------ AC-3
# 서로 다른 격리 루트를 쓰는 두 실행을 동시에 돌린다. 경로를 공유했다면 두 프로세스가
# 같은 저장/백업 파일을 동시에 왕복시켜 save_probe.gd 내부 _expect() 단언 중 최소
# 하나(직전 세대 백업 값 등)가 경쟁 상태로 깨졌을 것이다.
echo "[save-isolation-check] 동시 실행 두 개가 서로 다른 격리 공간을 쓰는지 확인" >&2
conc_a="$(mktemp -d "${TMPDIR:-/tmp}/keeum-concurrent-a.XXXXXX")"
conc_b="$(mktemp -d "${TMPDIR:-/tmp}/keeum-concurrent-b.XXXXXX")"
conc_log_a="$log_dir/concurrent-a.log"
conc_log_b="$log_dir/concurrent-b.log"

env XDG_DATA_HOME="$conc_a" KEEUM_TEST_USER_DIR="$conc_a" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/save_probe.gd \
  > "$conc_log_a" 2>&1 &
conc_pid_a=$!
env XDG_DATA_HOME="$conc_b" KEEUM_TEST_USER_DIR="$conc_b" \
  "$godot_bin" --headless --path "$repo_root" --script res://tools/save_probe.gd \
  > "$conc_log_b" 2>&1 &
conc_pid_b=$!

conc_status_a=0; wait "$conc_pid_a" || conc_status_a=$?
conc_status_b=0; wait "$conc_pid_b" || conc_status_b=$?
[[ "$conc_status_a" -eq 0 ]] || { cat "$conc_log_a" >&2; fail "동시 실행 A가 실패했다(exit $conc_status_a) — 격리가 새고 있을 수 있다"; }
[[ "$conc_status_b" -eq 0 ]] || { cat "$conc_log_b" >&2; fail "동시 실행 B가 실패했다(exit $conc_status_b) — 격리가 새고 있을 수 있다"; }
grep -Fq "세이브 검증 통과" "$conc_log_a" || fail "동시 실행 A가 성공 마커를 남기지 않았다"
grep -Fq "세이브 검증 통과" "$conc_log_b" || fail "동시 실행 B가 성공 마커를 남기지 않았다"
[[ "$(realpath "$conc_a")" != "$(realpath "$conc_b")" ]] \
  || fail "동시 실행 A/B 가 같은 격리 디렉터리를 공유했다"
rm -rf -- "$conc_a" "$conc_b"

# ------------------------------------------------------------------ AC-4
# check_keeum.sh/이 스크립트가 실제로 쓰는 것과 같은 관용구(mktemp -d 로 만든
# 자기 소유 디렉터리 + trap ... EXIT)가 성공·실패·SIGTERM 중단 세 경로 모두에서
# 자신이 만든 디렉터리만 지우고, 그 바깥의 파일은 그대로 두는지 확인한다.
echo "[save-isolation-check] 정리(cleanup)가 성공·실패·중단에서도 소유한 경로로만 제한되는지 확인" >&2

run_cleanup_ownership_case() {
  local label="$1" outcome="$2"  # outcome: success | failure | sigterm
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
  [[ ! -e "$owned_dir" ]] \
    || fail "$label 뒤에도 자신이 소유한 디렉터리($owned_dir)가 남아 있다"
  [[ -f "$outside_marker" && "$(cat "$outside_marker")" == "untouched" ]] \
    || fail "$label 이 소유 범위 밖의 파일($outside_marker)까지 건드렸다"

  rm -f -- "$outside_marker" "${outside_marker}.owned" "$script"
}

run_cleanup_ownership_case "정리(성공 종료)" success
run_cleanup_ownership_case "정리(실패 종료)" failure
run_cleanup_ownership_case "정리(SIGTERM 중단)" sigterm

echo "[save-isolation-check] OK — AC-1~5 를 전부 자동으로 재확인했다"
