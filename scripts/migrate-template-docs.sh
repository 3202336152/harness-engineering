#!/bin/bash

set -euo pipefail

CONFIG_PATH="harness/.harness/spec-policy.json"
MIGRATION_ROOT="harness/.harness/migrations"
OUTPUT_JSON=0
WRITE_REPORT=""
DRY_RUN=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AFFECTED_DOCS=()
BACKED_UP_DOCS=()
CHANGED_DOCS=()

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

append_unique() {
  local value="$1"
  shift
  local item
  for item in "$@"; do
    if [ "$item" = "$value" ]; then
      return 1
    fi
  done
  return 0
}

add_affected_doc() {
  local path="$1"
  [ -n "$path" ] || return 0
  if [ "${#AFFECTED_DOCS[@]}" -eq 0 ] || append_unique "$path" "${AFFECTED_DOCS[@]}"; then
    AFFECTED_DOCS+=("$path")
  fi
}

run_json_command() {
  local __status_var="$1"
  shift
  local output=""
  local status=0
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  printf -v "$__status_var" '%s' "$status"
  printf '%s' "$output"
}

usage() {
  cat <<'EOF'
Usage: migrate-template-docs.sh [--config <path>] [--migration-root <path>] [--write-report <path>] [--dry-run] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config)
        CONFIG_PATH="${2:-$CONFIG_PATH}"
        shift 2
        ;;
      --migration-root)
        MIGRATION_ROOT="${2:-$MIGRATION_ROOT}"
        shift 2
        ;;
      --write-report)
        WRITE_REPORT="${2:-}"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
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

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '{"status":"error","error":"jq is required for migrate-template-docs.sh"}\n'
    exit 1
  fi
}

collect_drifted_docs() {
  local drift_json="$1"
  local feature_base_dir
  local path

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "harness/docs/features"' "$CONFIG_PATH")"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    add_affected_doc "$path"
  done <<EOF
$(printf '%s' "$drift_json" | jq -r '.docs.drifted[]?.path, .docs.missing_metadata[]?.path' 2>/dev/null)
EOF

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    add_affected_doc "$path"
  done <<EOF
$(printf '%s' "$drift_json" | jq -r '
    .features.invalid_features[]? as $feature
    | $feature.missing_docs[]?
    | "'"$feature_base_dir"'" + "/" + $feature.feature + "/" + .
  ' 2>/dev/null)
EOF
}

collect_quality_issue_docs() {
  local validate_json="$1"
  local feature_base_dir
  local path

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "harness/docs/features"' "$CONFIG_PATH")"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    add_affected_doc "$path"
  done <<EOF
$(printf '%s' "$validate_json" | jq -r '
    (.project.quality_issues[]?
      | select(.kind == "missing_section" or .kind == "missing_frontmatter" or .kind == "frontmatter_mismatch")
      | .path),
    (.features.quality_issues[]?
      | select(.kind == "missing_section" or .kind == "missing_frontmatter" or .kind == "frontmatter_mismatch")
      | .path)
  ' 2>/dev/null)
EOF

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    add_affected_doc "$path"
  done <<EOF
$(printf '%s' "$validate_json" | jq -r '
    .project.missing_required_docs[]?,
    (.features.invalid_features[]? as $feature
      | $feature.missing_docs[]?
      | "'"$feature_base_dir"'" + "/" + $feature.feature + "/" + .)
  ' 2>/dev/null)
EOF
}

backup_docs() {
  local migration_dir="$1"
  local path
  local target

  for path in "${AFFECTED_DOCS[@]-}"; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    target="$migration_dir/backup/$path"
    mkdir -p "$(dirname "$target")"
    cp "$path" "$target"
    BACKED_UP_DOCS+=("$target")
  done
}

detect_changed_docs() {
  local migration_dir="$1"
  local path
  local backup

  for path in "${AFFECTED_DOCS[@]-}"; do
    [ -n "$path" ] || continue
    backup="$migration_dir/backup/$path"
    if [ -f "$path" ] && [ ! -f "$backup" ]; then
      CHANGED_DOCS+=("$path")
      continue
    fi
    if [ -f "$path" ] && [ -f "$backup" ] && ! cmp -s "$path" "$backup"; then
      CHANGED_DOCS+=("$path")
    fi
  done
}

write_report() {
  local report_path="$1"
  local migration_dir="$2"
  local autofix_json="$3"
  local remaining_drift="$4"
  local remaining_quality="$5"
  local affected_tmp=""
  local backup_tmp=""
  local changed_tmp=""
  local autofix_tmp=""
  local dry_run_json="false"

  mkdir -p "$(dirname "$report_path")"
  affected_tmp="$(mktemp)"
  backup_tmp="$(mktemp)"
  changed_tmp="$(mktemp)"
  autofix_tmp="$(mktemp)"
  append_array_json "${AFFECTED_DOCS[@]-}" > "$affected_tmp"
  append_array_json "${BACKED_UP_DOCS[@]-}" > "$backup_tmp"
  append_array_json "${CHANGED_DOCS[@]-}" > "$changed_tmp"
  if ! printf '%s' "${autofix_json:-{}}" | jq -c . > "$autofix_tmp" 2>/dev/null; then
    printf '{}\n' > "$autofix_tmp"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    dry_run_json="true"
  fi
  jq -n \
    --arg status "success" \
    --arg migration_dir "$migration_dir" \
    --arg report_path "$report_path" \
    --argjson dry_run "$dry_run_json" \
    --argjson affected_doc_count "${#AFFECTED_DOCS[@]}" \
    --argjson migrated_doc_count "${#CHANGED_DOCS[@]}" \
    --argjson backed_up_doc_count "${#BACKED_UP_DOCS[@]}" \
    --argjson remaining_drift_count "$remaining_drift" \
    --argjson remaining_quality_issue_count "$remaining_quality" \
    --slurpfile affected_docs "$affected_tmp" \
    --slurpfile backed_up_docs "$backup_tmp" \
    --slurpfile changed_docs "$changed_tmp" \
    --slurpfile autofix_summary "$autofix_tmp" \
    '{
      status:$status,
      migration_dir:$migration_dir,
      report_path:$report_path,
      dry_run:$dry_run,
      affected_doc_count:$affected_doc_count,
      migrated_doc_count:$migrated_doc_count,
      backed_up_doc_count:$backed_up_doc_count,
      affected_docs:$affected_docs[0],
      backed_up_docs:$backed_up_docs[0],
      migrated_docs:$changed_docs[0],
      remaining_drift_count:$remaining_drift_count,
      remaining_quality_issue_count:$remaining_quality_issue_count,
      autofix_summary:$autofix_summary[0]
    }' > "$report_path"
  rm -f "$affected_tmp" "$backup_tmp" "$changed_tmp" "$autofix_tmp"
}

emit_json_report() {
  local report_path="$1"
  cat "$report_path"
  printf '\n'
}

main() {
  local drift_status=0
  local validate_status=0
  local autofix_status=0
  local drift_json=""
  local validate_json=""
  local autofix_json='{}'
  local migration_dir=""
  local report_path=""
  local timestamp=""
  local remaining_drift=0
  local remaining_quality=0
  local rerun_drift=""
  local rerun_validate=""

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  drift_json="$(run_json_command drift_status bash "$SCRIPT_DIR/check-template-drift.sh" --config "$CONFIG_PATH" --json)"
  validate_json="$(run_json_command validate_status bash "$SCRIPT_DIR/validate-spec.sh" --config "$CONFIG_PATH" --json)"

  collect_drifted_docs "$drift_json"
  collect_quality_issue_docs "$validate_json"

  timestamp="$(date +%Y%m%dT%H%M%S)"
  migration_dir="$MIGRATION_ROOT/$timestamp"
  report_path="${WRITE_REPORT:-$migration_dir/report.json}"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$migration_dir"
    backup_docs "$migration_dir"
    autofix_json="$(run_json_command autofix_status bash "$SCRIPT_DIR/validate-spec.sh" --config "$CONFIG_PATH" --json --strict --autofix-safe)"
    rerun_drift="$(run_json_command drift_status bash "$SCRIPT_DIR/check-template-drift.sh" --config "$CONFIG_PATH" --json)"
    rerun_validate="$(run_json_command validate_status bash "$SCRIPT_DIR/validate-spec.sh" --config "$CONFIG_PATH" --json)"
    detect_changed_docs "$migration_dir"
    remaining_drift="$(printf '%s' "$rerun_drift" | jq -r '(.docs.drifted_count // 0) + (.docs.missing_metadata_count // 0)' 2>/dev/null || printf '0')"
    remaining_quality="$(printf '%s' "$rerun_validate" | jq -r '
      ([.project.quality_issues[]? | select(.kind == "missing_section" or .kind == "missing_frontmatter" or .kind == "frontmatter_mismatch")] | length) +
      ([.features.quality_issues[]? | select(.kind == "missing_section" or .kind == "missing_frontmatter" or .kind == "frontmatter_mismatch")] | length) +
      (.project.missing_required_docs_count // 0) +
      (.features.invalid_count // 0)
    ' 2>/dev/null || printf '0')"
  fi

  write_report "$report_path" "$migration_dir" "$autofix_json" "$remaining_drift" "$remaining_quality"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report "$report_path"
  else
    printf 'Migrated %s document(s). Report: %s\n' "${#CHANGED_DOCS[@]}" "$report_path"
  fi
}

main "$@"
