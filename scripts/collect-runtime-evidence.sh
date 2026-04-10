#!/bin/bash

set -euo pipefail

RUN_ID=""
TASK=""
FEATURE_ID=""
POLICY_PATH=".harness/observability-policy.json"
OUTPUT_DIR=""
SUMMARY_FILE=""
OUTPUT_JSON=0

COMMAND_RECORDS=()
FILE_RECORDS=()

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

sanitize_id() {
  local value="$1"
  value="${value// /-}"
  value="${value//\//-}"
  value="${value//\\/-}"
  value="${value//:/-}"
  value="${value//\"/-}"
  printf '%s' "$value"
}

run_capture_command() {
  local capture_id="$1"
  local command="$2"
  local output_file="$3"
  local status=0

  set +e
  bash -lc "$command" > "$output_file" 2>&1
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    COMMAND_RECORDS+=("$capture_id|success|$output_file|$status")
  else
    COMMAND_RECORDS+=("$capture_id|failed|$output_file|$status")
  fi
}

copy_capture_file() {
  local capture_id="$1"
  local source_path="$2"
  local target_path="$3"

  if [ -f "$source_path" ]; then
    cp "$source_path" "$target_path"
    FILE_RECORDS+=("$capture_id|success|$source_path|$target_path")
  elif [ -d "$source_path" ]; then
    cp -R "$source_path" "$target_path"
    FILE_RECORDS+=("$capture_id|success|$source_path|$target_path")
  else
    FILE_RECORDS+=("$capture_id|failed|$source_path|$target_path")
  fi
}

usage() {
  cat <<'EOF'
Usage: collect-runtime-evidence.sh --run-id <id> [--task <text>] [--feature-id <id>] [--policy <path>] [--summary-file <path>] [--output-dir <path>] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run-id)
        RUN_ID="${2:-}"
        shift 2
        ;;
      --task)
        TASK="${2:-}"
        shift 2
        ;;
      --feature-id)
        FEATURE_ID="${2:-}"
        shift 2
        ;;
      --policy)
        POLICY_PATH="${2:-$POLICY_PATH}"
        shift 2
        ;;
      --summary-file)
        SUMMARY_FILE="${2:-}"
        shift 2
        ;;
      --output-dir)
        OUTPUT_DIR="${2:-}"
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

  if [ -z "$RUN_ID" ]; then
    printf '{"status":"error","error":"Missing required --run-id"}\n'
    exit 1
  fi

  if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=".harness/evidence/$RUN_ID"
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '{"status":"error","error":"jq is required for collect-runtime-evidence.sh"}\n'
    exit 1
  fi
}

emit_command_records_json() {
  local first=1
  local record
  local capture_id
  local status
  local path
  local exit_code

  printf '['
  for record in "${COMMAND_RECORDS[@]-}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r capture_id status path exit_code <<EOF
$record
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"id":"%s","status":"%s","path":"%s","exit_code":%s}' \
      "$(json_escape "$capture_id")" \
      "$(json_escape "$status")" \
      "$(json_escape "$path")" \
      "$exit_code"
  done
  printf ']'
}

emit_file_records_json() {
  local first=1
  local record
  local capture_id
  local status
  local source_path
  local target_path

  printf '['
  for record in "${FILE_RECORDS[@]-}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r capture_id status source_path target_path <<EOF
$record
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"id":"%s","status":"%s","source_path":"%s","stored_path":"%s"}' \
      "$(json_escape "$capture_id")" \
      "$(json_escape "$status")" \
      "$(json_escape "$source_path")" \
      "$(json_escape "$target_path")"
  done
  printf ']'
}

write_manifest() {
  local manifest_path="$1"
  local status="$2"

  printf '{\n' > "$manifest_path"
  printf '  "status": "%s",\n' "$(json_escape "$status")" >> "$manifest_path"
  printf '  "run_id": "%s",\n' "$(json_escape "$RUN_ID")" >> "$manifest_path"
  printf '  "task": "%s",\n' "$(json_escape "$TASK")" >> "$manifest_path"
  printf '  "feature_id": "%s",\n' "$(json_escape "$FEATURE_ID")" >> "$manifest_path"
  printf '  "policy_path": "%s",\n' "$(json_escape "$POLICY_PATH")" >> "$manifest_path"
  printf '  "summary_file": "%s",\n' "$(json_escape "$SUMMARY_FILE")" >> "$manifest_path"
  printf '  "commands": ' >> "$manifest_path"
  emit_command_records_json >> "$manifest_path"
  printf ',\n' >> "$manifest_path"
  printf '  "file_artifacts": ' >> "$manifest_path"
  emit_file_records_json >> "$manifest_path"
  printf '\n}\n' >> "$manifest_path"
}

emit_json_report() {
  local status="$1"
  local manifest_path="$2"

  printf '{'
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"run_id":"%s",' "$(json_escape "$RUN_ID")"
  printf '"evidence_dir":"%s",' "$(json_escape "$OUTPUT_DIR")"
  printf '"manifest_path":"%s",' "$(json_escape "$manifest_path")"
  printf '"command_capture_count":%s,' "${#COMMAND_RECORDS[@]}"
  printf '"file_capture_count":%s,' "${#FILE_RECORDS[@]}"
  printf '"commands":'
  emit_command_records_json
  printf ','
  printf '"file_artifacts":'
  emit_file_records_json
  printf '}\n'
}

main() {
  local commands_dir=""
  local files_dir=""
  local manifest_path=""
  local status="success"
  local capture_id=""
  local command=""
  local source_path=""
  local target_path=""

  parse_args "$@"
  require_jq

  if [ ! -f "$POLICY_PATH" ]; then
    printf '{"status":"error","error":"Missing observability policy: %s"}\n' "$(json_escape "$POLICY_PATH")"
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"
  commands_dir="$OUTPUT_DIR/commands"
  files_dir="$OUTPUT_DIR/files"
  manifest_path="$OUTPUT_DIR/manifest.json"
  mkdir -p "$commands_dir" "$files_dir"

  if [ -n "$SUMMARY_FILE" ] && [ -f "$SUMMARY_FILE" ]; then
    cp "$SUMMARY_FILE" "$OUTPUT_DIR/summary.json"
  fi

  while IFS=$'\t' read -r capture_id command; do
    [ -n "$capture_id" ] || continue
    run_capture_command "$capture_id" "$command" "$commands_dir/$(sanitize_id "$capture_id").txt"
  done <<EOF
$(jq -r '.always_capture_commands[]? | [.id, .command] | @tsv' "$POLICY_PATH")
EOF

  while IFS=$'\t' read -r capture_id command; do
    [ -n "$capture_id" ] || continue
    run_capture_command "$capture_id" "$command" "$commands_dir/$(sanitize_id "$capture_id").txt"
  done <<EOF
$(jq -r '.runtime_capture_commands[]? | select(.enabled == true and (.command // "") != "") | [.id, .command] | @tsv' "$POLICY_PATH")
EOF

  while IFS=$'\t' read -r capture_id source_path; do
    [ -n "$capture_id" ] || continue
    target_path="$files_dir/$(sanitize_id "$capture_id")"
    copy_capture_file "$capture_id" "$source_path" "$target_path"
  done <<EOF
$(jq -r '.file_artifacts[]? | select(.enabled == true and (.path // "") != "") | [.id, .path] | @tsv' "$POLICY_PATH")
EOF

  if printf '%s\n' "${COMMAND_RECORDS[@]-}" | grep -q '|failed|'; then
    status="partial"
  fi
  if printf '%s\n' "${FILE_RECORDS[@]-}" | grep -q '|failed|'; then
    status="partial"
  fi

  write_manifest "$manifest_path" "$status"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report "$status" "$manifest_path"
  else
    printf 'Collected runtime evidence in %s\n' "$OUTPUT_DIR"
  fi
}

main "$@"
