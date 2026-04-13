#!/bin/bash

set -euo pipefail

THRESHOLD=30
SCAN_PATH="harness/docs"
OUTPUT_JSON=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
}

usage() {
  cat <<'EOF'
Usage: check-doc-freshness.sh [--threshold <days>] [--path <dir>] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --threshold)
        THRESHOLD="${2:-30}"
        shift 2
        ;;
      --path)
        SCAN_PATH="${2:-$(harness_docs_root_path)}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf '{"status":"error","error":"Unknown argument: %s"}\n' "$1"
        exit 1
        ;;
    esac
  done
}

file_timestamp() {
  local file="$1"
  local ts

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

emit_report() {
  local status="$1"
  local score="$2"
  local total="$3"
  local stale="$4"
  local stale_records="$5"
  local first=1
  local file
  local age

  if [ "$OUTPUT_JSON" -eq 0 ]; then
    printf '%s: %s stale document(s) out of %s (score %s)\n' "$status" "$stale" "$total" "$score"
    return
  fi

  printf '{'
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"threshold_days":%s,' "$THRESHOLD"
  printf '"total_docs":%s,' "$total"
  printf '"stale_count":%s,' "$stale"
  printf '"freshness_score":%s,' "$score"
  printf '"path":"%s",' "$(json_escape "$SCAN_PATH")"
  printf '"stale_files":['
  while IFS='|' read -r file age; do
    [ -n "$file" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"file":"%s","age_days":%s}' "$(json_escape "$file")" "$age"
  done <<EOF
$stale_records
EOF
  printf ']}'
  printf '\n'
}

main() {
  local now
  local file
  local total=0
  local stale=0
  local timestamp
  local age_days
  local score=0
  local stale_records=""
  local status="passed"

  parse_args "$@"
  if [ -z "$SCAN_PATH" ]; then
    SCAN_PATH="$(harness_docs_root_path)"
  fi
  now="$(date +%s)"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    total=$((total + 1))
    timestamp="$(file_timestamp "$file")"
    age_days=$(( (now - timestamp) / 86400 ))
    if [ "$age_days" -gt "$THRESHOLD" ]; then
      stale=$((stale + 1))
      if [ -n "$stale_records" ]; then
        stale_records="$stale_records
$file|$age_days"
      else
        stale_records="$file|$age_days"
      fi
    fi
  done <<EOF
$(find "$SCAN_PATH" -type f -name '*.md' 2>/dev/null | sort)
EOF

  if [ "$total" -eq 0 ]; then
    status="empty"
    score=0
  else
    score=$(( (total - stale) * 100 / total ))
    if [ "$stale" -gt 0 ]; then
      status="warning"
    fi
  fi

  emit_report "$status" "$score" "$total" "$stale" "$stale_records"
}

main "$@"
