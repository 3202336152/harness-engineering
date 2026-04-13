#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_JSON=0
MISSING=()

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

usage() {
  cat <<'EOF'
Usage: check-runtime-deps.sh [--json]
EOF
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
