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

it "resolves legacy project doc filenames from always_include policy entries"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mv "harness/docs/project/核心信念.md" "harness/docs/project/core-beliefs.md"
mv "harness/docs/project/项目架构.md" "harness/docs/project/ARCHITECTURE.md"
output=$(bash "$REPO_ROOT/scripts/resolve-task-context.sh" --task "Legacy Docs" --json 2>&1)
status=$?
assert_success "$status" "context resolution succeeds with legacy project docs"
assert_json_field "$output" '.required_context | index("harness/docs/project/core-beliefs.md") != null' "true"
assert_json_field "$output" '.required_context | index("harness/docs/project/ARCHITECTURE.md") != null' "true"
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

it "prepare stage succeeds without explicit change types"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" prepare --task "Inventory Sync" --feature-id FEAT-016 --title "Inventory Sync" --owner alice --json 2>&1)
status=$?
assert_success "$status" "prepare stage succeeds without change types"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".context.status" "success"
assert_json_field "$output" '.context.change_types | length' "0"
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

it "prepare stage skips context bundles when run policy disables them"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
cat > harness/.harness/run-policy.json <<'EOF'
{
  "version": "1.0.0",
  "record_context_bundles": false,
  "record_run_results": false,
  "record_metrics_ledger": false,
  "record_task_memory": false,
  "record_progress_report": false,
  "record_evidence": false
}
EOF
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" prepare --task "No Bundle" --json 2>&1)
status=$?
assert_success "$status" "prepare stage succeeds when context bundles are disabled"
assert_file_not_exists "harness/.harness/runtime/context/no-bundle.json"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" '.context | has("bundle_path")' "false"
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

it "verify stage respects run policy step selection and fail-fast"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p src/order/types src/order/service
cat > src/order/types/order-dto.ts <<'EOF'
import { orderService } from "../service/order-service";
EOF
cat > src/order/service/order-service.ts <<'EOF'
export const orderService = {};
EOF
cat > harness/.harness/run-policy.json <<'EOF'
{
  "version": "1.0.0",
  "verify_steps": ["architecture_lint", "doc_freshness"],
  "verify_fail_fast": true,
  "verify_timeout_seconds": 0
}
EOF
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --json 2>&1)
status=$?
assert_eq "1" "$status" "verify exits non-zero when fail-fast encounters an error"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".checks.architecture_lint.status" "violations"
assert_json_field "$output" ".checks.doc_freshness.status" "skipped"
assert_json_field "$output" ".checks.doc_freshness.reason" "fail_fast"
assert_json_field "$output" ".checks.spec_validation.status" "skipped"
assert_json_field "$output" ".checks.spec_validation.reason" "disabled_by_policy"
teardown_test_dir

it "verify stage marks timed out checks according to run policy"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p fake-bin
real_find="$(command -v find)"
cat > fake-bin/find <<EOF
#!/bin/bash
sleep 2
exec "$real_find" "\$@"
EOF
chmod +x fake-bin/find
cat > harness/.harness/run-policy.json <<'EOF'
{
  "version": "1.0.0",
  "verify_steps": ["doc_freshness"],
  "verify_fail_fast": false,
  "verify_timeout_seconds": 1
}
EOF
output=$(PATH="$PWD/fake-bin:$PATH" bash "$REPO_ROOT/scripts/harness-exec.sh" verify --json 2>&1)
status=$?
assert_eq "1" "$status" "verify exits non-zero when a check times out"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".checks.doc_freshness.status" "timeout"
assert_json_field "$output" ".checks.doc_freshness.timed_out" "true"
assert_json_field "$output" ".checks.doc_freshness.timeout_seconds" "1"
teardown_test_dir

it "verify stage fails when run policy contains an unknown step"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
cat > harness/.harness/run-policy.json <<'EOF'
{
  "version": "1.0.0",
  "verify_steps": ["spec_validaton"],
  "verify_fail_fast": true,
  "verify_timeout_seconds": 0
}
EOF
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --json 2>&1)
status=$?
assert_eq "1" "$status" "verify exits non-zero when run policy contains an unknown step"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".policy.verify_steps[0]" "spec_validaton"
assert_json_field "$output" ".checks.spec_validation.status" "skipped"
teardown_test_dir

it "run stage skips autofix when run policy disables it"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
cat > harness/.harness/run-policy.json <<'EOF'
{
  "version": "1.0.0",
  "verify_steps": ["spec_validation"],
  "autofix_on_verify_failure": false,
  "record_run_results": false,
  "record_metrics_ledger": false,
  "record_task_memory": false,
  "record_progress_report": false,
  "record_evidence": false
}
EOF
rm harness/docs/project/项目架构.md
output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" run --task "Broken Spec" --json 2>&1)
status=$?
assert_eq "1" "$status" "run exits non-zero when autofix is disabled"
assert_file_not_exists "harness/docs/project/项目架构.md"
assert_json_field "$output" ".status" "invalid"
assert_json_field "$output" ".verify.status" "invalid"
assert_json_field "$output" ".autofix.status" "skipped"
assert_json_field "$output" ".autofix.reason" "disabled_by_policy"
assert_json_field "$output" ".verify_after_autofix.status" "skipped"
assert_json_field "$output" ".verify_after_autofix.reason" "autofix_disabled"
teardown_test_dir

print_summary
