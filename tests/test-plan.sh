#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

seed_project_docs() {
  mkdir -p docs/exec-plans/active
  cat > AGENTS.md <<'EOF'
# Sample Project

## Quick Commands

```bash
npm test
```
EOF
  cat > docs/ARCHITECTURE.md <<'EOF'
# Architecture

This project uses a layered structure with repo, service, and UI slices.
EOF
  cat > docs/CONVENTIONS.md <<'EOF'
# Conventions

Prefer existing abstractions and keep files small.
EOF
  cat > docs/TESTING.md <<'EOF'
# Testing

Use npm test and keep coverage above 80% for new behavior.
EOF
}

describe "plan-harness.sh"

it "creates an execution plan file for a requested task"
setup_test_dir
init_git_repo
seed_project_docs
output=$(bash "$REPO_ROOT/scripts/plan-harness.sh" --task "Add user search" --agent codex-test 2>&1)
status=$?
assert_success "$status" "plan command succeeds"
assert_file_exists "docs/exec-plans/active/add-user-search.md"
assert_file_contains "docs/exec-plans/active/add-user-search.md" "# Execution Plan: Add user search"
assert_file_contains "docs/exec-plans/active/add-user-search.md" "## Constraints"
assert_file_contains "docs/exec-plans/active/add-user-search.md" "## Acceptance Criteria"
assert_file_contains "docs/exec-plans/active/add-user-search.md" "docs/project/ARCHITECTURE.md"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".title" "Add user search"
assert_json_field "$output" ".references[0]" "docs/project/ARCHITECTURE.md"
teardown_test_dir

it "supports dry-run without writing a plan file"
setup_test_dir
init_git_repo
seed_project_docs
output=$(bash "$REPO_ROOT/scripts/plan-harness.sh" --task "Add billing dashboard" --dry-run 2>&1)
status=$?
assert_success "$status" "plan dry-run succeeds"
assert_file_not_exists "docs/exec-plans/active/add-billing-dashboard.md"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".dry_run" "true"
teardown_test_dir

it "keeps Chinese task titles as readable plan filenames"
setup_test_dir
init_git_repo
seed_project_docs
output=$(bash "$REPO_ROOT/scripts/plan-harness.sh" --task "新增 用户搜索" --agent codex-test 2>&1)
status=$?
assert_success "$status" "plan command succeeds for Chinese task title"
assert_file_exists "docs/exec-plans/active/新增-用户搜索.md"
assert_file_contains "docs/exec-plans/active/新增-用户搜索.md" "# Execution Plan: 新增 用户搜索"
assert_json_field "$output" ".path" "docs/exec-plans/active/新增-用户搜索.md"
teardown_test_dir

print_summary
