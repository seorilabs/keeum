#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
  echo "[android-build] $*" >&2
  exit 1
}

for required in build.env export_presets.cfg scripts/install_android_build_template.sh; do
  [[ -f "$required" ]] || fail "필수 소스가 없다: $required"
done

set -a
# shellcheck disable=SC1091
. ./build.env
set +a

for tool in godot java keytool jarsigner python3 unzip; do
  command -v "$tool" >/dev/null 2>&1 || fail "빌더 이미지에 $tool 이 없다"
done

engine="$(godot --version | head -1)"
case "$engine" in
  "${GODOT_VERSION}.${GODOT_STATUS}"*) ;;
  *) fail "Godot 버전 불일치: image=$engine contract=${GODOT_VERSION}.${GODOT_STATUS}" ;;
esac

[[ "${SEORI_BUILD_MODE:-}" == "build-only" ]] \
  || fail "이 진입점은 중앙 build-only 전용이다"
: "${SEORI_SOURCE_SHA:?SEORI_SOURCE_SHA가 필요하다}"
[[ "$SEORI_SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]] \
  || fail "SEORI_SOURCE_SHA는 소문자 full commit SHA여야 한다"

if [[ -e .git ]]; then
  actual_sha="$(git rev-parse 'HEAD^{commit}')"
  [[ "$actual_sha" == "$SEORI_SOURCE_SHA" ]] \
    || fail "checkout SHA와 중앙 binding SHA가 다르다"
fi

: "${SEORI_ANDROID_AAB_OUTPUT:?SEORI_ANDROID_AAB_OUTPUT이 필요하다}"
[[ "$SEORI_ANDROID_AAB_OUTPUT" = /* && "$SEORI_ANDROID_AAB_OUTPUT" == *.aab ]] \
  || fail "SEORI_ANDROID_AAB_OUTPUT은 절대 .aab 경로여야 한다"
output_parent="$(dirname "$SEORI_ANDROID_AAB_OUTPUT")"
mkdir -p "$output_parent"
canonical_output="$(cd "$output_parent" && pwd -P)/$(basename "$SEORI_ANDROID_AAB_OUTPUT")"
[[ "$canonical_output" == "$SEORI_ANDROID_AAB_OUTPUT" ]] \
  || fail "SEORI_ANDROID_AAB_OUTPUT은 canonical path여야 한다"

for secret_name in \
  GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64 \
  GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD \
  GOOGLE_PLAY_UPLOAD_KEY_PASSWORD \
  GOOGLE_PLAY_UPLOAD_KEY_ALIAS \
  ANDROID_KEYSTORE_BASE64 \
  ANDROID_KEYSTORE_PATH \
  ANDROID_KEYSTORE_PASSWORD \
  ANDROID_KEYSTORE_USER
do
  [[ -z "${!secret_name:-}" ]] \
    || fail "build-only 실행에 production signing 입력을 주입할 수 없다: $secret_name"
done

release_tag="${SEORI_RELEASE_TAG:-}"
release_name="${SEORI_RELEASE_VERSION_NAME:-}"
release_code="${SEORI_RELEASE_VERSION_CODE:-}"
if [[ -n "$release_tag" ]]; then
  python3 - "$release_tag" "$release_name" "$release_code" "$ANDROID_EXPORT_PRESET" <<'PY'
from pathlib import Path
import re
import sys

tag, version_name, version_code_text, preset_name = sys.argv[1:]
match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
if match is None:
    raise SystemExit("release tag는 exact stable SemVer여야 한다")
major, minor, patch = (int(value) for value in match.groups())
if major > 1099 or minor > 999 or patch > 999:
    raise SystemExit("release tag segment가 중앙 version authority 범위를 넘는다")
expected_name = f"{major}.{minor}.{patch}"
expected_code = 1_000_000_000 + major * 1_000_000 + minor * 1_000 + patch
if version_name != expected_name or version_code_text != str(expected_code):
    raise SystemExit("중앙 tag binding과 전달된 Android version이 다르다")

path = Path("export_presets.cfg")
text = path.read_text(encoding="utf-8")
sections = re.split(r"(?=^\[preset\.[0-9]+\]\s*$)", text, flags=re.MULTILINE)
matches = [
    index
    for index, section in enumerate(sections)
    if f'name="{preset_name}"' in section and 'platform="Android"' in section
]
if len(matches) != 1:
    raise SystemExit("버전을 주입할 Android preset이 유일하지 않다")
index = matches[0]
section, code_count = re.subn(
    r"^version/code=.*$", f"version/code={expected_code}", sections[index],
    count=1, flags=re.MULTILINE,
)
section, name_count = re.subn(
    r'^version/name=.*$', f'version/name="{expected_name}"', section,
    count=1, flags=re.MULTILINE,
)
if code_count != 1 or name_count != 1:
    raise SystemExit("Android preset version 필드를 유일하게 찾지 못했다")
sections[index] = section
path.write_text("".join(sections), encoding="utf-8")
PY
else
  [[ -z "$release_name" && -z "$release_code" ]] \
    || fail "release tag 없이 version 값만 전달할 수 없다"
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/keeum-android-build-only.XXXXXX")"
cleanup() {
  cleanup_status=$?
  rm -rf -- "$work_dir"
  return "$cleanup_status"
}
trap cleanup EXIT

keystore="$work_dir/build-only.jks"
keystore_password="seori-${SEORI_SOURCE_SHA:0:24}"
SEORI_EPHEMERAL_KEYSTORE_PASSWORD="$keystore_password" \
  keytool -genkeypair -noprompt \
    -keystore "$keystore" \
    -storetype JKS \
    -storepass:env SEORI_EPHEMERAL_KEYSTORE_PASSWORD \
    -keypass:env SEORI_EPHEMERAL_KEYSTORE_PASSWORD \
    -alias seori-build-only \
    -keyalg RSA \
    -keysize 2048 \
    -validity 1 \
    -dname "CN=Seorilabs Build Only, OU=CI, O=Seorilabs, C=KR" >/dev/null 2>&1

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=seori-build-only
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$keystore_password"
export GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD="$keystore_password"

bash "$SCRIPTS_DIR/install_android_build_template.sh"

run_godot() {
  local label="$1"
  shift
  local log_file="$work_dir/$label.log"
  set +e
  godot "$@" 2>&1 | tee "$log_file"
  local status="${PIPESTATUS[0]}"
  set -e
  [[ "$status" -eq 0 ]] || fail "Godot $label exit=$status"
  if grep -Eq '^(SCRIPT ERROR|ERROR):' "$log_file"; then
    fail "Godot $label 로그에 오류가 있다"
  fi
}

run_godot import --headless --path "$PROJECT_DIR" --import --quit
run_godot export --headless --path "$PROJECT_DIR" \
  --export-release "$ANDROID_EXPORT_PRESET" "$canonical_output"

[[ -s "$canonical_output" ]] || fail "AAB가 생성되지 않았다"
unzip -tq "$canonical_output" >/dev/null
verify_output="$(LC_ALL=C jarsigner -verify "$canonical_output" 2>&1)" \
  || fail "build-only AAB 서명 검증 명령이 실패했다"
[[ "$verify_output" == *"jar verified."* ]] \
  || fail "build-only AAB가 실제로 서명되지 않았다"
echo "build-only AAB 완료: bytes=$(wc -c < "$canonical_output" | tr -d ' '), source=$SEORI_SOURCE_SHA"
