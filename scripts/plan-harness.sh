#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

exit_if_version_flag "${1:-}"

TASK=""
AGENT="unknown-agent"
FEATURE_ID=""
CHANGE_TYPES=""
DRY_RUN=0
OUTPUT_DIR="$(exec_plan_dir_path active)"

usage() {
  cat <<'EOF'
Usage: plan-harness.sh --task <description> [--agent <name>] [--feature-id <id>] [--change-types <csv>] [--output-dir <path>] [--dry-run]
EOF
}

slugify() {
  local slug

  slug="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  slug="${slug//$'\n'/-}"
  slug="${slug//$'\r'/-}"
  slug="${slug//$'\t'/-}"
  slug="${slug// /-}"
  slug="${slug//\//-}"
  slug="${slug//\\/-}"
  slug="${slug//:/-}"
  slug="${slug//\?/-}"
  slug="${slug//\*/-}"
  slug="${slug//\"/-}"
  slug="${slug//</-}"
  slug="${slug//>/-}"
  slug="${slug//|/-}"

  while [[ "$slug" == *--* ]]; do
    slug="${slug//--/-}"
  done
  while [[ "$slug" == -* ]]; do
    slug="${slug#-}"
  done
  while [[ "$slug" == *- ]]; do
    slug="${slug%-}"
  done
  while [[ "$slug" == .* ]]; do
    slug="${slug#.}"
  done
  while [[ "$slug" == *. ]]; do
    slug="${slug%.}"
  done

  printf '%s' "$slug"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --task|--title)
        TASK="${2:-}"
        shift 2
        ;;
      --agent)
        AGENT="${2:-}"
        shift 2
        ;;
      --feature-id)
        FEATURE_ID="${2:-}"
        shift 2
        ;;
      --change-types)
        CHANGE_TYPES="${2:-}"
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR="${2:-}"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        if [ -z "$TASK" ]; then
          TASK="$1"
        else
          TASK="$TASK $1"
        fi
        shift
        ;;
    esac
  done

  if [ -z "$TASK" ]; then
    printf '{"status":"error","error":"Missing task description"}\n'
    exit 1
  fi
}

risk_level() {
  if printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*(db|rollout)\s*(,|$)'; then
    printf 'high'
  elif printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*api\s*(,|$)'; then
    printf 'medium'
  else
    printf 'low'
  fi
}

rollback_required() {
  if printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*(db|rollout)\s*(,|$)'; then
    printf 'true'
  else
    printf 'false'
  fi
}

build_plan_body() {
  local task="$1"
  local created_date
  created_date="$(date +%F)"

  cat <<EOF
# Execution Plan: $task

## Status
Active

## Created
$created_date

## Agent
$AGENT

## Objective
Implement: $task

## Constraints
- Follow $(project_doc_path architecture) layered model and dependency boundaries.
- Comply with $(project_doc_path development) and the project-level spec set.
- Use $(project_doc_path testing) as the verification baseline for new changes.
- Update the related feature spec files under harness/docs/features/ when behavior or architecture changes.

## Acceptance Criteria
- [ ] All relevant tests pass
- [ ] Type check passes when the project supports it
- [ ] Lint passes when the project supports it
- [ ] Relevant docs are updated
- [ ] User-facing behavior for "$task" is verified

## Implementation Steps

### Phase 1: Discovery and data flow
- [ ] Review the relevant modules, boundaries, and existing patterns
- [ ] Add or update the foundational tests first

### Phase 2: Core implementation
- [ ] Implement the smallest change that satisfies the new behavior
- [ ] Keep dependencies aligned with the layered architecture

### Phase 3: Integration and verification
- [ ] Connect the change to the calling layer or UI surface
- [ ] Re-run validation and capture any follow-up documentation updates

## Decision Log
- $created_date: Initial plan generated for "$task"

## Issues
- [ ] None
EOF
}

write_machine_plan() {
  local title="$1"
  local markdown_path="$2"
  local json_path="$3"
  local created_date="$4"
  local risk

  risk="$(risk_level)"

  if [ "$DRY_RUN" -ne 0 ]; then
    return
  fi

  printf '{\n' > "$json_path"
  printf '  "task": "%s",\n' "$(json_escape "$title")" >> "$json_path"
  printf '  "feature_id": "%s",\n' "$(json_escape "$FEATURE_ID")" >> "$json_path"
  printf '  "change_types": ' >> "$json_path"
  if [ -n "$CHANGE_TYPES" ]; then
    append_array_json $(printf '%s' "$CHANGE_TYPES" | tr ',' ' ')
  else
    append_array_json
  fi >> "$json_path"
  printf ',\n' >> "$json_path"
  printf '  "agent": "%s",\n' "$(json_escape "$AGENT")" >> "$json_path"
  printf '  "created": "%s",\n' "$(json_escape "$created_date")" >> "$json_path"
  printf '  "markdown_path": "%s",\n' "$(json_escape "$markdown_path")" >> "$json_path"
  printf '  "required_docs": ' >> "$json_path"
  append_array_json "$(project_doc_path core-beliefs)" "$(project_doc_path architecture)" "$(project_doc_path development)" "$(project_doc_path testing)" >> "$json_path"
  printf ',\n' >> "$json_path"
  printf '  "required_checks": ' >> "$json_path"
  append_array_json "validate-spec" "check-doc-impact" "lint-architecture" >> "$json_path"
  printf ',\n' >> "$json_path"
  printf '  "risk_level": "%s",\n' "$(json_escape "$risk")" >> "$json_path"
  printf '  "rollback_required": %s\n' "$(rollback_required)" >> "$json_path"
  printf '}\n' >> "$json_path"
}

output_report() {
  local title="$1"
  local path="$2"
  local machine_plan_path="$3"
  printf '{'
  printf '"status":"success",'
  printf '"title":"%s",' "$(json_escape "$title")"
  printf '"path":"%s",' "$(json_escape "$path")"
  printf '"machine_plan_path":"%s",' "$(json_escape "$machine_plan_path")"
  printf '"agent":"%s",' "$(json_escape "$AGENT")"
  printf '"dry_run":%s,' "$( [ "$DRY_RUN" -eq 1 ] && printf 'true' || printf 'false' )"
  printf '"references":'
  append_array_json "$(project_doc_path architecture)" "$(project_doc_path core-beliefs)" "$(project_doc_path development)" "$(project_doc_path testing)"
  printf '}\n'
}

main() {
  local slug
  local plan_path
  local machine_plan_path
  local body
  local created_date

  parse_args "$@"
  slug="$(slugify "$TASK")"
  if [ -z "$slug" ]; then
    slug="execution-plan"
  fi
  plan_path="$OUTPUT_DIR/$slug.md"
  machine_plan_path="$OUTPUT_DIR/$slug.json"
  created_date="$(date +%F)"
  body="$(build_plan_body "$TASK")"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$OUTPUT_DIR"
    printf '%s\n' "$body" > "$plan_path"
  fi
  write_machine_plan "$TASK" "$plan_path" "$machine_plan_path" "$created_date"

  output_report "$TASK" "$plan_path" "$machine_plan_path"
}

main "$@"
