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

print_summary
