#!/bin/bash

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"
OUTPUT_ROOT="harness/.harness/templates"
TEMPLATE_PATH=""
FORCE=0
LIST_ONLY=0

CREATED_FILES=()
SKIPPED_FILES=()

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"

exit_if_version_flag "${1:-}"

usage() {
  cat <<'EOF'
Usage: prepare-template-overrides.sh [--output-root <path>] [--template <relative-path>] [--force] [--list]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output-root)
        OUTPUT_ROOT="${2:-$OUTPUT_ROOT}"
        shift 2
        ;;
      --template)
        TEMPLATE_PATH="${2:-}"
        shift 2
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --list)
        LIST_ONLY=1
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

export_template() {
  local logical_path="$1"
  local source_file=""
  local target_file="$OUTPUT_ROOT/$logical_path"
  local target_dir

  if ! source_file="$(default_template_file "$logical_path")"; then
    printf '{"status":"error","error":"Missing built-in template: %s"}\n' "$(json_escape "$logical_path")"
    exit 1
  fi

  if [ -f "$target_file" ] && [ "$FORCE" -ne 1 ]; then
    SKIPPED_FILES+=("$target_file")
    return
  fi

  target_dir="$(dirname "$target_file")"
  mkdir -p "$target_dir"
  cp "$source_file" "$target_file"
  CREATED_FILES+=("$target_file")
}

emit_report() {
  printf '{'
  printf '"status":"success",'
  printf '"mode":"export",'
  printf '"output_root":"%s",' "$(json_escape "$OUTPUT_ROOT")"
  printf '"created_files":'
  append_safe_array_json "CREATED_FILES"
  printf ','
  printf '"skipped_files":'
  append_safe_array_json "SKIPPED_FILES"
  printf '}\n'
}

emit_list_report() {
  local templates=()
  local template_file

  while IFS= read -r template_file; do
    [ -n "$template_file" ] || continue
    templates+=("$template_file")
  done <<EOF
$(list_default_template_files)
EOF

  printf '{'
  printf '"status":"success",'
  printf '"mode":"list",'
  printf '"output_root":"%s",' "$(json_escape "$OUTPUT_ROOT")"
  printf '"templates":'
  append_array_json "${templates[@]}"
  printf '}\n'
}

main() {
  parse_args "$@"
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "" "$OUTPUT_ROOT"

  if [ "$LIST_ONLY" -eq 1 ]; then
    emit_list_report
    exit 0
  fi

  if [ -n "$TEMPLATE_PATH" ]; then
    export_template "$TEMPLATE_PATH"
  else
    while IFS= read -r template_file; do
      [ -n "$template_file" ] || continue
      export_template "$template_file"
    done <<EOF
$(list_default_template_files)
EOF
  fi

  emit_report
}

main "$@"
