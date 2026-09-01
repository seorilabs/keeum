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

if git -C "$repo_root" ls-files | grep -Eq '(^|/)(build|raw)/|(^|/)\.godot/|\.import$|(^|/)qa_sheet\.png$'; then
  fail "generated build, raw, QA, or import files must not be tracked"
fi

echo "fleet source contract: OK"
