#!/bin/bash

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck source=tests/test-helpers.sh
. "$REPO_ROOT/tests/test-helpers.sh"

seed_full_harness_project() {
  mkdir -p docs/design-docs docs/exec-plans/active docs/exec-plans/completed .github/workflows scripts tests
  cat > AGENTS.md <<'EOF'
# Sample Project

## Quick Commands

```bash
npm install
npm test
```

## Architecture

Layered service architecture.

## Constraints

Keep docs updated.
EOF
  cp AGENTS.md CLAUDE.md
  cat > docs/ARCHITECTURE.md <<'EOF'
# Architecture

Layered model with dependency boundaries.

Dependencies flow one way.

Boundary checks are enforced in CI.
EOF
  cat > docs/CONVENTIONS.md <<'EOF'
# Conventions

Follow shared utilities first.

Files use kebab-case.
EOF
  cat > docs/TESTING.md <<'EOF'
# Testing

Use npm test for verification.

Coverage is tracked in CI.
EOF
  cat > docs/SECURITY.md <<'EOF'
# Security

Secrets stay in environment variables.

.env files are ignored.
EOF
  cat > docs/design-docs/core-beliefs.md <<'EOF'
# Core Beliefs

Architecture choices require team review.
EOF
  cat > docs/exec-plans/active/sample-plan.md <<'EOF'
# Execution Plan

Active plan placeholder.
EOF
  cat > scripts/lint-architecture.sh <<'EOF'
#!/bin/bash
echo "ok"
EOF
  chmod +x scripts/lint-architecture.sh
  cat > .github/PULL_REQUEST_TEMPLATE.md <<'EOF'
## What
EOF
  cat > .github/workflows/ci.yml <<'EOF'
name: CI
jobs:
  validate:
    steps:
      - run: bash scripts/lint-architecture.sh
      - run: npm test
EOF
  cat > .gitignore <<'EOF'
.env
credentials.json
*.key
EOF
  mkdir -p .husky
  cat > .husky/pre-commit <<'EOF'
#!/bin/bash
npm test
EOF
  chmod +x .husky/pre-commit
  cat > package.json <<'EOF'
{"name":"sample-project","scripts":{"test":"echo ok","coverage":"echo coverage"}}
EOF
  touch tests/index.test.ts
}

seed_project_level_spec_project() {
  mkdir -p docs/project docs/features/FEAT-010-checkout-rewrite .github/workflows scripts tests .harness
  cat > AGENTS.md <<'EOF'
# Sample Project

## Quick Commands

```bash
npm test
```

## Architecture

See docs/project/ARCHITECTURE.md.

## Constraints

Keep specs and docs updated.
EOF
  cat > docs/project/ARCHITECTURE.md <<'EOF'
---
id: project-architecture
title: Project Architecture
type: project-architecture
status: active
owner: team
last_updated: 2026-04-07
---

# Project Architecture

Boundary rules and layered model live here.
EOF
  cat > docs/project/DEVELOPMENT.md <<'EOF'
---
id: project-development
title: Project Development
type: project-development
status: active
owner: team
last_updated: 2026-04-07
---

# Project Development

Conventions and review expectations live here.
EOF
  cat > docs/project/TESTING.md <<'EOF'
---
id: project-testing
title: Project Testing
type: project-testing
status: active
owner: team
last_updated: 2026-04-07
---

# Project Testing

Use npm test and keep verification in CI.
EOF
  cat > docs/project/SECURITY.md <<'EOF'
---
id: project-security
title: Project Security
type: project-security
status: active
owner: team
last_updated: 2026-04-07
---

# Project Security

Security guidance lives here.
EOF
  cat > .harness/spec-policy.json <<'EOF'
{
  "project_docs": [
    { "id": "architecture", "path": "docs/project/ARCHITECTURE.md", "required": true },
    { "id": "development", "path": "docs/project/DEVELOPMENT.md", "required": true },
    { "id": "testing", "path": "docs/project/TESTING.md", "required": true },
    { "id": "security", "path": "docs/project/SECURITY.md", "required": true }
  ],
  "feature_spec": {
    "base_dir": "docs/features",
    "required_docs": ["overview.md", "design.md", "test-spec.md", "status.md"],
    "change_type_docs": {
      "api": ["api-spec.md"]
    }
  }
}
EOF
  cat > docs/features/FEAT-010-checkout-rewrite/overview.md <<'EOF'
---
id: FEAT-010
title: Checkout Rewrite
type: feature-overview
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
---

# Feature Overview
EOF
  cat > docs/features/FEAT-010-checkout-rewrite/design.md <<'EOF'
---
id: FEAT-010
title: Checkout Rewrite
type: feature-design
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
---

# Feature Design
EOF
  cat > docs/features/FEAT-010-checkout-rewrite/test-spec.md <<'EOF'
---
id: FEAT-010
title: Checkout Rewrite
type: feature-test-spec
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
---

# Feature Test Spec
EOF
  cat > docs/features/FEAT-010-checkout-rewrite/status.md <<'EOF'
---
id: FEAT-010
title: Checkout Rewrite
type: feature-status
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
---

# Feature Status
EOF
  cat > docs/features/FEAT-010-checkout-rewrite/api-spec.md <<'EOF'
---
id: FEAT-010
title: Checkout Rewrite
type: feature-api-spec
status: draft
owner: alice
change_types: "api"
last_updated: 2026-04-07
---

# Feature API Spec
EOF
  cat > scripts/lint-architecture.sh <<'EOF'
#!/bin/bash
echo "ok"
EOF
  chmod +x scripts/lint-architecture.sh
  cat > .github/workflows/ci.yml <<'EOF'
name: CI
jobs:
  validate:
    steps:
      - run: bash scripts/lint-architecture.sh
      - run: bash scripts/validate-spec.sh --json
EOF
  cat > package.json <<'EOF'
{"name":"sample-project","scripts":{"test":"echo ok"}}
EOF
  touch tests/index.test.ts
}

describe "audit-harness.sh"

it "reports level 0 for an empty project"
setup_test_dir
init_git_repo
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds"
assert_json_field "$output" ".status" "completed"
assert_json_field "$output" ".overall_score" "0"
assert_json_field "$output" ".maturity_level" "0"
assert_json_field "$output" ".maturity_label" "No Harness"
teardown_test_dir

it "treats GEMINI.md as a valid entry document"
setup_test_dir
init_git_repo
cat > GEMINI.md <<'EOF'
# Sample Project

## Quick Commands

- npm test

## Architecture

Layered service architecture.

## Constraints

Keep docs updated.
EOF
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds with GEMINI entry doc"
assert_json_field "$output" ".dimensions.entry_document.score" "100"
assert_json_field "$output" ".dimensions.entry_document.line_count" "13"
teardown_test_dir

it "reports a high score for a well-prepared harness project"
setup_test_dir
init_git_repo
seed_full_harness_project
git add -A >/dev/null 2>&1
git commit -m "seed harness project" --quiet >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds on full project"
assert_json_number_gte "$output" ".overall_score" "80"
assert_json_number_gte "$output" ".maturity_level" "3"
assert_json_field "$output" ".dimensions.entry_document.score" "100"
teardown_test_dir

it "recognizes the v2 project-level spec structure"
setup_test_dir
init_git_repo
seed_project_level_spec_project
git add -A >/dev/null 2>&1
git commit -m "seed project spec structure" --quiet >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds on project-level spec structure"
assert_json_number_gte "$output" ".dimensions.doc_structure.score" "75"
assert_json_number_gte "$output" ".dimensions.architecture_constraints.score" "60"
teardown_test_dir

it "writes a reusable audit snapshot for initialized harness projects"
setup_test_dir
init_git_repo
seed_project_level_spec_project
git add -A >/dev/null 2>&1
git commit -m "seed project spec structure" --quiet >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds and writes snapshot"
assert_file_exists ".harness/runtime/last-audit.json"
assert_json_field "$output" ".snapshot_path" ".harness/runtime/last-audit.json"
assert_json_field "$(cat .harness/runtime/last-audit.json)" ".status" "completed"
assert_json_field "$(cat .harness/runtime/last-audit.json)" '.last_run_at != null' "true"
assert_json_number_gte "$(cat .harness/runtime/last-audit.json)" ".overall_score" "0"
teardown_test_dir

it "surfaces line-count warnings for oversized entry documents"
setup_test_dir
init_git_repo
cat > AGENTS.md <<'EOF'
# Sample Project

## Quick Commands

- npm test

## Architecture

Layered service architecture.

## Constraints

Keep docs updated.
EOF
for i in $(seq 1 205); do
  printf 'Extra detail line %s\n' "$i" >> AGENTS.md
done
git add AGENTS.md >/dev/null 2>&1
git commit -m "add oversized entry document" --quiet >/dev/null 2>&1
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds on oversized entry document"
assert_json_field "$output" ".dimensions.entry_document.line_count" "218"
assert_json_field "$output" ".dimensions.entry_document.score" "70"
assert_json_field "$output" '.dimensions.entry_document.status | contains("218 lines")' "true"
if printf '%s' "$output" | jq -r '.dimensions.entry_document.fix' | grep -q "218 lines"; then
  pass_test "entry document fix references exact line count"
else
  fail_test "entry document fix missing exact line count"
fi
teardown_test_dir

it "checks context policy presence and budget in documentation structure"
setup_test_dir
init_git_repo
mkdir -p docs/project .harness
cat > docs/project/ARCHITECTURE.md <<'EOF'
# 项目架构

## 系统上下文

订单服务负责订单创建。
EOF
cat > .harness/context-policy.json <<'EOF'
{
  "version": "1.0.0",
  "max_context_files": 12
}
EOF
output=$(bash "$REPO_ROOT/scripts/audit-harness.sh" 2>&1)
status=$?
assert_success "$status" "audit command succeeds with context policy"
assert_json_field "$output" ".dimensions.doc_structure.score" "30"
assert_json_field "$output" '.dimensions.doc_structure.details | index(".harness/context-policy.json found") != null' "true"
assert_json_field "$output" '.dimensions.doc_structure.details | index("Context budget configured (max 12 files)") != null' "true"
teardown_test_dir

print_summary
