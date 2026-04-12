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
assert_file_not_exists "GEMINI.md"
assert_files_equal "CLAUDE.md" "AGENTS.md" "entry docs stay identical across tool-specific filenames"
assert_dir_exists "docs/project"
assert_dir_exists "docs/features"
assert_file_exists "docs/project/核心信念.md"
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
assert_file_contains "docs/project/项目架构.md" "## 模块清单与职责"
assert_file_contains "docs/project/项目架构.md" "## 分层与包结构"
assert_file_contains "docs/project/项目架构.md" "## 核心链路与时序"
assert_file_contains "docs/project/项目架构.md" "## 事务边界与一致性"
assert_file_contains "docs/project/项目设计.md" "## 工程设计结论"
assert_file_contains "docs/project/项目设计.md" "## 分层设计约定"
assert_file_contains "docs/project/项目设计.md" "## 当前代码挂点与职责分工"
assert_file_contains "docs/project/接口规范.md" "## 协议与接口类型"
assert_file_contains "docs/project/接口规范.md" "## 通用报文与上下文"
assert_file_contains "docs/project/接口规范.md" "## 典型示例与联调约定"
assert_file_contains "docs/project/开发规范.md" "## 技术栈开发约定"
assert_file_contains "docs/project/开发规范.md" "## 新增功能最小落地清单"
assert_file_contains "docs/project/开发规范.md" "## 分支与提交规范"
assert_file_contains "docs/project/需求说明.md" "## 功能需求清单"
assert_file_contains "docs/project/需求说明.md" "## 核心业务流程"
assert_file_contains "docs/project/测试策略.md" "# 项目测试策略"
assert_file_contains "docs/project/测试策略.md" "## 测试分层矩阵"
assert_file_contains "docs/project/测试策略.md" "## 关键链路测试设计"
assert_file_contains "docs/project/安全规范.md" "## 认证、授权与审计"
assert_file_contains "docs/project/安全规范.md" "## 敏感数据与日志脱敏"
assert_file_contains "docs/project/核心信念.md" "## 架构原则"
assert_file_contains "docs/project/核心信念.md" "## 质量标准"
assert_file_not_exists "docs/架构总览.md"
assert_file_not_exists "docs/开发约定.md"
assert_file_not_exists "docs/测试入口.md"
assert_file_not_exists "docs/安全说明.md"
assert_dir_not_exists "docs/design-docs"
assert_file_exists ".github/PULL_REQUEST_TEMPLATE.md"
assert_file_exists ".harness/architecture.json"
assert_file_exists ".harness/spec-policy.json"
assert_file_exists ".harness/doc-impact-rules.json"
assert_file_exists ".harness/context-policy.json"
assert_file_exists ".harness/run-policy.json"
assert_file_exists ".harness/observability-policy.json"
assert_file_exists ".harness/runtime/task-memory.json"
assert_file_exists ".harness/runtime/last-audit.json"
assert_file_exists ".harness/runtime/progress.md"
assert_dir_exists ".harness/evidence"
assert_dir_exists ".harness/metrics"
assert_dir_exists ".harness/exec-plans/active"
assert_dir_exists ".harness/exec-plans/completed"
assert_dir_exists ".harness/exec-plans/tech-debt"
assert_dir_exists ".harness/product-specs"
assert_dir_exists ".harness/references"
assert_dir_not_exists ".harness/skill-runtime"
assert_dir_not_exists ".husky"
assert_file_not_exists ".github/workflows/harness-guardrails.yml"
assert_file_not_exists ".git/hooks/pre-commit"
assert_file_contains "docs/project/项目架构.md" "template_version: 1.1.0"
assert_file_contains "docs/project/项目架构.md" "template_profile: generic"
assert_file_contains "docs/project/项目架构.md" "doc_state: scaffold"
assert_file_contains "AGENTS.md" "docs/project/核心信念.md"
assert_file_contains "AGENTS.md" "## 初始化后项目文档补全"
assert_file_contains "AGENTS.md" "pom.xml"
assert_file_contains "AGENTS.md" "ApplicationService"
assert_file_contains "AGENTS.md" "application.yml"
assert_file_contains "AGENTS.md" "scan-java-project.sh"
assert_file_contains "AGENTS.md" ".harness/runtime/java-doc-scan.json"
assert_file_contains "CLAUDE.md" "docs/project/核心信念.md"
assert_file_contains "CLAUDE.md" "## 启动检查（每次对话开始时执行）"
assert_file_contains "CLAUDE.md" ".harness/runtime/last-audit.json"
assert_file_contains "CLAUDE.md" "必须先确认 spec 和文档前置条件已经满足"
assert_file_contains "CLAUDE.md" "bash scripts/harness-exec.sh prepare"
assert_file_contains "CLAUDE.md" "## 自动 Audit 触发条件"
assert_file_contains "CLAUDE.md" "## 初始化后项目文档补全"
assert_file_contains "CLAUDE.md" "build.gradle"
assert_file_contains "CLAUDE.md" "Controller"
assert_file_contains "CLAUDE.md" "待确认 / 未覆盖范围"
assert_file_contains "CLAUDE.md" "scan-java-project.sh"
assert_file_contains "CLAUDE.md" ".harness/runtime/java-doc-scan.json"
assert_file_contains "CLAUDE.md" "doc_state: scaffold"
assert_file_contains "CLAUDE.md" "doc_state: hydrated"
assert_file_contains "docs/project/运行基线.md" "# 项目运行与变更基线"
assert_file_contains "docs/project/运行基线.md" "## 数据变更与批处理窗口"
assert_file_contains "docs/project/可观测性基线.md" "# 项目可观测性基线"
assert_file_contains "docs/project/可观测性基线.md" "## Trace、事件与排障链路"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.version" "1.1.0"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.profile" "generic"
assert_json_field "$(cat .harness/spec-policy.json)" ".quality_gate.strict_default" "false"
assert_json_field "$(cat .harness/spec-policy.json)" ".quality_gate.require_hydrated_doc_state" "true"
assert_json_field "$(cat .harness/spec-policy.json)" '.project_docs | map(select(.id == "core-beliefs")) | length' "1"
assert_json_field "$(cat .harness/doc-impact-rules.json)" ".rules[0].id" "java-api-surface"
assert_json_field "$(cat .harness/context-policy.json)" ".version" "1.0.0"
assert_json_field "$(cat .harness/context-policy.json)" '.always_include | index("AGENTS.md") != null' "true"
assert_json_field "$(cat .harness/context-policy.json)" '.always_include | index("CLAUDE.md") != null' "true"
assert_json_field "$(cat .harness/context-policy.json)" '.always_include | index("GEMINI.md") != null' "true"
assert_json_field "$(cat .harness/context-policy.json)" '.always_include | index("docs/project/核心信念.md") != null' "true"
assert_json_field "$(cat .harness/architecture.json)" '.layers[0]' "types"
assert_json_field "$(cat .harness/run-policy.json)" ".verify_steps[0]" "doc_impact"
assert_json_field "$(cat .harness/observability-policy.json)" ".version" "1.0.0"
assert_json_field "$(cat .harness/runtime/task-memory.json)" ".version" "1.0.0"
assert_json_field "$(cat .harness/runtime/last-audit.json)" ".status" "never_run"
assert_json_field "$output" '.entry_files | index("AGENTS.md") != null' "true"
assert_json_field "$output" '.entry_files | index("CLAUDE.md") != null' "true"
assert_json_field "$output" '.entry_files | index("GEMINI.md") == null' "true"
assert_json_field "$output" ".hydration_required_count" "10"
assert_json_field "$output" '.hydration_required_docs | index("docs/project/项目架构.md") != null' "true"
assert_json_field "$output" '.next_steps | index("After init, have the coding agent read key project files before filling docs/project/; do not rely on guesses") != null' "true"
assert_json_field "$output" '.next_steps | index("After hydrating a project doc from real code, update its frontmatter from doc_state: scaffold to doc_state: hydrated") != null' "true"
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
mkdir -p src/main/java/com/example/sample/interfaces/http
cat > src/main/java/com/example/sample/SampleApplication.java <<'EOF'
package com.example.sample;

public class SampleApplication {
  public static void main(String[] args) {}
}
EOF
cat > src/main/java/com/example/sample/interfaces/http/SampleController.java <<'EOF'
package com.example.sample.interfaces.http;

public class SampleController {}
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" 2>&1)
status=$?
assert_success "$status" "init command succeeds on maven project"
assert_json_field "$output" ".detected_stack" "java-maven"
assert_file_contains "AGENTS.md" "./mvnw clean test"
assert_file_contains "docs/project/开发规范.md" "./mvnw spotless:apply"
assert_file_contains "docs/project/项目架构.md" "启动类和根包建议位于业务代码最上层"
assert_file_contains "docs/project/项目架构.md" "template_profile: java-backend-service"
assert_file_contains "docs/project/项目架构.md" "doc_state: scaffold"
assert_file_exists ".harness/runtime/java-doc-scan.json"
assert_json_field "$(cat .harness/runtime/java-doc-scan.json)" '.inventory.entrypoints | map(.name) | index("SampleApplication") != null' "true"
assert_json_field "$(cat .harness/runtime/java-doc-scan.json)" '.inventory.controllers | map(.name) | index("SampleController") != null' "true"
assert_json_field "$(cat .harness/architecture.json)" '.layers[0]' "domain"
assert_json_field "$(cat .harness/architecture.json)" '.cross_domain_allowed_via' "anti-corruption-layer"
assert_json_field "$(cat .harness/architecture.json)" '.forbidden_dependencies | index("application -> infrastructure") != null' "true"
assert_json_field "$(cat .harness/spec-policy.json)" ".template_pack.profile" "java-backend-service"
assert_json_field "$(cat .harness/spec-policy.json)" ".quality_gate.strict_default" "true"
assert_json_field "$(cat .harness/spec-policy.json)" ".quality_gate.require_hydrated_doc_state" "true"
assert_json_field "$output" ".hydration_required_count" "10"
assert_json_field "$output" '.next_steps | index("Refresh the Java inventory with bash scripts/scan-java-project.sh --json before hydrating project docs after major code changes") != null' "true"
assert_json_field "$output" '.next_steps | index("For Java projects, prefer rerunning init with --with-strong-constraints so local commits and CI can block spec drift automatically") != null' "true"
assert_json_field "$output" '.next_steps | index("For Java profiles, validate-spec now defaults to strict doc-state enforcement; scaffold docs will fail validation until hydrated") != null' "true"
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
cat > custom-templates/CLAUDE.md.tpl <<'EOF'
# {{PROJECT_NAME}}

这是用户级自定义入口模板。
EOF
output=$(HARNESS_TEMPLATE_ROOT="$PWD/custom-templates" bash "$REPO_ROOT/scripts/init-harness.sh" --project-name sample-app 2>&1)
status=$?
assert_success "$status" "init command succeeds with user template root"
assert_file_contains "AGENTS.md" "这是用户级自定义入口模板。"
assert_file_contains "CLAUDE.md" "这是用户级自定义入口模板。"
assert_files_equal "CLAUDE.md" "AGENTS.md" "custom entry template is shared by AGENTS and CLAUDE"
teardown_test_dir

it "supports tool-scoped entry docs and additive re-init without losing existing content"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --tool codex 2>&1)
status=$?
assert_success "$status" "init command succeeds with codex-only entry doc"
assert_file_exists "AGENTS.md"
assert_file_not_exists "CLAUDE.md"
assert_file_not_exists "GEMINI.md"
assert_json_field "$output" '.entry_files | length' "1"
assert_json_field "$output" '.entry_files[0]' "AGENTS.md"
cat >> AGENTS.md <<'EOF'

## Custom Constraint

- Keep cross-tool entry docs aligned.
EOF
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --tool claude-code,gemini-cli 2>&1)
status=$?
assert_success "$status" "re-init adds missing tool entry docs"
assert_file_exists "CLAUDE.md"
assert_file_exists "GEMINI.md"
assert_file_contains "AGENTS.md" "Custom Constraint"
assert_file_contains "CLAUDE.md" "Custom Constraint"
assert_file_contains "GEMINI.md" "Custom Constraint"
assert_files_equal "AGENTS.md" "CLAUDE.md" "claude entry doc reuses the existing codex content"
assert_files_equal "AGENTS.md" "GEMINI.md" "gemini entry doc reuses the existing codex content"
assert_json_field "$output" '.created_files | index("CLAUDE.md") != null' "true"
assert_json_field "$output" '.created_files | index("GEMINI.md") != null' "true"
assert_json_field "$output" '.skipped_files | index("docs/project/核心信念.md") != null' "true"
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
assert_file_exists "CLAUDE.md"
assert_files_equal "AGENTS.md" "CLAUDE.md" "missing entry docs inherit the existing custom content"
assert_json_number_gte "$output" ".skipped_files | length" "1"
teardown_test_dir

it "can scaffold strong constraints with vendored runtime, git hook, and GitHub Actions"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --with-strong-constraints 2>&1)
status=$?
assert_success "$status" "init command succeeds with strong constraints"
assert_dir_exists ".harness/skill-runtime/harness-engineering"
assert_file_exists ".harness/skill-runtime/harness-engineering/scripts/check-runtime-deps.sh"
assert_file_exists ".harness/skill-runtime/harness-engineering/scripts/check-doc-impact.sh"
assert_file_exists ".harness/skill-runtime/harness-engineering/scripts/lint-architecture.sh"
assert_file_exists ".harness/skill-runtime/harness-engineering/schemas/plan-machine.schema.json"
assert_file_exists ".harness/skill-runtime/harness-engineering/assets/hooks/pre-commit-doc-guard.sh.tpl"
assert_file_exists ".harness/skill-runtime/harness-engineering/assets/ci-templates/github-actions.yml.tpl"
assert_file_exists ".git/hooks/pre-commit"
assert_file_exists ".github/workflows/harness-guardrails.yml"
assert_file_contains ".git/hooks/pre-commit" ".harness/skill-runtime/harness-engineering"
assert_file_contains ".git/hooks/pre-commit" 'validate-spec.sh" --json --strict'
assert_file_contains ".github/workflows/harness-guardrails.yml" "HARNESS_SKILL_ROOT: \".harness/skill-runtime/harness-engineering\""
assert_file_contains ".github/workflows/harness-guardrails.yml" 'bash "$HARNESS_SKILL_ROOT/scripts/lint-architecture.sh"'
assert_json_field "$output" '.enabled_guardrails | index("git-hook") != null' "true"
assert_json_field "$output" '.enabled_guardrails | index("github-actions") != null' "true"
assert_json_field "$output" '.enabled_guardrails | index("strict-spec-checks") != null' "true"
teardown_test_dir

it "can scaffold husky-based constraints and set hooksPath"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --with-husky 2>&1)
status=$?
assert_success "$status" "init command succeeds with husky"
assert_dir_exists ".harness/skill-runtime/harness-engineering"
assert_file_exists ".harness/skill-runtime/harness-engineering/scripts/check-doc-impact.sh"
assert_file_exists ".husky/pre-commit"
assert_file_contains ".husky/pre-commit" ".harness/skill-runtime/harness-engineering"
assert_eq ".husky" "$(git config --get core.hooksPath)" "git hooksPath points to .husky"
assert_json_field "$output" '.enabled_guardrails | index("husky") != null' "true"
teardown_test_dir

it "auto-enables strict spec checks for java hooks"
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
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --with-git-hook 2>&1)
status=$?
assert_success "$status" "init command succeeds with java git hook"
assert_file_exists ".git/hooks/pre-commit"
assert_file_contains ".git/hooks/pre-commit" 'validate-spec.sh" --json --strict'
assert_json_field "$output" '.enabled_guardrails | index("git-hook") != null' "true"
assert_json_field "$output" '.enabled_guardrails | index("strict-spec-checks") != null' "true"
teardown_test_dir

it "can enable strict spec checks for husky-based constraints"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/init-harness.sh" --with-husky --with-strict-spec-checks 2>&1)
status=$?
assert_success "$status" "init command succeeds with husky strict spec checks"
assert_file_exists ".husky/pre-commit"
assert_file_contains ".husky/pre-commit" 'validate-spec.sh" --json --strict'
assert_json_field "$output" '.enabled_guardrails | index("husky") != null' "true"
assert_json_field "$output" '.enabled_guardrails | index("strict-spec-checks") != null' "true"
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
