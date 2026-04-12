#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "publish-check.sh"

it "runs the local publish-readiness checks successfully"
output=$(bash "$REPO_ROOT/scripts/publish-check.sh" --skip-official 2>&1)
status=$?
assert_success "$status" "publish check succeeds with local-only mode"
if printf '%s' "$output" | grep -q "Publish readiness checks passed"; then
  pass_test "publish check output confirms success"
else
  fail_test "publish check output missing success marker"
fi

it "covers more than one agent in official smoke-test configuration"
assert_file_contains "$REPO_ROOT/scripts/publish-check.sh" "codex,claude-code"
assert_file_contains "$REPO_ROOT/scripts/publish-check.sh" "project install smoke test ("

print_summary
