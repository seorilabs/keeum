#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "fleet source contract: $*" >&2
  exit 1
}

project_files="$(git -C "$repo_root" ls-files | awk '/(^|\/)project\.godot$/ { print }')"
[[ "$project_files" == "project.godot" ]] \
  || fail "exactly one root project.godot must be tracked"

preset_files="$(git -C "$repo_root" ls-files | awk '/(^|\/)export_presets\.cfg$/ { print }')"
[[ "$preset_files" == "export_presets.cfg" ]] \
  || fail "exactly one root export_presets.cfg must be tracked"

preset_file="$repo_root/export_presets.cfg"
for required in build.env scripts/build-android.sh scripts/install_android_build_template.sh; do
  [[ "$(git -C "$repo_root" ls-files "$required")" == "$required" ]] \
    || fail "WorkflowBundle build source is not tracked: $required"
done
[[ "$(git -C "$repo_root" ls-files build/.gdignore)" == "build/.gdignore" ]] \
  || fail "tracked build/.gdignore is required to isolate generated exports"
[[ "$(rg -c '^platform="Android"$' "$preset_file")" -eq 1 ]] \
  || fail "exactly one Android export preset is required"
[[ "$(rg -c '^platform="iOS"$' "$preset_file")" -eq 1 ]] \
  || fail "exactly one iOS export preset is required"
[[ "$(rg -c '^package/unique_name="com\.seorilabs\.keeum"$' "$preset_file")" -eq 1 ]] \
  || fail "Android package must be com.seorilabs.keeum"
[[ "$(rg -c '^application/bundle_identifier="com\.seorilabs\.keeum"$' "$preset_file")" -eq 1 ]] \
  || fail "iOS bundle must be com.seorilabs.keeum"
[[ "$(rg -c '^application/app_store_team_id="HCDUXX4Z3X"$' "$preset_file")" -eq 1 ]] \
  || fail "iOS build target must use the active shared Apple team identity"
rg -q '^gradle_build/export_format=1$' "$preset_file" \
  || fail "Android export must produce an AAB"
rg -q '^application/export_project_only=true$' "$preset_file" \
  || fail "iOS build target must export an unsigned Xcode project"
[[ "$(rg -c '^exclude_filter="[^"]*build/\*' "$preset_file")" -eq 2 ]] \
  || fail "all market exports must exclude generated build artifacts"

if git -C "$repo_root" ls-files \
  | grep -Ev '^build/\.gdignore$' \
  | grep -Eq '(^|/)(build|raw)/|(^|/)\.godot/|\.import$|(^|/)qa_sheet\.png$'; then
  fail "generated build, raw, QA, or import files must not be tracked"
fi

echo "fleet source contract: OK"
