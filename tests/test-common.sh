#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "common.sh"

it "json_escape produces valid JSON-safe output for control characters"
setup_test_dir
cat > probe-json-escape.sh <<EOF
#!/bin/bash
set -euo pipefail
. "$REPO_ROOT/scripts/lib/common.sh"
value=\$'A\bB\fC\tD\nE\rF\001'
escaped="\$(json_escape "\$value")"
printf '"%s"' "\$escaped"
EOF
chmod +x probe-json-escape.sh
output=$(bash ./probe-json-escape.sh 2>&1)
status=$?
assert_success "$status" "json escape probe succeeds"
if printf '%s' "$output" | jq -e . >/dev/null 2>&1; then
  pass_test "escaped payload parses as JSON"
else
  fail_test "escaped payload is invalid JSON"
fi
actual_hex=$(printf '%s' "$output" | jq -j . | od -An -t x1 | tr -d ' \n')
expected_hex=$(printf 'A\bB\fC\tD\nE\rF\001' | od -An -t x1 | tr -d ' \n')
assert_eq "$expected_hex" "$actual_hex" "escaped payload round-trips through jq"
teardown_test_dir

print_summary
