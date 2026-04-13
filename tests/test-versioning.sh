#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPECTED_VERSION="1.1.0"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "script versioning"

assert_script_version() {
  local script_path="$1"
  local output=""
  local status=0

  output=$(bash "$REPO_ROOT/$script_path" --version 2>&1)
  status=$?
  assert_success "$status" "$script_path --version succeeds"
  assert_eq "harness-engineering $EXPECTED_VERSION" "$output" "$script_path version output"
}

it "keeps skill metadata and changelog aligned with the current release"
skill_version=$(sed -n '/^---$/,/^---$/p' "$REPO_ROOT/SKILL.md" 2>/dev/null | grep "^  version:" | sed 's/  version: *//')
assert_eq "\"$EXPECTED_VERSION\"" "$skill_version" "SKILL metadata version"
assert_file_contains "$REPO_ROOT/CHANGELOG.md" "## $EXPECTED_VERSION"

it "reports the current release from every top-level script"
while IFS= read -r script_path; do
  script_path="${script_path#$REPO_ROOT/}"
  assert_script_version "$script_path"
done < <(find "$REPO_ROOT/scripts" -maxdepth 1 -type f -name '*.sh' | sort)

print_summary
