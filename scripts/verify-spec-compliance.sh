#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="${1:-SKILL.md}"
ERRORS=0

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

fail() {
  printf 'FAIL: %s\n' "$1"
  ERRORS=$((ERRORS + 1))
}

warn() {
  printf 'WARN: %s\n' "$1"
}

pass() {
  printf 'OK: %s\n' "$1"
}

extract_description() {
  awk '
    BEGIN { in_frontmatter=0; desc=0 }
    /^---$/ {
      if (in_frontmatter == 0) {
        in_frontmatter=1
        next
      }
      exit
    }
    in_frontmatter == 0 { next }
    desc == 1 {
      if ($0 ~ /^[A-Za-z0-9_-]+:[[:space:]]*/) {
        exit
      }
      gsub(/^  /, "", $0)
      printf "%s", $0
      next
    }
    /^description:[[:space:]]*/ {
      line=$0
      sub(/^description:[[:space:]]*/, "", line)
      printf "%s", line
      desc=1
    }
  ' "$SKILL_FILE"
}

main() {
  local name
  local description
  local description_len
  local frontmatter_count
  local frontmatter_end
  local total_lines
  local body_lines

  printf 'Verifying Agent Skills specification compliance...\n'

  if [ ! -f "$SKILL_FILE" ]; then
    fail "$SKILL_FILE not found"
    printf 'FAILED: %s compliance error(s)\n' "$ERRORS"
    exit 1
  fi
  pass "$SKILL_FILE exists"

  frontmatter_count="$(grep -c '^---$' "$SKILL_FILE" || true)"
  if [ "$frontmatter_count" -lt 2 ]; then
    fail "YAML frontmatter is incomplete"
  else
    pass "YAML frontmatter delimiters found"
  fi

  name="$(sed -n '/^---$/,/^---$/p' "$SKILL_FILE" | grep '^name:' | head -1 | sed 's/name:[[:space:]]*//')"
  if [ -z "$name" ]; then
    fail "Missing name field"
  else
    if [ ${#name} -gt 64 ]; then
      fail "name exceeds 64 characters"
    elif ! printf '%s' "$name" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
      fail "name format invalid: $name"
    else
      pass "name = $name"
    fi
  fi

  description="$(extract_description)"
  if [ -z "$description" ]; then
    fail "Missing or empty description field"
  else
    description_len=${#description}
    if [ "$description_len" -gt 1024 ]; then
      fail "description exceeds 1024 characters"
    else
      pass "description present ($description_len chars)"
    fi
  fi

  frontmatter_end="$(grep -n '^---$' "$SKILL_FILE" | tail -1 | cut -d: -f1)"
  total_lines="$(wc -l < "$SKILL_FILE")"
  body_lines=$((total_lines - frontmatter_end))
  if [ "$body_lines" -ge 500 ]; then
    warn "SKILL.md body is $body_lines lines (recommended < 500)"
  else
    pass "body = $body_lines lines"
  fi

  if [ ! -d scripts ]; then
    fail "scripts/ directory missing"
  else
    pass "scripts/ directory exists"
  fi

  if [ ! -d references ]; then
    fail "references/ directory missing"
  else
    pass "references/ directory exists"
  fi

  if [ ! -d assets ]; then
    fail "assets/ directory missing"
  else
    pass "assets/ directory exists"
  fi

  if [ "$ERRORS" -gt 0 ]; then
    printf 'FAILED: %s compliance error(s)\n' "$ERRORS"
    exit 1
  fi

  printf 'PASSED: All specification checks passed\n'
}

main "$@"
