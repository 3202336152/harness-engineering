#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NAME="harness-engineering"
OUTPUT_DIR="$REPO_ROOT/.build/skill-package"
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

usage() {
  cat <<'EOF'
Usage: export-skill-package.sh [--output-dir <path>] [--text]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output-dir)
        OUTPUT_DIR="${2:-$OUTPUT_DIR}"
        shift 2
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

copy_path() {
  local relative_path="$1"
  local source_path="$REPO_ROOT/$relative_path"
  local target_path="$PACKAGE_DIR/$relative_path"

  if [ ! -e "$source_path" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$target_path")"
  cp -R "$source_path" "$target_path"
  COPIED_PATHS+=("$relative_path")
}

remove_dot_store() {
  find "$PACKAGE_DIR" -name '.DS_Store' -type f -delete 2>/dev/null || true
}

emit_json() {
  printf '{'
  printf '"status":"success",'
  printf '"package_name":"%s",' "$(json_escape "$PACKAGE_NAME")"
  printf '"package_dir":"%s",' "$(json_escape "$PACKAGE_DIR")"
  printf '"copied_paths":'
  append_array_json "${COPIED_PATHS[@]-}"
  printf '}\n'
}

emit_text() {
  printf 'Exported slim skill package to %s\n' "$PACKAGE_DIR"
}

main() {
  parse_args "$@"

  PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"
  COPIED_PATHS=()

  rm -rf "$PACKAGE_DIR"
  mkdir -p "$PACKAGE_DIR"

  copy_path "SKILL.md"
  copy_path "README.md"
  copy_path "LICENSE"
  copy_path "CHANGELOG.md"
  copy_path "assets"
  copy_path "references"
  copy_path "scripts"
  copy_path "doc/文档导航.md"
  copy_path "doc/本地使用指南.md"
  copy_path "doc/能力与功能说明.md"
  copy_path "doc/安装与试点指南.md"

  remove_dot_store

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json
  else
    emit_text
  fi
}

main "$@"
