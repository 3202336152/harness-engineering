#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"
# shellcheck source=scripts/lib/entry-docs.sh
. "$SCRIPT_DIR/lib/entry-docs.sh"

exit_if_version_flag "${1:-}"

DEEP_MODE="false"
DEEP_ARCH_EXECUTED="false"
DEEP_ARCH_STATUS="skipped"
DEEP_ARCH_EXIT_CODE=0
DEEP_ARCH_REPORTED_STATUS=""
DEEP_ARCH_REASON="not_requested"
DEEP_SPEC_EXECUTED="false"
DEEP_SPEC_STATUS="skipped"
DEEP_SPEC_EXIT_CODE=0
DEEP_SPEC_REPORTED_STATUS=""
DEEP_SPEC_REASON="not_requested"
CAPTURE_OUTPUT=""
CAPTURE_STATUS=0

ENTRY_SCORE=0
ENTRY_LINE_COUNT=0
ENTRY_STATUS=""
ENTRY_DETAILS=""
ENTRY_FIX="Run /harness init to create an entry doc such as AGENTS.md, CLAUDE.md, or GEMINI.md."

DOC_SCORE=0
DOC_STATUS=""
DOC_DETAILS=""
DOC_FIX="Create the project-level spec set under harness/docs/project/ (项目架构、开发规范、测试策略、安全规范), and keep harness/.harness/spec-policy.json plus harness/.harness/context-policy.json aligned with it."

FRESHNESS_SCORE=0
FRESHNESS_STATUS=""
FRESHNESS_DETAILS=""
FRESHNESS_FIX="Review stale documents and keep them aligned with the current codebase."

ARCH_SCORE=0
ARCH_STATUS=""
ARCH_DETAILS=""
ARCH_FIX="Add architecture boundary checks and wire them into CI."

TEST_SCORE=0
TEST_STATUS=""
TEST_DETAILS=""
TEST_FIX="Configure tests, add a test directory, and run tests in CI."

AUTOMATION_SCORE=0
AUTOMATION_STATUS=""
AUTOMATION_DETAILS=""
AUTOMATION_FIX="Add CI, pre-commit hooks, and a pull request template."

EXEC_SCORE=0
EXEC_STATUS=""
EXEC_DETAILS=""
EXEC_FIX="Create harness/.harness/exec-plans/active and track real execution plans there."

SECURITY_SCORE=0
SECURITY_STATUS=""
SECURITY_DETAILS=""
SECURITY_FIX="Document security guidance in $(project_doc_path security) and ignore secrets in version control."

OVERALL_SCORE=0
MATURITY_LEVEL=0
MATURITY_LABEL="No Harness"
LAST_AUDIT_PATH="harness/.harness/runtime/last-audit.json"
LAST_AUDIT_WRITTEN=0

usage() {
  cat <<'EOF'
Usage: audit-harness.sh [--deep]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --deep)
        DEEP_MODE="true"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf '{"status":"error","error":"Unknown argument: %s"}\n' "$(json_escape "$1")"
        exit 1
        ;;
    esac
  done
}

append_detail() {
  if [ -n "$1" ]; then
    printf '%s\n%s' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

file_timestamp() {
  local file="$1"
  local ts=""

  ts="$(git log -1 --format='%ct' -- "$file" 2>/dev/null || true)"
  if [ -n "$ts" ]; then
    printf '%s' "$ts"
    return
  fi

  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  elif stat -c %Y "$file" >/dev/null 2>&1; then
    stat -c %Y "$file"
  else
    date +%s
  fi
}

json_array_from_lines() {
  local text="$1"
  local first=1
  local line
  printf '['
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$line")"
  done <<EOF
$text
EOF
  printf ']'
}

first_existing_entry_document() {
  first_existing_entry_document_path || true
}

capture_command_output() {
  CAPTURE_OUTPUT=""
  CAPTURE_STATUS=0

  set +e
  CAPTURE_OUTPUT="$("$@" 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

reported_status_from_output() {
  printf '%s' "$1" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

emit_deep_check_json() {
  local executed="$1"
  local status="$2"
  local exit_code="$3"
  local reported_status="$4"
  local reason="$5"

  printf '{"executed":%s,"status":"%s","exit_code":%s' \
    "$executed" \
    "$(json_escape "$status")" \
    "$exit_code"
  if [ -n "$reported_status" ]; then
    printf ',"reported_status":"%s"' "$(json_escape "$reported_status")"
  fi
  if [ -n "$reason" ]; then
    printf ',"reason":"%s"' "$(json_escape "$reason")"
  fi
  printf '}'
}

emit_deep_checks_json() {
  printf '{'
  printf '"architecture_lint":'
  emit_deep_check_json "$DEEP_ARCH_EXECUTED" "$DEEP_ARCH_STATUS" "$DEEP_ARCH_EXIT_CODE" "$DEEP_ARCH_REPORTED_STATUS" "$DEEP_ARCH_REASON"
  printf ','
  printf '"spec_validation":'
  emit_deep_check_json "$DEEP_SPEC_EXECUTED" "$DEEP_SPEC_STATUS" "$DEEP_SPEC_EXIT_CODE" "$DEEP_SPEC_REPORTED_STATUS" "$DEEP_SPEC_REASON"
  printf '}'
}

snapshot_deep_fields_json() {
  if [ "$DEEP_MODE" != "true" ]; then
    return
  fi

  printf ',\n  "deep_mode": true,\n  "deep_checks": %s' "$(emit_deep_checks_json)"
}

ci_files() {
  find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null
  if [ -f .gitlab-ci.yml ]; then
    printf '%s\n' ".gitlab-ci.yml"
  fi
}

any_file_matches() {
  local pattern="$1"
  shift || true
  local path
  for path in "$@"; do
    [ -f "$path" ] || continue
    if grep -Eiq "$pattern" "$path" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

first_existing_path() {
  local path
  for path in "$@"; do
    if [ -f "$path" ]; then
      printf '%s' "$path"
      return
    fi
  done
}

score_entry_document() {
  local file
  local line_count=0
  file="$(first_existing_entry_document)"

  if [ -z "$file" ]; then
    ENTRY_LINE_COUNT=0
    ENTRY_STATUS="No AGENTS.md, CLAUDE.md, or GEMINI.md found"
    ENTRY_DETAILS="Missing entry document"
    return
  fi

  ENTRY_SCORE=40
  ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Entry document found: $file")"
  line_count=$(wc -l < "$file" | tr -d ' ')
  ENTRY_LINE_COUNT="$line_count"

  if [ "$line_count" -le 100 ]; then
    ENTRY_SCORE=$((ENTRY_SCORE + 30))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Entry document is under 100 lines ($line_count lines)")"
  elif [ "$line_count" -le 150 ]; then
    ENTRY_SCORE=$((ENTRY_SCORE + 15))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Entry document is over 100 lines ($line_count lines) and should be trimmed")"
  elif [ "$line_count" -le 200 ]; then
    ENTRY_SCORE=$((ENTRY_SCORE + 5))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Entry document is over 150 lines ($line_count lines); move detailed guidance to harness/docs/")"
  else
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "WARNING: Entry document exceeds 200 lines ($line_count lines); agent context quality is degraded")"
  fi

  if grep -Eiq '^## (Quick Commands|快速命令)' "$file"; then
    ENTRY_SCORE=$((ENTRY_SCORE + 10))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Quick commands section present")"
  fi

  if grep -Eiq '^## (Architecture|架构)' "$file"; then
    ENTRY_SCORE=$((ENTRY_SCORE + 10))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Architecture section present")"
  fi

  if grep -Eiq '^## (Constraints|约束)' "$file"; then
    ENTRY_SCORE=$((ENTRY_SCORE + 10))
    ENTRY_DETAILS="$(append_detail "$ENTRY_DETAILS" "Constraints section present")"
  fi

  ENTRY_STATUS="Entry document score: $ENTRY_SCORE ($line_count lines)"
  if [ "$ENTRY_SCORE" -ge 100 ]; then
    ENTRY_FIX="Entry document already looks healthy."
  elif [ "$line_count" -gt 200 ]; then
    ENTRY_FIX="Entry document is $line_count lines. Move detailed implementation notes into harness/docs/project/ or harness/.harness/references/ and keep the entry document as a short index under 100 lines."
  elif [ "$line_count" -gt 100 ]; then
    ENTRY_FIX="Entry document is $line_count lines. Trim inline detail and replace it with short pointers to harness/docs/project/ and harness/docs/features/."
  else
    ENTRY_FIX="Keep the entry document concise and add quick commands, architecture, and constraints sections."
  fi
}

score_doc_structure() {
  local file
  local max_files=""
  for file in \
    "$(first_existing_project_doc architecture || true)" \
    "$(first_existing_project_doc development || true)" \
    "$(first_existing_project_doc testing || true)" \
    "$(first_existing_project_doc security || true)"; do
    [ -n "$file" ] || continue
    if [ "$(wc -l < "$file" | tr -d ' ')" -gt 2 ]; then
      DOC_SCORE=$((DOC_SCORE + 25))
      DOC_DETAILS="$(append_detail "$DOC_DETAILS" "$file exists with content")"
    else
      DOC_SCORE=$((DOC_SCORE + 10))
      DOC_DETAILS="$(append_detail "$DOC_DETAILS" "$file exists but is sparse")"
    fi
  done

  if [ -z "$(first_existing_project_doc architecture || true)" ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Architecture spec missing")"
  fi
  if [ -z "$(first_existing_project_doc development || true)" ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Development conventions missing")"
  fi
  if [ -z "$(first_existing_project_doc testing || true)" ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Testing spec missing")"
  fi
  if [ -z "$(first_existing_project_doc security || true)" ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Security spec missing")"
  fi

  if [ -f harness/.harness/spec-policy.json ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "harness/.harness/spec-policy.json found")"
  fi

  if [ -f harness/.harness/context-policy.json ]; then
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "harness/.harness/context-policy.json found")"
    if command -v jq >/dev/null 2>&1; then
      max_files="$(jq -r '.max_context_files // empty' harness/.harness/context-policy.json 2>/dev/null || true)"
      if [ -n "$max_files" ] && [ "$max_files" -gt 0 ] 2>/dev/null && [ "$max_files" -le 15 ] 2>/dev/null; then
        DOC_SCORE=$((DOC_SCORE + 5))
        DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Context budget configured (max $max_files files)")"
      elif [ -n "$max_files" ] && [ "$max_files" -gt 15 ] 2>/dev/null; then
        DOC_DETAILS="$(append_detail "$DOC_DETAILS" "WARNING: max_context_files=$max_files is high; consider reducing to 12 or fewer")"
      else
        DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Context budget file present but max_context_files is missing or invalid")"
      fi
    else
      DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Context budget file present but jq is unavailable for max_context_files inspection")"
    fi
  else
    DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Missing harness/.harness/context-policy.json")"
  fi

  if [ "$DOC_SCORE" -gt 100 ]; then
    DOC_SCORE=100
  fi

  DOC_STATUS="Documentation structure score: $DOC_SCORE"
  if [ "$DOC_SCORE" -ge 100 ]; then
    DOC_FIX="Documentation structure already covers the core files."
  fi
}

score_doc_freshness() {
  local docs_found=0
  local stale_count=0
  local file
  local last_modified=0
  local now
  local age_days=0

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    FRESHNESS_SCORE=50
    FRESHNESS_STATUS="Not a git repository"
    FRESHNESS_DETAILS="Freshness cannot be verified without git history"
    FRESHNESS_FIX="Initialize git or commit documentation regularly."
    return
  fi

  now=$(date +%s)
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    docs_found=$((docs_found + 1))
    last_modified="$(file_timestamp "$file")"
    age_days=$(( (now - last_modified) / 86400 ))
    if [ "$age_days" -gt 30 ]; then
      stale_count=$((stale_count + 1))
      FRESHNESS_DETAILS="$(append_detail "$FRESHNESS_DETAILS" "$file is stale ($age_days days)")"
    else
      FRESHNESS_DETAILS="$(append_detail "$FRESHNESS_DETAILS" "$file is fresh")"
    fi
  done <<EOF
$(find "$(harness_docs_root_path)" -type f -name '*.md' 2>/dev/null | sort)
EOF

  if [ "$docs_found" -eq 0 ]; then
    FRESHNESS_SCORE=0
    FRESHNESS_STATUS="No documentation found"
    if [ -z "$FRESHNESS_DETAILS" ]; then
      FRESHNESS_DETAILS="No docs to evaluate"
    fi
    return
  fi

  FRESHNESS_SCORE=$(( (docs_found - stale_count) * 100 / docs_found ))
  FRESHNESS_STATUS="Documentation freshness score: $FRESHNESS_SCORE"
  if [ "$FRESHNESS_SCORE" -ge 100 ]; then
    FRESHNESS_FIX="Documentation is fresh."
  fi
}

score_architecture_constraints() {
  local ci_path
  if [ -f scripts/lint-architecture.sh ] || [ -f harness/.harness/architecture.json ]; then
    ARCH_SCORE=$((ARCH_SCORE + 40))
    ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Architecture validation artifact found")"
  fi

  if [ -f .eslintrc ] || [ -f .eslintrc.json ] || [ -f .eslintrc.js ] || [ -f .ruff.toml ] || [ -f pyproject.toml ] || [ -f .golangci.yml ] || [ -f .golangci.yaml ]; then
    ARCH_SCORE=$((ARCH_SCORE + 20))
    ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Linter configuration found")"
  fi

  for ci_path in $(ci_files); do
    if grep -Eiq 'architecture|lint-arch|boundary|lint-architecture' "$ci_path" 2>/dev/null; then
      ARCH_SCORE=$((ARCH_SCORE + 20))
      ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Architecture checks appear in CI")"
      break
    fi
  done

  if any_file_matches 'layer|dependency|boundary' "$(project_doc_path architecture)" "$(project_docs_dir_path)/ARCHITECTURE.md"; then
    ARCH_SCORE=$((ARCH_SCORE + 20))
    ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Architecture document describes constraints")"
  fi

  ARCH_STATUS="Architecture constraint score: $ARCH_SCORE"
  if [ "$ARCH_SCORE" -ge 100 ]; then
    ARCH_FIX="Architecture constraints already look strong."
  fi
}

score_test_coverage() {
  local ci_path
  if ([ -f package.json ] && grep -Eiq '"test"[[:space:]]*:' package.json) || \
     [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ] || \
     ([ -f pyproject.toml ] && grep -Eiq 'pytest' pyproject.toml) || \
     [ -f go.mod ] || [ -f Cargo.toml ]; then
    TEST_SCORE=$((TEST_SCORE + 30))
    TEST_DETAILS="$(append_detail "$TEST_DETAILS" "Test command configured")"
  fi

  if [ -d tests ] || [ -d __tests__ ] || [ -d src/test/java ] || \
     find . -type f \( -name '*_test.go' -o -name 'test_*.py' -o -name '*.test.ts' -o -name '*.test.js' -o -name '*Test.java' -o -name '*IT.java' \) | grep -q .; then
    TEST_SCORE=$((TEST_SCORE + 30))
    TEST_DETAILS="$(append_detail "$TEST_DETAILS" "Test files or directories found")"
  fi

  for ci_path in $(ci_files); do
    if grep -Eiq 'npm test|pytest|go test|cargo test|run tests|(\./mvnw|mvn)[^[:cntrl:]]*test|(\./gradlew|gradle)[^[:cntrl:]]*test' "$ci_path" 2>/dev/null; then
      TEST_SCORE=$((TEST_SCORE + 20))
      TEST_DETAILS="$(append_detail "$TEST_DETAILS" "Tests run in CI")"
      break
    fi
  done

  if ([ -f package.json ] && grep -Eiq '"coverage"[[:space:]]*:' package.json) || \
     ([ -f pyproject.toml ] && grep -Eiq 'pytest-cov' pyproject.toml) || \
     find . -maxdepth 2 -type f \( -name 'coverage*' -o -name '*lcov*' \) | grep -q .; then
    TEST_SCORE=$((TEST_SCORE + 20))
    TEST_DETAILS="$(append_detail "$TEST_DETAILS" "Coverage configuration found")"
  fi

  TEST_STATUS="Test readiness score: $TEST_SCORE"
  if [ "$TEST_SCORE" -ge 100 ]; then
    TEST_FIX="Testing setup already looks strong."
  fi
}

score_automation() {
  if ci_files | grep -q .; then
    AUTOMATION_SCORE=$((AUTOMATION_SCORE + 50))
    AUTOMATION_DETAILS="$(append_detail "$AUTOMATION_DETAILS" "CI pipeline found")"
  fi

  if [ -d .husky ] || [ -f .git/hooks/pre-commit ] || [ -f .pre-commit-config.yaml ]; then
    AUTOMATION_SCORE=$((AUTOMATION_SCORE + 30))
    AUTOMATION_DETAILS="$(append_detail "$AUTOMATION_DETAILS" "Pre-commit hook configuration found")"
  fi

  if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then
    AUTOMATION_SCORE=$((AUTOMATION_SCORE + 20))
    AUTOMATION_DETAILS="$(append_detail "$AUTOMATION_DETAILS" "Pull request template found")"
  fi

  AUTOMATION_STATUS="Automation score: $AUTOMATION_SCORE"
  if [ "$AUTOMATION_SCORE" -ge 100 ]; then
    AUTOMATION_FIX="Automation is already in good shape."
  fi
}

score_exec_plans() {
  if [ -d "$(exec_plan_root_path)" ]; then
    EXEC_SCORE=$((EXEC_SCORE + 40))
    EXEC_DETAILS="$(append_detail "$EXEC_DETAILS" "$(exec_plan_root_path) exists")"
    if [ -d "$(exec_plan_dir_path active)" ]; then
      EXEC_SCORE=$((EXEC_SCORE + 20))
      EXEC_DETAILS="$(append_detail "$EXEC_DETAILS" "active plans directory exists")"
    fi
    if [ -d "$(exec_plan_dir_path completed)" ]; then
      EXEC_SCORE=$((EXEC_SCORE + 20))
      EXEC_DETAILS="$(append_detail "$EXEC_DETAILS" "completed plans directory exists")"
    fi
    if find "$(exec_plan_root_path)" -type f -name '*.md' 2>/dev/null | grep -q .; then
      EXEC_SCORE=$((EXEC_SCORE + 20))
      EXEC_DETAILS="$(append_detail "$EXEC_DETAILS" "Execution plan files found")"
    fi
  else
    EXEC_DETAILS="$(exec_plan_root_path) is missing"
  fi

  EXEC_STATUS="Execution plan score: $EXEC_SCORE"
  if [ "$EXEC_SCORE" -ge 100 ]; then
    EXEC_FIX="Execution plans are already being tracked."
  fi
}

score_security_governance() {
  if [ -f .gitignore ] && grep -Eq '(^|/)\.env($|[^A-Za-z0-9_-])|^\.env$' .gitignore; then
    SECURITY_SCORE=$((SECURITY_SCORE + 30))
    SECURITY_DETAILS="$(append_detail "$SECURITY_DETAILS" ".env is ignored")"
  fi

  if [ -n "$(first_existing_project_doc security || true)" ] || [ -f SECURITY.md ]; then
    SECURITY_SCORE=$((SECURITY_SCORE + 30))
    SECURITY_DETAILS="$(append_detail "$SECURITY_DETAILS" "Security documentation found")"
  fi

  if [ -f .gitignore ] && grep -Eiq 'credentials|secret|\.key' .gitignore; then
    SECURITY_SCORE=$((SECURITY_SCORE + 20))
    SECURITY_DETAILS="$(append_detail "$SECURITY_DETAILS" "Sensitive file patterns are ignored")"
  fi

  if [ -f CODEOWNERS ] || [ -f .github/CODEOWNERS ]; then
    SECURITY_SCORE=$((SECURITY_SCORE + 20))
    SECURITY_DETAILS="$(append_detail "$SECURITY_DETAILS" "CODEOWNERS configured")"
  fi

  SECURITY_STATUS="Security governance score: $SECURITY_SCORE"
  if [ "$SECURITY_SCORE" -ge 100 ]; then
    SECURITY_FIX="Security governance already looks complete."
  fi
}

run_deep_checks() {
  local arch_output=""
  local arch_status=0
  local spec_output=""
  local spec_status=0

  if [ "$DEEP_MODE" != "true" ]; then
    return
  fi

  if [ -f scripts/lint-architecture.sh ]; then
    DEEP_ARCH_EXECUTED="true"
    DEEP_ARCH_REASON=""
    capture_command_output bash scripts/lint-architecture.sh
    arch_output="$CAPTURE_OUTPUT"
    arch_status="$CAPTURE_STATUS"
    DEEP_ARCH_EXIT_CODE="$arch_status"
    DEEP_ARCH_REPORTED_STATUS="$(reported_status_from_output "$arch_output")"
    if [ "$arch_status" -eq 0 ]; then
      case "$DEEP_ARCH_REPORTED_STATUS" in
        warnings|warning)
          DEEP_ARCH_STATUS="warnings"
          ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Deep architecture lint execution reported warnings")"
          ;;
        ""|passed)
          DEEP_ARCH_STATUS="passed"
          ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Deep architecture lint execution passed")"
          ;;
        *)
          DEEP_ARCH_STATUS="$DEEP_ARCH_REPORTED_STATUS"
          ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Deep architecture lint execution reported status: $DEEP_ARCH_REPORTED_STATUS")"
          ;;
      esac
    else
      DEEP_ARCH_STATUS="failed"
      ARCH_DETAILS="$(append_detail "$ARCH_DETAILS" "Deep architecture lint execution failed")"
      ARCH_FIX="Fix the reported architecture lint violations before relying on the current boundary policy."
    fi
  else
    DEEP_ARCH_REASON="missing_script"
  fi

  if [ -f scripts/validate-spec.sh ]; then
    DEEP_SPEC_EXECUTED="true"
    DEEP_SPEC_REASON=""
    capture_command_output bash scripts/validate-spec.sh --json
    spec_output="$CAPTURE_OUTPUT"
    spec_status="$CAPTURE_STATUS"
    DEEP_SPEC_EXIT_CODE="$spec_status"
    DEEP_SPEC_REPORTED_STATUS="$(reported_status_from_output "$spec_output")"
    if [ "$spec_status" -eq 0 ]; then
      DEEP_SPEC_STATUS="passed"
      DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Deep spec validation execution passed")"
    else
      DEEP_SPEC_STATUS="failed"
      DOC_DETAILS="$(append_detail "$DOC_DETAILS" "Deep spec validation execution failed")"
      DOC_FIX="Fix the reported spec validation issues and keep harness/docs plus harness/.harness policies aligned."
    fi
  else
    DEEP_SPEC_REASON="missing_script"
  fi
}

calculate_overall() {
  OVERALL_SCORE=$(( \
    ENTRY_SCORE * 15 + \
    DOC_SCORE * 15 + \
    FRESHNESS_SCORE * 10 + \
    ARCH_SCORE * 15 + \
    TEST_SCORE * 15 + \
    AUTOMATION_SCORE * 10 + \
    EXEC_SCORE * 10 + \
    SECURITY_SCORE * 10 \
  ))
  OVERALL_SCORE=$((OVERALL_SCORE / 100))

  if [ "$OVERALL_SCORE" -ge 90 ]; then
    MATURITY_LEVEL=4
    MATURITY_LABEL="Autonomous Harness"
  elif [ "$OVERALL_SCORE" -ge 70 ]; then
    MATURITY_LEVEL=3
    MATURITY_LABEL="Observable Harness"
  elif [ "$OVERALL_SCORE" -ge 50 ]; then
    MATURITY_LEVEL=2
    MATURITY_LABEL="Constrained Harness"
  elif [ "$OVERALL_SCORE" -ge 25 ]; then
    MATURITY_LEVEL=1
    MATURITY_LABEL="Basic Harness"
  else
    MATURITY_LEVEL=0
    MATURITY_LABEL="No Harness"
  fi
}

priority_impact_for_score() {
  if [ "$1" -lt 50 ]; then
    printf 'high'
  elif [ "$1" -lt 75 ]; then
    printf 'medium'
  else
    printf 'low'
  fi
}

emit_priority_fixes() {
  local rows=""
  local priority=1
  local row
  local score
  local dimension
  local action
  local impact
  local count=0

  rows="$(cat <<EOF
$ENTRY_SCORE|entry_document|$ENTRY_FIX
$DOC_SCORE|doc_structure|$DOC_FIX
$FRESHNESS_SCORE|doc_freshness|$FRESHNESS_FIX
$ARCH_SCORE|architecture_constraints|$ARCH_FIX
$TEST_SCORE|test_coverage|$TEST_FIX
$AUTOMATION_SCORE|automation|$AUTOMATION_FIX
$EXEC_SCORE|exec_plans|$EXEC_FIX
$SECURITY_SCORE|security_governance|$SECURITY_FIX
EOF
)"

  printf '['
  while IFS='|' read -r score dimension action; do
    [ -n "$dimension" ] || continue
    impact="$(priority_impact_for_score "$score")"
    if [ "$impact" = "low" ]; then
      continue
    fi
    if [ "$count" -gt 0 ]; then
      printf ','
    fi
    printf '{"priority":%s,"dimension":"%s","action":"%s","impact":"%s"}' \
      "$priority" \
      "$(json_escape "$dimension")" \
      "$(json_escape "$action")" \
      "$impact"
    priority=$((priority + 1))
    count=$((count + 1))
    if [ "$count" -ge 5 ]; then
      break
    fi
  done <<EOF
$(printf '%s\n' "$rows" | LC_ALL=C sort -n)
EOF
  printf ']'
}

emit_dimension() {
  local score="$1"
  local weight="$2"
  local status="$3"
  local details="$4"
  local fix="$5"

  printf '{"score":%s,"weight":%s,"status":"%s","details":' \
    "$score" \
    "$weight" \
    "$(json_escape "$status")"
  json_array_from_lines "$details"
  printf ',"fix":"%s"}' "$(json_escape "$fix")"
}

emit_entry_dimension() {
  printf '{"score":%s,"weight":%s,"status":"%s","line_count":%s,"details":' \
    "$ENTRY_SCORE" \
    "0.15" \
    "$(json_escape "$ENTRY_STATUS")" \
    "$ENTRY_LINE_COUNT"
  json_array_from_lines "$ENTRY_DETAILS"
  printf ',"fix":"%s"}' "$(json_escape "$ENTRY_FIX")"
}

write_last_audit_snapshot() {
  local priority_fixes_json="$1"
  local timestamp=""

  if [ ! -d "$(harness_runtime_root_path)" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$LAST_AUDIT_PATH")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat > "$LAST_AUDIT_PATH" <<EOF
{
  "version": "1.0.0",
  "status": "completed",
  "last_run_at": "$(json_escape "$timestamp")",
  "overall_score": $OVERALL_SCORE,
  "maturity_level": $MATURITY_LEVEL,
  "maturity_label": "$(json_escape "$MATURITY_LABEL")",
  "priority_fixes": $priority_fixes_json$(snapshot_deep_fields_json)
}
EOF
  LAST_AUDIT_WRITTEN=1
}

output_report() {
  local priority_fixes_json=""
  priority_fixes_json="$(emit_priority_fixes)"

  printf '{'
  printf '"status":"completed",'
  printf '"overall_score":%s,' "$OVERALL_SCORE"
  printf '"maturity_level":%s,' "$MATURITY_LEVEL"
  printf '"maturity_label":"%s",' "$(json_escape "$MATURITY_LABEL")"
  printf '"deep_mode":%s,' "$DEEP_MODE"
  printf '"dimensions":{'
  printf '"entry_document":'
  emit_entry_dimension
  printf ','
  printf '"doc_structure":'
  emit_dimension "$DOC_SCORE" "0.15" "$DOC_STATUS" "$DOC_DETAILS" "$DOC_FIX"
  printf ','
  printf '"doc_freshness":'
  emit_dimension "$FRESHNESS_SCORE" "0.10" "$FRESHNESS_STATUS" "$FRESHNESS_DETAILS" "$FRESHNESS_FIX"
  printf ','
  printf '"architecture_constraints":'
  emit_dimension "$ARCH_SCORE" "0.15" "$ARCH_STATUS" "$ARCH_DETAILS" "$ARCH_FIX"
  printf ','
  printf '"test_coverage":'
  emit_dimension "$TEST_SCORE" "0.15" "$TEST_STATUS" "$TEST_DETAILS" "$TEST_FIX"
  printf ','
  printf '"automation":'
  emit_dimension "$AUTOMATION_SCORE" "0.10" "$AUTOMATION_STATUS" "$AUTOMATION_DETAILS" "$AUTOMATION_FIX"
  printf ','
  printf '"exec_plans":'
  emit_dimension "$EXEC_SCORE" "0.10" "$EXEC_STATUS" "$EXEC_DETAILS" "$EXEC_FIX"
  printf ','
  printf '"security_governance":'
  emit_dimension "$SECURITY_SCORE" "0.10" "$SECURITY_STATUS" "$SECURITY_DETAILS" "$SECURITY_FIX"
  printf '},'
  printf '"snapshot_path":'
  if [ "$LAST_AUDIT_WRITTEN" -eq 1 ]; then
    printf '"%s",' "$(json_escape "$LAST_AUDIT_PATH")"
  else
    printf 'null,'
  fi
  if [ "$DEEP_MODE" = "true" ]; then
    printf '"deep_checks":'
    emit_deep_checks_json
    printf ','
  fi
  printf '"priority_fixes":'
  printf '%s' "$priority_fixes_json"
  printf '}\n'
}

main() {
  parse_args "$@"
  score_entry_document
  score_doc_structure
  score_doc_freshness
  score_architecture_constraints
  score_test_coverage
  score_automation
  score_exec_plans
  score_security_governance
  run_deep_checks
  calculate_overall
  write_last_audit_snapshot "$(emit_priority_fixes)"
  output_report
}

main "$@"
