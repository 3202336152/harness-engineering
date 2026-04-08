#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "prepare-template-overrides.sh"

it "exports a selected template into the project override directory"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/prepare-template-overrides.sh" --template feature/overview.md.tpl 2>&1)
status=$?
assert_success "$status" "template export command succeeds"
assert_file_exists ".harness/templates/feature/overview.md.tpl"
assert_file_contains ".harness/templates/feature/overview.md.tpl" "# 功能概览"
assert_json_field "$output" ".status" "success"
teardown_test_dir

it "does not overwrite an exported template unless force is provided"
setup_test_dir
init_git_repo
mkdir -p .harness/templates/feature
cat > .harness/templates/feature/overview.md.tpl <<'EOF'
# custom
EOF
output=$(bash "$REPO_ROOT/scripts/prepare-template-overrides.sh" --template feature/overview.md.tpl 2>&1)
status=$?
assert_success "$status" "template export command succeeds without force"
assert_file_contains ".harness/templates/feature/overview.md.tpl" "# custom"
assert_json_number_gte "$output" ".skipped_files | length" "1"
teardown_test_dir

print_summary
