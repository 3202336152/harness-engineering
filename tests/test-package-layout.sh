#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "package layout"

it "ignores generated runtime-only package artifacts"
assert_file_contains "$REPO_ROOT/.gitignore" ".build/"

it "does not keep .DS_Store files in the repository"
ds_store_files=$(find "$REPO_ROOT" -name '.DS_Store' | sort)
assert_eq "" "$ds_store_files" "repository has no .DS_Store files"

it "includes the deep reference documents for the full skill flow"
assert_file_exists "$REPO_ROOT/references/ARCHITECTURE-PATTERNS.md"
assert_file_exists "$REPO_ROOT/references/AGENTS-MD-GUIDE.md"
assert_file_exists "$REPO_ROOT/references/CONTEXT-ENGINEERING.md"
assert_file_exists "$REPO_ROOT/references/TASK-SPEC-FORMAT.md"
assert_file_exists "$REPO_ROOT/references/PR-WORKFLOW.md"
assert_file_exists "$REPO_ROOT/references/OBSERVABILITY.md"
assert_file_exists "$REPO_ROOT/references/ENTROPY-MANAGEMENT.md"
assert_file_exists "$REPO_ROOT/references/METRICS.md"
assert_file_exists "$REPO_ROOT/references/SECURITY.md"

it "includes CI template assets for downstream projects"
assert_file_exists "$REPO_ROOT/assets/ci-templates/github-actions.yml.tpl"
assert_file_exists "$REPO_ROOT/assets/ci-templates/gitlab-ci.yml.tpl"
assert_file_exists "$REPO_ROOT/assets/hooks/pre-commit-doc-guard.sh.tpl"

it "includes a manual publish-check workflow for official validation"
assert_file_exists "$REPO_ROOT/.github/workflows/publish-check.yml"
assert_file_contains "$REPO_ROOT/.github/workflows/publish-check.yml" "workflow_dispatch:"
assert_file_contains "$REPO_ROOT/.github/workflows/publish-check.yml" "bash scripts/publish-check.sh"

it "includes spec workflow scripts and templates"
assert_file_exists "$REPO_ROOT/scripts/new-feature-spec.sh"
assert_file_exists "$REPO_ROOT/scripts/validate-spec.sh"
assert_file_exists "$REPO_ROOT/scripts/prepare-template-overrides.sh"
assert_file_exists "$REPO_ROOT/scripts/check-template-drift.sh"
assert_file_exists "$REPO_ROOT/scripts/check-doc-impact.sh"
assert_file_exists "$REPO_ROOT/scripts/resolve-task-context.sh"
assert_file_exists "$REPO_ROOT/scripts/harness-exec.sh"
assert_file_exists "$REPO_ROOT/scripts/install-skill.sh"
assert_file_exists "$REPO_ROOT/scripts/scan-java-project.sh"
assert_file_exists "$REPO_ROOT/scripts/check-rollback-readiness.sh"
assert_file_exists "$REPO_ROOT/scripts/migrate-template-docs.sh"
assert_file_exists "$REPO_ROOT/scripts/collect-runtime-evidence.sh"
assert_file_exists "$REPO_ROOT/scripts/harness-gc.sh"
assert_file_exists "$REPO_ROOT/scripts/check-runtime-deps.sh"
assert_file_exists "$REPO_ROOT/schemas/plan-machine.schema.json"
assert_file_exists "$REPO_ROOT/assets/templates/project/ARCHITECTURE.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/project/REQUIREMENTS.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/project/OPERATIONS.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/project/OBSERVABILITY.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/doc-impact-rules.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/context-policy.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/run-policy.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/observability-policy.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/task-memory.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/last-audit.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/progress.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/feature/overview.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/feature/test-spec.md.tpl"

it "uses Chinese names for maintainer docs under doc"
assert_file_exists "$REPO_ROOT/doc/文档导航.md"
assert_file_exists "$REPO_ROOT/doc/本地使用指南.md"
assert_file_exists "$REPO_ROOT/doc/手册/Harness工程手册.md"
assert_file_exists "$REPO_ROOT/doc/历史设计/00-索引.md"
assert_file_exists "$REPO_ROOT/doc/归档/Skill实施设计文档.md"

it "can self-check runtime dependencies on the current machine"
output=$(bash "$REPO_ROOT/scripts/check-runtime-deps.sh" --json 2>&1)
status=$?
assert_success "$status" "runtime dependency check succeeds"
assert_json_field "$output" ".status" "ok"
assert_json_field "$output" '.missing_commands | length' "0"

it "exports a runtime-only install bundle for global installation"
setup_test_dir
output=$(bash "$REPO_ROOT/scripts/export-skill-package.sh" --output-dir "$TEST_TMP/dist" 2>&1)
status=$?
assert_success "$status" "export bundle command succeeds"
assert_file_exists "$TEST_TMP/dist/harness-engineering/SKILL.md"
assert_file_exists "$TEST_TMP/dist/harness-engineering/scripts/init-harness.sh"
assert_file_exists "$TEST_TMP/dist/harness-engineering/scripts/check-runtime-deps.sh"
assert_file_exists "$TEST_TMP/dist/harness-engineering/scripts/lib/template-resolver.sh"
assert_file_exists "$TEST_TMP/dist/harness-engineering/scripts/scan-java-project.sh"
assert_file_exists "$TEST_TMP/dist/harness-engineering/schemas/plan-machine.schema.json"
assert_file_exists "$TEST_TMP/dist/harness-engineering/assets/templates/project/ARCHITECTURE.md.tpl"
assert_file_exists "$TEST_TMP/dist/harness-engineering/assets/templates/last-audit.json.tpl"
assert_file_exists "$TEST_TMP/dist/harness-engineering/assets/hooks/pre-commit-doc-guard.sh.tpl"
assert_file_exists "$TEST_TMP/dist/harness-engineering/assets/ci-templates/github-actions.yml.tpl"
assert_file_exists "$TEST_TMP/dist/harness-engineering/references/ARCHITECTURE-PATTERNS.md"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/README.md"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/CHANGELOG.md"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/tests/test-init.sh"
assert_dir_not_exists "$TEST_TMP/dist/harness-engineering/doc"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/doc/历史设计/00-索引.md"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/doc/归档/Skill实施设计文档.md"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/scripts/export-skill-package.sh"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/scripts/install-skill.sh"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/scripts/publish-check.sh"
assert_file_not_exists "$TEST_TMP/dist/harness-engineering/scripts/verify-spec-compliance.sh"
assert_json_field "$output" ".status" "success"
assert_json_field "$output" ".package_dir" "$TEST_TMP/dist/harness-engineering"
teardown_test_dir

print_summary
