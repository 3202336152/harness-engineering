#!/bin/bash

set -euo pipefail

OUTPUT_JSON=0
MISSING=()

usage() {
  cat <<'EOF'
Usage: check-runtime-deps.sh [--json]
EOF
}

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
    [ -n "$item" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
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

check_command() {
  local name="$1"

  if ! command -v "$name" >/dev/null 2>&1; then
    MISSING+=("$name")
  fi
}

emit_json() {
  local status="ok"

  if [ "${#MISSING[@]}" -gt 0 ]; then
    status="missing_dependencies"
  fi

  printf '{'
  printf '"status":"%s",' "$status"
  printf '"required_commands":'
  append_array_json "bash" "git" "jq"
  printf ','
  printf '"missing_commands":'
  append_array_json "${MISSING[@]-}"
  printf ','
  printf '"windows_note":"Windows users should run harness-engineering from WSL2 or another POSIX-compatible shell environment."'
  printf '}\n'
}

emit_text() {
  if [ "${#MISSING[@]}" -eq 0 ]; then
    printf 'Runtime dependencies are available: bash, git, jq\n'
  else
    printf 'Missing required commands: %s\n' "${MISSING[*]}"
    printf 'Windows users should run harness-engineering from WSL2 or another POSIX-compatible shell environment.\n'
  fi
}

main() {
  parse_args "$@"

  check_command "bash"
  check_command "git"
  check_command "jq"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json
  else
    emit_text
  fi

  if [ "${#MISSING[@]}" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
