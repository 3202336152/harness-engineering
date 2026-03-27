#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "init-harness.sh"

it "creates the core harness structure in an empty git repo"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app 2>&1)
status=$?
assert_success "$status" "init command succeeds"
assert_file_exists "AGENTS.md"
assert_file_exists "CLAUDE.md"
assert_file_exists "docs/ARCHITECTURE.md"
assert_file_exists "docs/CONVENTIONS.md"
assert_file_exists "docs/TESTING.md"
assert_file_exists "docs/SECURITY.md"
assert_file_exists "docs/design-docs/core-beliefs.md"
assert_file_exists ".github/PULL_REQUEST_TEMPLATE.md"
assert_file_exists ".harness/architecture.json"
assert_dir_exists "docs/exec-plans/active"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".project" "sample-app"
assert_json_field "$output" ".detected_stack" "unknown"
teardown_test_dir

it "detects a node project and fills npm commands"
setup_test_dir
init_git_repo
cat > package.json <<'EOF'
{"name":"sample-app","scripts":{"test":"npm test"}}
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" 2>&1)
status=$?
assert_success "$status" "init command succeeds on node project"
assert_json_field "$output" ".detected_stack" "node"
assert_file_contains "AGENTS.md" "npm install"
assert_file_contains "docs/TESTING.md" "npm test"
teardown_test_dir

it "does not overwrite AGENTS.md unless force is provided"
setup_test_dir
init_git_repo
cat > AGENTS.md <<'EOF'
# Custom Agent Notes
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" 2>&1)
status=$?
assert_success "$status" "init command succeeds without force"
assert_file_contains "AGENTS.md" "Custom Agent Notes"
assert_json_number_gte "$output" ".skipped_files | length" "1"
teardown_test_dir

it "does not create files during dry-run"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --dry-run 2>&1)
status=$?
assert_success "$status" "init dry-run succeeds"
assert_file_not_exists "AGENTS.md"
assert_dir_not_exists "docs"
assert_json_field "$output" ".status" "success"
assert_json_number_gte "$output" ".created_files | length" "8"
teardown_test_dir

print_summary
