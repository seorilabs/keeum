#!/usr/bin/env bash
set -euo pipefail

# 중앙 Godot Android workflow가 export 전에 호출한다. 단독
# --install-android-build-template은 Godot 4.7에서 작업 없이 대기할 수 있으므로,
# 설치된 공식 export template의 android_source.zip을 직접 전개한다.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="${GODOT_PROJECT_DIR:-${PROJECT_DIR:-$repo_root}}"
godot_bin="${GODOT_BIN:-godot}"

fail() {
  echo "[android-template] $*" >&2
  exit 1
}

[[ -d "$project_dir" ]] || fail "프로젝트 디렉터리 없음: $project_dir"
command -v "$godot_bin" >/dev/null 2>&1 || fail "Godot 바이너리를 찾을 수 없음: $godot_bin"
command -v unzip >/dev/null 2>&1 || fail "unzip이 필요함"

if [[ -n "${GODOT_VERSION:-}" ]]; then
  template_version="${GODOT_VERSION}.${GODOT_STATUS:-stable}"
else
  template_version="$("$godot_bin" --version | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.[^.]+).*/\1/')"
fi
[[ "$template_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[A-Za-z0-9_-]+$ ]] \
  || fail "Godot template 버전을 해석할 수 없음: $template_version"

case "$(uname -s)" in
  Darwin)
    config_dir="${HOME}/Library/Application Support/Godot"
    template_root="${HOME}/Library/Application Support/Godot/export_templates/$template_version"
    ;;
  *)
    config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/godot"
    template_root="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/export_templates/$template_version"
    ;;
esac

android_source="$template_root/android_source.zip"
[[ -f "$android_source" ]] \
  || fail "Android export template 없음: $android_source"

# Fresh CI에서는 Android SDK/JDK 환경을 Godot editor settings에도 기록해야 한다.
# 로컬에 환경변수가 없으면 기존 editor settings를 그대로 사용한다.
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
java_home="${JAVA_HOME:-}"
if [[ -z "$java_home" ]] && [[ "$(uname -s)" == "Darwin" ]] && [[ -x /usr/libexec/java_home ]]; then
  java_home="$(/usr/libexec/java_home 2>/dev/null || true)"
elif [[ -z "$java_home" ]] && command -v java >/dev/null 2>&1 && command -v readlink >/dev/null 2>&1; then
  java_path="$(readlink -f "$(command -v java)" 2>/dev/null || true)"
  [[ -n "$java_path" ]] && java_home="$(dirname "$(dirname "$java_path")")"
fi

if [[ -n "$sdk_root" && -n "$java_home" ]]; then
  mkdir -p "$config_dir"
  "$godot_bin" --headless --editor --quit-after 2 --path "$project_dir" >/dev/null 2>&1 || true
  minor_version="$(cut -d. -f1-2 <<<"$template_version")"
  settings_file="$config_dir/editor_settings-${minor_version}.tres"
  if [[ ! -f "$settings_file" ]]; then
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$settings_file"
  fi
  python3 - "$settings_file" "$sdk_root" "$java_home" <<'PY'
import re
import sys

path, sdk, java = sys.argv[1:]
with open(path, "r", encoding="utf-8") as source:
    text = source.read()


def upsert(value: str, key: str, replacement: str) -> str:
    line = f'{key} = "{replacement}"'
    pattern = re.compile(rf"^{re.escape(key)} = .*$", re.MULTILINE)
    if pattern.search(value):
        return pattern.sub(line, value)
    return value.rstrip() + "\n" + line + "\n"


text = upsert(text, "export/android/android_sdk_path", sdk)
text = upsert(text, "export/android/java_sdk_path", java)
with open(path, "w", encoding="utf-8") as destination:
    destination.write(text)
PY
fi

android_dir="$project_dir/android"
build_dir="$android_dir/build"
version_marker="$android_dir/.build_version"
installed_version=""
[[ -f "$version_marker" ]] && installed_version="$(tr -d '\r\n' < "$version_marker")"

if [[ "$installed_version" != "$template_version" || ! -f "$build_dir/build.gradle" ]]; then
  rm -rf -- "$build_dir"
  mkdir -p "$build_dir"
  unzip -q -o "$android_source" -d "$build_dir"
  printf '%s\n' "$template_version" > "$version_marker"
  touch "$android_dir/.gdignore"
fi

[[ -f "$build_dir/build.gradle" ]] || fail "android/build/build.gradle 설치 실패"
[[ -f "$build_dir/gradlew" ]] && chmod +x "$build_dir/gradlew"
echo "[android-template] installed $template_version"
