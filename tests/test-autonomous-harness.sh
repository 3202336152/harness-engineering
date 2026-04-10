#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "autonomous harness"

it "resolves a task context bundle for an existing feature"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-010 --title "Order Query" --owner alice --change-types api >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/resolve-task-context.sh" --task "Order Query" --feature-id FEAT-010 --json --write-bundle .harness/runtime/context/order-query.json 2>&1)
status=$?
assert_success "$status" "context resolution succeeds"
assert_file_exists ".harness/runtime/context/order-query.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".feature_id" "FEAT-010"
assert_json_field "$output" '.required_context | index("docs/project/项目架构.md") != null' "true"
assert_json_field "$output" '.required_context | index("docs/features/FEAT-010-order-query/功能概览.md") != null' "true"
teardown_test_dir

it "prepare stage creates feature spec, machine plan, and context bundle"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" prepare --task "Order Query" --feature-id FEAT-011 --title "Order Query" --owner alice --change-types api --agent codex-test --json 2>&1)
status=$?
assert_success "$status" "prepare stage succeeds"
assert_file_exists "docs/features/FEAT-011-order-query/功能概览.md"
assert_file_exists "docs/features/FEAT-011-order-query/manifest.json"
assert_file_exists "docs/exec-plans/active/order-query.md"
assert_file_exists "docs/exec-plans/active/order-query.json"
assert_file_exists ".harness/runtime/context/order-query.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".feature_created" "true"
assert_json_field "$output" ".context.status" "success"
teardown_test_dir

it "verify stage aggregates harness checks"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-012 --title "Order Query" --owner alice --change-types rollout >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --feature-id FEAT-012 --json 2>&1)
status=$?
assert_success "$status" "verify stage succeeds"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".checks.spec_validation.status" "passed"
assert_json_field "$output" ".checks.doc_impact.status" "passed"
assert_json_field "$output" ".checks.rollback_readiness.status" "passed"
teardown_test_dir

print_summary
