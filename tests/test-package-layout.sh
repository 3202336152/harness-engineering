#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

describe "package layout"

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

it "includes spec workflow scripts and templates"
assert_file_exists "$REPO_ROOT/scripts/new-feature-spec.sh"
assert_file_exists "$REPO_ROOT/scripts/validate-spec.sh"
assert_file_exists "$REPO_ROOT/scripts/prepare-template-overrides.sh"
assert_file_exists "$REPO_ROOT/scripts/check-template-drift.sh"
assert_file_exists "$REPO_ROOT/scripts/check-doc-impact.sh"
assert_file_exists "$REPO_ROOT/assets/templates/project/ARCHITECTURE.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/project/REQUIREMENTS.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/doc-impact-rules.json.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/feature/overview.md.tpl"
assert_file_exists "$REPO_ROOT/assets/templates/feature/test-spec.md.tpl"

it "uses Chinese names for maintainer docs under doc"
assert_file_exists "$REPO_ROOT/doc/文档导航.md"
assert_file_exists "$REPO_ROOT/doc/本地使用指南.md"
assert_file_exists "$REPO_ROOT/doc/手册/Harness工程手册.md"
assert_file_exists "$REPO_ROOT/doc/历史设计/00-索引.md"
assert_file_exists "$REPO_ROOT/doc/归档/Skill实施设计文档.md"

print_summary
