#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "runtime governance"

it "migrates drifted docs and writes backups for historical template upgrades"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-030 --title "Order Query" --owner alice --change-types api >/dev/null 2>&1

cat > harness/docs/project/项目架构.md <<'EOF'
---
id: project-architecture
title: 项目架构
type: project-architecture
status: active
owner: team
last_updated: 2026-04-07
template_version: 1.0.0
template_profile: generic
template_language: zh-CN
---

# 项目架构

## 系统上下文

订单服务负责订单创建与状态流转。

## 分层与包结构

controller / application / domain / infrastructure 四层分离。
EOF

output=$(bash "$REPO_ROOT/scripts/migrate-template-docs.sh" --json 2>&1)
status=$?
assert_success "$status" "template migration succeeds"
migration_dir=$(printf '%s' "$output" | jq -r '.migration_dir')
assert_dir_exists "$migration_dir"
assert_file_exists "$migration_dir/report.json"
assert_file_exists "$migration_dir/backup/harness/docs/project/项目架构.md"
assert_file_contains "harness/docs/project/项目架构.md" "template_version: 1.1.0"
assert_file_contains "harness/docs/project/项目架构.md" "## 事务边界与一致性"
assert_json_field "$output" ".status" "success"
assert_json_number_gte "$output" ".migrated_doc_count" "1"
teardown_test_dir

it "records run ledger, metrics ledger, task memory, and evidence during verify"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
bash "$REPO_ROOT/scripts/new-feature-spec.sh" --id FEAT-031 --title "Order Query" --owner alice --change-types rollout >/dev/null 2>&1

cat > harness/.harness/observability-policy.json <<'EOF'
{
  "version": "1.0.0",
  "always_capture_commands": [
    {"id": "git-status", "argv": ["git", "status", "--short"]}
  ],
  "runtime_capture_commands": [
    {"id": "app-health", "enabled": true, "argv": ["printf", "health=ok\nlatency_ms=42\n"]}
  ],
  "file_artifacts": []
}
EOF

output=$(bash "$REPO_ROOT/scripts/harness-exec.sh" verify --feature-id FEAT-031 --json 2>&1)
status=$?
assert_success "$status" "verify with evidence succeeds"
run_record=$(printf '%s' "$output" | jq -r '.artifacts.run_record_path')
evidence_dir=$(printf '%s' "$output" | jq -r '.artifacts.evidence_dir')
assert_file_exists "harness/.harness/runs/ledger.jsonl"
assert_file_exists "harness/.harness/metrics/ledger.jsonl"
assert_file_exists "harness/.harness/runtime/task-memory.json"
assert_file_exists "harness/.harness/runtime/progress.md"
assert_file_exists "$run_record"
assert_dir_exists "$evidence_dir"
assert_file_exists "$evidence_dir/manifest.json"
assert_file_exists "$evidence_dir/commands/app-health.txt"
assert_file_contains "$evidence_dir/commands/app-health.txt" "health=ok"
assert_file_contains "harness/.harness/runtime/progress.md" "FEAT-031"
assert_json_field "$(cat harness/.harness/runtime/task-memory.json)" '.tasks[0].feature_id' "FEAT-031"
assert_json_field "$output" ".status" "passed"
assert_json_field "$output" ".artifacts.evidence.status" "success"
teardown_test_dir

it "rejects unsafe shell-style evidence commands while keeping safe argv captures"
setup_test_dir
init_git_repo
mkdir -p harness/.harness
cat > harness/.harness/observability-policy.json <<'EOF'
{
  "version": "1.0.0",
  "always_capture_commands": [
    {"id": "git status$(bad)", "argv": ["git", "status", "--short"]}
  ],
  "runtime_capture_commands": [
    {"id": "app-health", "enabled": true, "argv": ["printf", "health=ok\n"]},
    {"id": "dangerous;rm", "enabled": true, "command": "git status; rm -rf ."}
  ],
  "file_artifacts": []
}
EOF
output=$(bash "$REPO_ROOT/scripts/collect-runtime-evidence.sh" --run-id verify-test --json 2>&1)
status=$?
assert_success "$status" "evidence collection succeeds with partial unsafe policy"
assert_json_field "$output" ".status" "partial"
assert_json_field "$output" '.commands[0].path | contains("git-status-bad.txt")' "true"
assert_json_field "$output" '.commands[1].status' "success"
assert_json_field "$output" '.commands[2].status' "rejected"
assert_file_exists "harness/.harness/evidence/verify-test/commands/git-status-bad.txt"
assert_file_exists "harness/.harness/evidence/verify-test/commands/app-health.txt"
assert_file_exists "harness/.harness/evidence/verify-test/commands/dangerous-rm.txt"
assert_file_contains "harness/.harness/evidence/verify-test/commands/dangerous-rm.txt" "Rejected unsafe capture command"
teardown_test_dir

it "prunes stale runtime artifacts while keeping the newest records"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p harness/.harness/evidence/old-run harness/.harness/evidence/new-run
printf '{}' > harness/.harness/runtime/context/old.json
printf '{}' > harness/.harness/runtime/context/new.json
printf '{}' > harness/.harness/runs/20240101-old.json
printf '{}' > harness/.harness/runs/20240102-new.json
printf '{}' > harness/.harness/evidence/old-run/manifest.json
printf '{}' > harness/.harness/evidence/new-run/manifest.json
touch -t 202401010101 harness/.harness/runtime/context/old.json harness/.harness/runs/20240101-old.json harness/.harness/evidence/old-run
touch -t 202401020202 harness/.harness/runtime/context/new.json harness/.harness/runs/20240102-new.json harness/.harness/evidence/new-run
output=$(bash "$REPO_ROOT/scripts/harness-gc.sh" --json --keep-context 1 --keep-runs 1 --keep-evidence 1 2>&1)
status=$?
assert_success "$status" "runtime gc succeeds"
assert_file_not_exists "harness/.harness/runtime/context/old.json"
assert_file_exists "harness/.harness/runtime/context/new.json"
assert_file_not_exists "harness/.harness/runs/20240101-old.json"
assert_file_exists "harness/.harness/runs/20240102-new.json"
assert_dir_not_exists "harness/.harness/evidence/old-run"
assert_dir_exists "harness/.harness/evidence/new-run"
assert_json_field "$output" ".status" "success"
assert_json_number_gte "$output" ".pruned.context_bundles" "1"
assert_json_number_gte "$output" ".pruned.run_records" "1"
assert_json_number_gte "$output" ".pruned.evidence_dirs" "1"
teardown_test_dir

it "keeps newest runtime artifacts when stat is unavailable and date -r is used"
setup_test_dir
init_git_repo
bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app >/dev/null 2>&1
mkdir -p harness/.harness/evidence/z-old-run harness/.harness/evidence/a-new-run fake-bin
printf '{}' > harness/.harness/runtime/context/z-old.json
printf '{}' > harness/.harness/runtime/context/a-new.json
printf '{}' > harness/.harness/runs/z-old.json
printf '{}' > harness/.harness/runs/a-new.json
printf '{}' > harness/.harness/evidence/z-old-run/manifest.json
printf '{}' > harness/.harness/evidence/a-new-run/manifest.json
touch -t 202401010101 harness/.harness/runtime/context/z-old.json harness/.harness/runs/z-old.json harness/.harness/evidence/z-old-run
touch -t 202401020202 harness/.harness/runtime/context/a-new.json harness/.harness/runs/a-new.json harness/.harness/evidence/a-new-run
cat > fake-bin/stat <<'EOF'
#!/bin/bash
exit 1
EOF
cat > fake-bin/date <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-r" ]; then
  /bin/date "$@"
else
  printf '1710000000\n'
fi
EOF
chmod +x fake-bin/stat fake-bin/date
output=$(PATH="$PWD/fake-bin:$PATH" bash "$REPO_ROOT/scripts/harness-gc.sh" --json --keep-context 1 --keep-runs 1 --keep-evidence 1 2>&1)
status=$?
assert_success "$status" "runtime gc succeeds when stat is unavailable"
assert_file_not_exists "harness/.harness/runtime/context/z-old.json"
assert_file_exists "harness/.harness/runtime/context/a-new.json"
assert_file_not_exists "harness/.harness/runs/z-old.json"
assert_file_exists "harness/.harness/runs/a-new.json"
assert_dir_not_exists "harness/.harness/evidence/z-old-run"
assert_dir_exists "harness/.harness/evidence/a-new-run"
teardown_test_dir

print_summary
