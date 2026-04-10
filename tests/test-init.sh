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
assert_file_exists "docs/架构总览.md"
assert_file_exists "docs/开发约定.md"
assert_file_exists "docs/测试入口.md"
assert_file_exists "docs/安全说明.md"
assert_dir_exists "docs/project"
assert_dir_exists "docs/features"
assert_file_exists "docs/project/项目架构.md"
assert_file_exists "docs/project/项目设计.md"
assert_file_exists "docs/project/接口规范.md"
assert_file_exists "docs/project/开发规范.md"
assert_file_exists "docs/project/需求说明.md"
assert_file_exists "docs/project/测试策略.md"
assert_file_exists "docs/project/安全规范.md"
assert_file_exists "docs/project/运行基线.md"
assert_file_exists "docs/project/可观测性基线.md"
assert_file_contains "docs/project/项目架构.md" "# 项目架构"
assert_file_contains "docs/project/项目架构.md" "## 分层与包结构"
assert_file_contains "docs/project/项目架构.md" "## 事务边界与一致性"
assert_file_contains "docs/project/项目设计.md" "## Java 分层设计约定"
assert_file_contains "docs/project/接口规范.md" "## 协议与接口类型"
assert_file_contains "docs/project/开发规范.md" "## Java 开发约定"
assert_file_contains "docs/project/需求说明.md" "## 功能需求清单"
assert_file_contains "docs/project/测试策略.md" "# 项目测试策略"
assert_file_contains "docs/project/测试策略.md" "## 测试分层矩阵"
assert_file_contains "docs/project/安全规范.md" "## 认证、授权与审计"
assert_file_exists "docs/design-docs/核心信念.md"
assert_file_exists ".github/PULL_REQUEST_TEMPLATE.md"
assert_file_exists ".harness/architecture.json"
assert_file_exists ".harness/spec-policy.json"
assert_file_exists ".harness/doc-impact-rules.json"
assert_file_exists ".harness/context-policy.json"
assert_file_exists ".harness/run-policy.json"
assert_file_exists ".harness/observability-policy.json"
assert_file_exists ".harness/runtime/task-memory.json"
assert_file_exists ".harness/runtime/progress.md"
assert_dir_exists ".harness/evidence"
assert_dir_exists ".harness/metrics"
assert_dir_exists "docs/exec-plans/active"
assert_file_contains "docs/project/项目架构.md" "template_version: 1.1.0"
assert_file_contains "docs/project/项目架构.md" "template_profile: generic"
assert_file_contains "docs/project/运行基线.md" "# 项目运行与变更基线"
assert_file_contains "docs/project/可观测性基线.md" "# 项目可观测性基线"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.version" "1.1.0"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.profile" "generic"
assert_json_field "$(cat .harness/doc-impact-rules.json)" ".rules[0].id" "java-api-surface"
assert_json_field "$(cat .harness/context-policy.json)" ".version" "1.0.0"
assert_json_field "$(cat .harness/run-policy.json)" ".verify_steps[0]" "doc_impact"
assert_json_field "$(cat .harness/observability-policy.json)" ".version" "1.0.0"
assert_json_field "$(cat .harness/runtime/task-memory.json)" ".version" "1.0.0"
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
assert_file_contains "docs/测试入口.md" "npm test"
assert_file_contains "docs/project/测试策略.md" "npm test"
teardown_test_dir

it "detects a maven java project and fills mvn commands"
setup_test_dir
init_git_repo
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>sample-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" 2>&1)
status=$?
assert_success "$status" "init command succeeds on maven project"
assert_json_field "$output" ".detected_stack" "java-maven"
assert_file_contains "AGENTS.md" "./mvnw clean test"
assert_file_contains "docs/测试入口.md" "./mvnw clean test"
assert_file_contains "docs/project/开发规范.md" "./mvnw spotless:apply"
assert_file_contains "docs/project/项目架构.md" "template_profile: java-backend-service"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.profile" "java-backend-service"
teardown_test_dir

it "supports overriding the generated template profile"
setup_test_dir
init_git_repo
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>sample-app</artifactId>
  <version>1.0.0</version>
</project>
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --profile java-batch-job 2>&1)
status=$?
assert_success "$status" "init command succeeds with explicit profile"
assert_file_contains "docs/project/项目架构.md" "template_profile: java-batch-job"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.profile" "java-batch-job"
teardown_test_dir

it "uses user-level template overrides when HARNESS_TEMPLATE_ROOT is set"
setup_test_dir
init_git_repo
mkdir -p custom-templates/project
cat > custom-templates/AGENTS.md.tpl <<'EOF'
# {{PROJECT_NAME}}

这是用户级自定义入口模板。
EOF
output=$(HARNESS_TEMPLATE_ROOT="$PWD/custom-templates" bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app 2>&1)
status=$?
assert_success "$status" "init command succeeds with user template root"
assert_file_contains "AGENTS.md" "这是用户级自定义入口模板。"
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
