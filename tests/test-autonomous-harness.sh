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
output=$(bash "$REPO_ROOT/scripts/resolve-task-context.sh" --task "Order Query" --feature-id FEAT-010 --json --write-bundle harness/.harness/runtime/context/order-query.json 2>&1)
status=$?
assert_success "$status" "context resolution succeeds"
assert_file_exists "harness/.harness/runtime/context/order-query.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".feature_id" "FEAT-010"
assert_json_field "$output" '.required_context | index("harness/docs/project/核心信念.md") != null' "true"
assert_json_field "$output" '.required_context | index("harness/docs/project/项目架构.md") != null' "true"
assert_json_field "$output" '.required_context | index("harness/docs/features/FEAT-010-order-query/功能概览.md") != null' "true"
teardown_test_dir

it "prepare stage creates feature spec, machine plan, and context bundle"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" prepare --task "Order Query" --feature-id FEAT-011 --title "Order Query" --owner alice --change-types api --agent codex-test --json 2>&1)
status=$?
assert_success "$status" "prepare stage succeeds"
assert_file_exists "harness/docs/features/FEAT-011-order-query/功能概览.md"
assert_file_exists "harness/docs/features/FEAT-011-order-query/manifest.json"
assert_file_exists "harness/.harness/exec-plans/active/order-query.md"
assert_file_exists "harness/.harness/exec-plans/active/order-query.json"
assert_file_exists "harness/.harness/runtime/context/order-query.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".feature_created" "true"
assert_json_field "$output" ".context.status" "success"
teardown_test_dir

it "prepare stage honors HARNESS_AGENT_NAME when --agent is omitted"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(HARNESS_AGENT_NAME="claude-code" bash "$REPO_ROOT/scripts/harness-exec.sh" prepare --task "Inventory Sync" --feature-id FEAT-014 --title "Inventory Sync" --owner alice --change-types api --json 2>&1)
status=$?
assert_success "$status" "prepare stage succeeds with env-based agent default"
assert_json_field "$output" ".status" "success"
assert_json_field "$(cat harness/.harness/exec-plans/active/inventory-sync.json)" ".agent" "claude-code"
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

it "restore stage reconstructs recent task state and context"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-013 --title "Order Query" --owner alice --change-types api >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --feature-id FEAT-013 --json 2>&1)
status=$?
assert_success "$status" "verify stage succeeds before restore"
restore_output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" restore --feature-id FEAT-013 --json 2>&1)
restore_status=$?
assert_success "$restore_status" "restore stage succeeds"
assert_json_field "$restore_output" ".status" "restored"
assert_json_field "$restore_output" ".session_restored" "true"
assert_json_field "$restore_output" ".last_feature_id" "FEAT-013"
assert_json_field "$restore_output" ".last_mode" "verify"
assert_json_field "$restore_output" ".feature_spec_exists" "true"
assert_json_field "$restore_output" '.pending_steps | length' "5"
assert_json_field "$restore_output" '.context_bundle | index("harness/docs/project/核心信念.md") != null' "true"
assert_json_field "$restore_output" '.context_bundle | index("harness/docs/project/项目架构.md") != null' "true"
assert_json_field "$restore_output" '.context_bundle | index("harness/docs/features/FEAT-013-order-query/功能概览.md") != null' "true"
teardown_test_dir

it "restore stage reports an empty session when no runtime history exists"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
restore_output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" restore --json 2>&1)
restore_status=$?
assert_success "$restore_status" "restore stage succeeds without history"
assert_json_field "$restore_output" ".status" "empty"
assert_json_field "$restore_output" ".session_restored" "false"
teardown_test_dir

it "creates distinct run identifiers for rapid successive verify runs"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-015 --title "Order Query" --owner alice --change-types rollout >/dev/null 2>&1
first_output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --feature-id FEAT-015 --json 2>&1)
first_status=$?
second_output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --feature-id FEAT-015 --json 2>&1)
second_status=$?
first_run_id=$(printf '%s' "$first_output" | jq -r '.artifacts.run_id')
second_run_id=$(printf '%s' "$second_output" | jq -r '.artifacts.run_id')
assert_success "$first_status" "first verify succeeds"
assert_success "$second_status" "second verify succeeds"
if [ -n "$first_run_id" ] && [ -n "$second_run_id" ] && [ "$first_run_id" != "$second_run_id" ]; then
  pass_test "rapid verify runs use unique run ids"
else
  fail_test "rapid verify runs reused the same run id"
  echo "    first:  $first_run_id"
  echo "    second: $second_run_id"
fi
teardown_test_dir

print_summary
