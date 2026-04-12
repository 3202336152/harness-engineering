#!/bin/bash

set -u

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""
TEST_TMP=""

describe() {
  echo
  echo "=== $1 ==="
}

it() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

setup_test_dir() {
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/harness-engineering-test.XXXXXX")"
  cd "$TEST_TMP" || exit 1
}

init_git_repo() {
  git init --quiet >/dev/null 2>&1
  git config user.name "Harness Test"
  git config user.email "harness-test@example.com"
}

teardown_test_dir() {
  if [ -n "$TEST_TMP" ] && [ -d "$TEST_TMP" ]; then
    chmod -R u+w "$TEST_TMP" >/dev/null 2>&1 || true
    rm -rf "$TEST_TMP"
  fi
  TEST_TMP=""
}

fail_test() {
  local message="$1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: $CURRENT_TEST ($message)"
}

pass_test() {
  local message="$1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: $CURRENT_TEST${message:+ ($message)}"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"
  if [ "$expected" = "$actual" ]; then
    pass_test "$message"
  else
    fail_test "${message:-values differ}"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_success() {
  local status="$1"
  local message="${2:-command succeeded}"
  if [ "$status" -eq 0 ]; then
    pass_test "$message"
  else
    fail_test "$message"
    echo "    exit code: $status"
  fi
}

assert_file_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    pass_test "file exists: $file"
  else
    fail_test "file missing: $file"
  fi
}

assert_file_not_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    pass_test "file absent: $file"
  else
    fail_test "file unexpectedly exists: $file"
  fi
}

assert_dir_exists() {
  local dir="$1"
  if [ -d "$dir" ]; then
    pass_test "dir exists: $dir"
  else
    fail_test "dir missing: $dir"
  fi
}

assert_dir_not_exists() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    pass_test "dir absent: $dir"
  else
    fail_test "dir unexpectedly exists: $dir"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass_test "contains: $pattern"
  else
    fail_test "$file missing pattern: $pattern"
  fi
}

assert_files_equal() {
  local expected_file="$1"
  local actual_file="$2"
  local message="${3:-files are equal}"
  if cmp -s "$expected_file" "$actual_file" 2>/dev/null; then
    pass_test "$message"
  else
    fail_test "$message"
    echo "    expected file: $expected_file"
    echo "    actual file:   $actual_file"
  fi
}

assert_json_field() {
  local json="$1"
  local field="$2"
  local expected="$3"
  local actual
  actual=$(printf '%s' "$json" | jq -r "$field" 2>/dev/null)
  assert_eq "$expected" "$actual" "JSON $field"
}

assert_json_number_gte() {
  local json="$1"
  local field="$2"
  local minimum="$3"
  local actual
  actual=$(printf '%s' "$json" | jq -r "$field" 2>/dev/null)
  if [ -n "$actual" ] && [ "$actual" -ge "$minimum" ]; then
    pass_test "JSON $field >= $minimum"
  else
    fail_test "JSON $field below $minimum"
    echo "    actual: $actual"
  fi
}

print_summary() {
  echo
  echo "================================"
  echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
  echo "================================"
  [ "$TESTS_FAILED" -eq 0 ]
}
