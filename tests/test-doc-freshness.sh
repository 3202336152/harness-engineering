#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

commit_with_date() {
  local message="$1"
  local commit_date="$2"
  git add -A >/dev/null 2>&1
  GIT_AUTHOR_DATE="$commit_date" GIT_COMMITTER_DATE="$commit_date" git commit -m "$message" --quiet >/dev/null 2>&1
}

describe "check-doc-freshness.sh"

it "marks old committed docs as stale"
setup_test_dir
init_git_repo
mkdir -p harness/docs/project
cat > harness/docs/project/项目架构.md <<'EOF'
# Architecture
Old doc.
EOF
commit_with_date "old docs" "2025-01-01T00:00:00Z"
output=$(bash "$REPO_ROOT/scripts/check-doc-freshness.sh" --threshold 30 --json 2>&1)
status=$?
assert_success "$status" "doc freshness command succeeds"
assert_json_field "$output" ".status" "warning"
assert_json_number_gte "$output" ".stale_count" "1"
teardown_test_dir

it "passes when docs are fresh"
setup_test_dir
init_git_repo
mkdir -p harness/docs/project
cat > harness/docs/project/项目架构.md <<'EOF'
# Architecture
Fresh doc.
EOF
git add -A >/dev/null 2>&1
git commit -m "fresh docs" --quiet >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/check-doc-freshness.sh" --threshold 30 --json 2>&1)
status=$?
assert_success "$status" "doc freshness command succeeds"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".stale_count" "0"
teardown_test_dir

it "handles markdown file paths that contain spaces"
setup_test_dir
init_git_repo
mkdir -p harness/docs/project
cat > "harness/docs/project/项目 架构 v2.md" <<'EOF'
# 项目架构
历史版本。
EOF
commit_with_date "docs with spaces" "2025-01-01T00:00:00Z"
output=$(bash "$REPO_ROOT/scripts/check-doc-freshness.sh" --threshold 30 --json 2>&1)
status=$?
assert_success "$status" "doc freshness handles spaced file paths"
assert_json_field "$output" ".status" "warning"
assert_json_field "$output" ".stale_count" "1"
assert_json_field "$output" '.stale_files[0].file' "harness/docs/project/项目 架构 v2.md"
teardown_test_dir

print_summary
