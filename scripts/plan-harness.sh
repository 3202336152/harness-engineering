#!/bin/bash

set -euo pipefail

TASK=""
AGENT="unknown-agent"
DRY_RUN=0
OUTPUT_DIR="docs/exec-plans/active"

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
}

append_array_json() {
  local first=1
  local item
  printf '['
  for item in "$@"; do
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

usage() {
  cat <<'EOF'
Usage: plan-harness.sh --task <description> [--agent <name>] [--output-dir <path>] [--dry-run]
EOF
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
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
- Follow docs/ARCHITECTURE.md layered model and dependency boundaries.
- Comply with docs/CONVENTIONS.md golden rules and existing project patterns.
- Use docs/TESTING.md as the verification baseline for new changes.
- Update related docs when behavior or architecture changes.

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

output_report() {
  local title="$1"
  local path="$2"
  printf '{'
  printf '"status":"success",'
  printf '"title":"%s",' "$(json_escape "$title")"
  printf '"path":"%s",' "$(json_escape "$path")"
  printf '"agent":"%s",' "$(json_escape "$AGENT")"
  printf '"dry_run":%s,' "$( [ "$DRY_RUN" -eq 1 ] && printf 'true' || printf 'false' )"
  printf '"references":'
  append_array_json "docs/ARCHITECTURE.md" "docs/CONVENTIONS.md" "docs/TESTING.md"
  printf '}\n'
}

main() {
  local slug
  local plan_path
  local body

  parse_args "$@"
  slug="$(slugify "$TASK")"
  if [ -z "$slug" ]; then
    slug="execution-plan"
  fi
  plan_path="$OUTPUT_DIR/$slug.md"
  body="$(build_plan_body "$TASK")"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$OUTPUT_DIR"
    printf '%s\n' "$body" > "$plan_path"
  fi

  output_report "$TASK" "$plan_path"
}

main "$@"
