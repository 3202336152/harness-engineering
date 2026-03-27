#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

SKILLMD="$REPO_ROOT/SKILL.md"

describe "SKILL.md compliance"

it "exists at the repository root"
assert_file_exists "$SKILLMD"

it "uses the expected skill name"
name=$(sed -n '/^---$/,/^---$/p' "$SKILLMD" 2>/dev/null | grep "^name:" | sed 's/name: *//')
assert_eq "harness-engineering" "$name" "frontmatter name"

it "keeps the body below 500 lines"
frontmatter_end=$(grep -n "^---$" "$SKILLMD" 2>/dev/null | tail -1 | cut -d: -f1)
if [ -n "$frontmatter_end" ]; then
  total_lines=$(wc -l < "$SKILLMD")
  body_lines=$((total_lines - frontmatter_end))
else
  body_lines=9999
fi
if [ "$body_lines" -lt 500 ]; then
  pass_test "body lines ($body_lines) < 500"
else
  fail_test "body lines ($body_lines) >= 500"
fi

it "passes the repository spec verification script"
output=$(bash "$REPO_ROOT/scripts/verify-spec-compliance.sh" 2>&1)
status=$?
assert_success "$status" "verify-spec-compliance succeeds"
if printf '%s' "$output" | grep -q "PASSED"; then
  pass_test "verification output says PASSED"
else
  fail_test "verification output missing PASSED"
fi

print_summary
