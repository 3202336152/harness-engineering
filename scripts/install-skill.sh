#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NAME="harness-engineering"
OUTPUT_DIR="$REPO_ROOT/.build/skill-package"
INSTALL_SCOPE="global"
AGENT_NAME=""
SKIP_CONFIRM=1
OUTPUT_JSON=1

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
Usage: install-skill.sh [--global|--project] [--agent <name>] [--output-dir <path>] [--no-yes] [--text]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --global)
        INSTALL_SCOPE="global"
        shift
        ;;
      --project)
        INSTALL_SCOPE="project"
        shift
        ;;
      --agent)
        AGENT_NAME="${2:-}"
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR="${2:-$OUTPUT_DIR}"
        shift 2
        ;;
      --no-yes)
        SKIP_CONFIRM=0
        shift
        ;;
      --text)
        OUTPUT_JSON=0
        shift
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

emit_json() {
  printf '{'
  printf '"status":"success",'
  printf '"scope":"%s",' "$(json_escape "$INSTALL_SCOPE")"
  printf '"package_dir":"%s",' "$(json_escape "$PACKAGE_DIR")"
  printf '"agent":"%s"' "$(json_escape "$AGENT_NAME")"
  printf '}\n'
}

emit_text() {
  printf 'Installed %s from %s\n' "$PACKAGE_NAME" "$PACKAGE_DIR"
}

main() {
  local install_cmd=()

  parse_args "$@"

  bash "$SCRIPT_DIR/check-runtime-deps.sh" >/dev/null

  bash "$SCRIPT_DIR/export-skill-package.sh" --output-dir "$OUTPUT_DIR" >/dev/null
  PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"

  install_cmd=(npx skills add "$PACKAGE_DIR")
  if [ "$INSTALL_SCOPE" = "global" ]; then
    install_cmd+=(-g)
  fi
  if [ -n "$AGENT_NAME" ]; then
    install_cmd+=(-a "$AGENT_NAME")
  fi
  if [ "$SKIP_CONFIRM" -eq 1 ]; then
    install_cmd+=(-y)
  fi

  "${install_cmd[@]}"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json
  else
    emit_text
  fi
}

main "$@"
