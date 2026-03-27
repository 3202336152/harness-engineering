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

print_summary
