#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NAME="harness-engineering"
OUTPUT_DIR="$REPO_ROOT/.build/skill-package"
OUTPUT_JSON=1

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

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

copy_runtime_paths() {
  local relative_path

  for relative_path in \
    "SKILL.md" \
    "LICENSE" \
    "assets/templates" \
    "assets/hooks" \
    "assets/ci-templates" \
    "references" \
    "schemas" \
    "scripts/audit-harness.sh" \
    "scripts/check-runtime-deps.sh" \
    "scripts/check-doc-freshness.sh" \
    "scripts/check-doc-impact.sh" \
    "scripts/check-rollback-readiness.sh" \
    "scripts/check-template-drift.sh" \
    "scripts/collect-runtime-evidence.sh" \
    "scripts/harness-exec.sh" \
    "scripts/harness-gc.sh" \
    "scripts/init-harness.sh" \
    "scripts/lint-architecture.sh" \
    "scripts/migrate-template-docs.sh" \
    "scripts/new-feature-spec.sh" \
    "scripts/plan-harness.sh" \
    "scripts/prepare-template-overrides.sh" \
    "scripts/resolve-task-context.sh" \
    "scripts/scan-java-project.sh" \
    "scripts/validate-spec.sh" \
    "scripts/lib"; do
    copy_path "$relative_path"
  done
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
  printf 'Exported runtime-only skill package to %s\n' "$PACKAGE_DIR"
}

main() {
  parse_args "$@"

  PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"
  COPIED_PATHS=()

  rm -rf "$PACKAGE_DIR"
  mkdir -p "$PACKAGE_DIR"

  copy_runtime_paths

  remove_dot_store

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json
  else
    emit_text
  fi
}

main "$@"
