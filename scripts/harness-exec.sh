#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-}"
shift || true

# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

TASK=""
FEATURE_ID=""
TITLE=""
OWNER="team"
CHANGE_TYPES=""
AGENT="codex"
STRICT=0
USE_STAGED=0
OUTPUT_JSON=0
PLAN_DIR="docs/exec-plans/active"

RUN_POLICY_PATH=".harness/run-policy.json"
OBSERVABILITY_POLICY_PATH=".harness/observability-policy.json"
TASK_MEMORY_PATH=".harness/runtime/task-memory.json"
PROGRESS_REPORT_PATH=".harness/runtime/progress.md"
RUN_LEDGER_PATH=".harness/runs/ledger.jsonl"
METRICS_LEDGER_PATH=".harness/metrics/ledger.jsonl"

RESOLVED_FEATURE_DIR=""
RESOLVED_TASK=""
RESOLVED_TITLE=""

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
}

json_array_from_lines() {
  printf '%s\n' "$1" | jq -Rn '[inputs | select(length > 0)]'
}

slugify() {
  local slug
  slug="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  slug="${slug//$'\n'/-}"
  slug="${slug//$'\r'/-}"
  slug="${slug//$'\t'/-}"
  slug="${slug// /-}"
  slug="${slug//\//-}"
  slug="${slug//\\/-}"
  slug="${slug//:/-}"
  slug="${slug//\?/-}"
  slug="${slug//\*/-}"
  slug="${slug//\"/-}"
  slug="${slug//</-}"
  slug="${slug//>/-}"
  slug="${slug//|/-}"
  while [[ "$slug" == *--* ]]; do
    slug="${slug//--/-}"
  done
  while [[ "$slug" == -* ]]; do
    slug="${slug#-}"
  done
  while [[ "$slug" == *- ]]; do
    slug="${slug%-}"
  done
  printf '%s' "$slug"
}

extract_frontmatter_value() {
  local file="$1"
  local key="$2"
  awk -v target="$key" '
    BEGIN { in_frontmatter=0 }
    /^---$/ {
      if (in_frontmatter == 0) {
        in_frontmatter=1
        next
      }
      exit
    }
    in_frontmatter == 1 && $0 ~ ("^" target ":") {
      line=$0
      sub("^" target ":[[:space:]]*", "", line)
      gsub(/^"/, "", line)
      gsub(/"$/, "", line)
      print line
      exit
    }
  ' "$file"
}

usage() {
  cat <<'EOF'
Usage:
  harness-exec.sh prepare --task <description> [--feature-id <id>] [--title <title>] [--owner <name>] [--change-types <csv>] [--agent <name>] [--json]
  harness-exec.sh verify [--feature-id <id>] [--strict] [--staged] [--json]
  harness-exec.sh autofix-safe [--json]
  harness-exec.sh run --task <description> [--feature-id <id>] [--title <title>] [--owner <name>] [--change-types <csv>] [--agent <name>] [--strict] [--staged] [--json]
  harness-exec.sh restore [--feature-id <id>] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --task)
        TASK="${2:-}"
        shift 2
        ;;
      --feature-id)
        FEATURE_ID="${2:-}"
        shift 2
        ;;
      --title)
        TITLE="${2:-}"
        shift 2
        ;;
      --owner)
        OWNER="${2:-team}"
        shift 2
        ;;
      --change-types)
        CHANGE_TYPES="${2:-}"
        shift 2
        ;;
      --agent)
        AGENT="${2:-codex}"
        shift 2
        ;;
      --strict)
        STRICT=1
        shift
        ;;
      --staged)
        USE_STAGED=1
        shift
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --plan-dir)
        PLAN_DIR="${2:-$PLAN_DIR}"
        shift 2
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
    printf '{"status":"error","error":"jq is required for harness-exec.sh"}\n'
    exit 1
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

write_json_or_error() {
  local raw="$1"
  local target="$2"

  if printf '%s' "$raw" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$raw" > "$target"
  else
    jq -n \
      --arg status "error" \
      --arg raw_output "$raw" \
      '{status:$status,raw_output:$raw_output}' > "$target"
  fi
}

load_policy_bool() {
  local filter="$1"
  local default_value="$2"

  if [ ! -f "$RUN_POLICY_PATH" ]; then
    printf '%s' "$default_value"
    return
  fi

  jq -r "$filter // $default_value" "$RUN_POLICY_PATH" 2>/dev/null || printf '%s' "$default_value"
}

policy_mode_enabled() {
  local filter="$1"
  local mode="$2"

  if [ ! -f "$RUN_POLICY_PATH" ]; then
    return 1
  fi

  jq -e --arg mode "$mode" "$filter | index(\$mode) != null" "$RUN_POLICY_PATH" >/dev/null 2>&1
}

ensure_runtime_dirs() {
  mkdir -p \
    ".harness/runtime/context" \
    ".harness/runs" \
    ".harness/evidence" \
    ".harness/metrics"
}

iso_timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

generate_run_id() {
  local mode="$1"
  printf '%s-%s-%s' "$mode" "$(date +%Y%m%dT%H%M%S)" "$$"
}

find_feature_dir() {
  local feature_base_dir="docs/features"
  if [ -z "$FEATURE_ID" ] || [ ! -d "$feature_base_dir" ]; then
    return 0
  fi
  find "$feature_base_dir" -mindepth 1 -maxdepth 1 -type d -name "$FEATURE_ID-*" | sort | head -1
}

resolve_feature_metadata() {
  local overview_file=""

  RESOLVED_FEATURE_DIR="$(find_feature_dir)"
  RESOLVED_TASK="$TASK"
  RESOLVED_TITLE="$TITLE"

  if [ -n "$RESOLVED_FEATURE_DIR" ]; then
    overview_file="$(first_existing_feature_doc "$RESOLVED_FEATURE_DIR" overview || true)"
    if [ -f "$overview_file" ]; then
      if [ -z "$RESOLVED_TITLE" ]; then
        RESOLVED_TITLE="$(extract_frontmatter_value "$overview_file" "title")"
      fi
      if [ -z "$RESOLVED_TASK" ]; then
        RESOLVED_TASK="$RESOLVED_TITLE"
      fi
    fi
  fi

  if [ -z "$RESOLVED_TITLE" ] && [ -n "$RESOLVED_TASK" ]; then
    RESOLVED_TITLE="$RESOLVED_TASK"
  fi
  if [ -z "$RESOLVED_TASK" ] && [ -n "$FEATURE_ID" ]; then
    RESOLVED_TASK="$FEATURE_ID"
  fi
  if [ -z "$RESOLVED_TITLE" ] && [ -n "$FEATURE_ID" ]; then
    RESOLVED_TITLE="$FEATURE_ID"
  fi
}

update_task_memory() {
  local memory_path="$1"
  local feature_id="$2"
  local task_name="$3"
  local title_name="$4"
  local mode="$5"
  local status="$6"
  local run_id="$7"
  local recorded_at="$8"
  local evidence_dir="$9"
  local run_record_path="${10}"
  local tmp=""
  local project_name=""

  project_name="$(basename "$(pwd)")"
  mkdir -p "$(dirname "$memory_path")"

  if [ ! -f "$memory_path" ]; then
    jq -n \
      --arg version "1.0.0" \
      --arg project "$project_name" \
      --arg updated_at "$recorded_at" \
      '{version:$version,project:$project,updated_at:$updated_at,tasks:[]}' > "$memory_path"
  fi

  tmp="$(mktemp)"
  jq \
    --arg project "$project_name" \
    --arg feature_id "$feature_id" \
    --arg task_name "$task_name" \
    --arg title_name "$title_name" \
    --arg mode "$mode" \
    --arg status "$status" \
    --arg run_id "$run_id" \
    --arg recorded_at "$recorded_at" \
    --arg evidence_dir "$evidence_dir" \
    --arg run_record_path "$run_record_path" \
    '
    .version = (.version // "1.0.0") |
    .project = (.project // $project) |
    .updated_at = $recorded_at |
    .tasks = (
      (if ($feature_id != "" or $task_name != "" or $title_name != "") then
        [{
          feature_id: ($feature_id | select(. != "")),
          task: ($task_name | select(. != "")),
          title: ($title_name | select(. != "")),
          mode: $mode,
          status: $status,
          updated_at: $recorded_at,
          last_run_id: $run_id,
          evidence_dir: ($evidence_dir | select(. != "")),
          run_record_path: ($run_record_path | select(. != ""))
        }]
      else [] end)
      +
      ((.tasks // [])
        | map(
            if $feature_id != "" then
              select((.feature_id // "") != $feature_id)
            elif $task_name != "" then
              select((.task // "") != $task_name)
            else
              .
            end
          )
      )
      | .[:20]
    )
    ' "$memory_path" > "$tmp"
  mv "$tmp" "$memory_path"
}

render_progress_report() {
  local memory_path="$1"
  local run_ledger_path="$2"
  local progress_path="$3"
  local recorded_at="$4"

  mkdir -p "$(dirname "$progress_path")"
  {
    printf '# Harness Progress\n\n'
    printf 'Last updated: %s\n\n' "$recorded_at"
    printf '## Active Tasks\n\n'
    if [ -f "$memory_path" ] && jq -e '(.tasks // []) | length > 0' "$memory_path" >/dev/null 2>&1; then
      jq -r '
        .tasks[:10][]
        | "- "
          + (if (.feature_id // "") != "" then .feature_id + " " else "" end)
          + (.title // .task // "Unnamed task")
          + " | status=" + (.status // "unknown")
          + " | mode=" + (.mode // "unknown")
          + " | updated_at=" + (.updated_at // "")
      ' "$memory_path"
    else
      printf '暂无任务。\n'
    fi
    printf '\n## Recent Runs\n\n'
    if [ -f "$run_ledger_path" ] && [ -s "$run_ledger_path" ]; then
      tail -n 10 "$run_ledger_path" | jq -s -r '
        reverse[]
        | "- "
          + (.run_id // "unknown-run")
          + " | mode=" + (.mode // "unknown")
          + " | status=" + (.status // "unknown")
          + (if (.feature_id // "") != "" then " | feature=" + .feature_id else "" end)
          + " | at=" + (.recorded_at // "")
      '
    else
      printf '暂无记录。\n'
    fi
  } > "$progress_path"
}

select_restore_task_json() {
  local memory_path="$1"

  if [ ! -f "$memory_path" ]; then
    printf '{}'
    return
  fi

  if [ -n "$FEATURE_ID" ]; then
    jq -c --arg feature_id "$FEATURE_ID" \
      '((.tasks // []) | map(select((.feature_id // "") == $feature_id)) | .[0]) // {}' \
      "$memory_path" 2>/dev/null || printf '{}'
  else
    jq -c '(.tasks // [])[0] // {}' "$memory_path" 2>/dev/null || printf '{}'
  fi
}

compact_text_file() {
  local file="$1"
  local max_lines="${2:-40}"

  [ -f "$file" ] || return 0

  awk -v max_lines="$max_lines" '
    NR <= max_lines {
      gsub(/[[:space:]]+/, " ")
      sub(/^ /, "", $0)
      sub(/ $/, "", $0)
      if (length($0) > 0) {
        printf "%s ", $0
      }
    }
  ' "$file" | sed 's/^ *//; s/ *$//'
}

extract_pending_steps_json() {
  local status_file="$1"

  if [ ! -f "$status_file" ]; then
    printf '[]'
    return
  fi

  awk '
    /^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]+/ {
      sub(/^[[:space:]]*-[[:space:]]\[[[:space:]]\][[:space:]]+/, "", $0)
      print
    }
  ' "$status_file" | jq -Rn '[inputs | select(length > 0)]'
}

append_restore_path_line() {
  local lines="$1"
  local path="$2"

  if [ -z "$path" ] || [ ! -f "$path" ]; then
    printf '%s' "$lines"
    return
  fi

  if [ -n "$lines" ] && printf '%s\n' "$lines" | grep -Fxq "$path"; then
    printf '%s' "$lines"
  elif [ -n "$lines" ]; then
    printf '%s\n%s' "$lines" "$path"
  else
    printf '%s' "$path"
  fi
}

fallback_restore_context_bundle_json() {
  local feature_dir="$1"
  local lines=""
  local path=""
  local doc_id=""

  if [ -f AGENTS.md ]; then
    lines="AGENTS.md"
  elif [ -f CLAUDE.md ]; then
    lines="CLAUDE.md"
  fi

  for doc_id in architecture development testing security requirements operations observability; do
    path="$(first_existing_project_doc "$doc_id" || true)"
    lines="$(append_restore_path_line "$lines" "$path")"
  done

  if [ -n "$feature_dir" ] && [ -d "$feature_dir" ]; then
    lines="$(append_restore_path_line "$lines" "$feature_dir/manifest.json")"
    for doc_id in overview design api-spec db-spec test-spec rollout status; do
      path="$(first_existing_feature_doc "$feature_dir" "$doc_id" || true)"
      lines="$(append_restore_path_line "$lines" "$path")"
    done
  fi

  json_array_from_lines "$lines"
}

resolve_restore_context_json() {
  local restore_task="$1"
  local selected_feature_id="$2"
  local context_status=0
  local context_output=""
  local context_cmd=()

  if [ -z "$restore_task" ]; then
    printf '{"required_context":[],"recommended_context":[],"verification_steps":[]}'
    return
  fi

  context_cmd=(bash "$SCRIPT_DIR/resolve-task-context.sh" --task "$restore_task" --json)
  if [ -n "$selected_feature_id" ]; then
    context_cmd+=(--feature-id "$selected_feature_id")
  fi

  context_output="$(run_json_command context_status "${context_cmd[@]}")"
  if [ "$context_status" -eq 0 ] && printf '%s' "$context_output" | jq -e '.status == "success"' >/dev/null 2>&1; then
    printf '%s' "$context_output" | jq -c \
      '{required_context:(.required_context // []),recommended_context:(.recommended_context // []),verification_steps:(.verification_steps // [])}'
  else
    printf '{"required_context":[],"recommended_context":[],"verification_steps":[]}'
  fi
}

restore_stage() {
  local selected_task_json='{}'
  local selected_task=""
  local selected_title=""
  local selected_feature_id="$FEATURE_ID"
  local selected_status=""
  local selected_mode=""
  local selected_run_id=""
  local selected_updated_at=""
  local selected_run_record_path=""
  local selected_evidence_dir=""
  local recent_tasks_json='[]'
  local feature_dir=""
  local status_doc_path=""
  local pending_steps_json='[]'
  local progress_summary=""
  local context_json='{"required_context":[],"recommended_context":[],"verification_steps":[]}'
  local context_bundle_json='[]'
  local recommended_context_json='[]'
  local verification_steps_json='[]'
  local restore_task=""
  local session_restored="false"
  local feature_spec_exists="false"
  local report_status="empty"
  local task_memory_path_output=""
  local progress_report_path_output=""

  if [ -f "$TASK_MEMORY_PATH" ]; then
    task_memory_path_output="$TASK_MEMORY_PATH"
    recent_tasks_json="$(jq -c '(.tasks // [])[:5]' "$TASK_MEMORY_PATH" 2>/dev/null || printf '[]')"
    selected_task_json="$(select_restore_task_json "$TASK_MEMORY_PATH")"
  fi

  if [ -f "$PROGRESS_REPORT_PATH" ]; then
    progress_report_path_output="$PROGRESS_REPORT_PATH"
    progress_summary="$(compact_text_file "$PROGRESS_REPORT_PATH" 40)"
  fi

  selected_task="$(printf '%s' "$selected_task_json" | jq -r '.task // ""' 2>/dev/null || printf '')"
  selected_title="$(printf '%s' "$selected_task_json" | jq -r '.title // ""' 2>/dev/null || printf '')"
  if [ -z "$selected_feature_id" ]; then
    selected_feature_id="$(printf '%s' "$selected_task_json" | jq -r '.feature_id // ""' 2>/dev/null || printf '')"
  fi
  selected_status="$(printf '%s' "$selected_task_json" | jq -r '.status // ""' 2>/dev/null || printf '')"
  selected_mode="$(printf '%s' "$selected_task_json" | jq -r '.mode // ""' 2>/dev/null || printf '')"
  selected_run_id="$(printf '%s' "$selected_task_json" | jq -r '.last_run_id // ""' 2>/dev/null || printf '')"
  selected_updated_at="$(printf '%s' "$selected_task_json" | jq -r '.updated_at // ""' 2>/dev/null || printf '')"
  selected_run_record_path="$(printf '%s' "$selected_task_json" | jq -r '.run_record_path // ""' 2>/dev/null || printf '')"
  selected_evidence_dir="$(printf '%s' "$selected_task_json" | jq -r '.evidence_dir // ""' 2>/dev/null || printf '')"

  if [ -n "$selected_feature_id" ] && [ -d docs/features ]; then
    feature_dir="$(find docs/features -mindepth 1 -maxdepth 1 -type d -name "$selected_feature_id-*" | sort | head -1)"
  fi

  if [ -n "$feature_dir" ]; then
    feature_spec_exists="true"
    status_doc_path="$(first_existing_feature_doc "$feature_dir" status || true)"
    if [ -n "$status_doc_path" ]; then
      pending_steps_json="$(extract_pending_steps_json "$status_doc_path")"
    fi
  fi

  restore_task="$selected_task"
  if [ -z "$restore_task" ]; then
    restore_task="$selected_title"
  fi
  if [ -z "$restore_task" ]; then
    restore_task="$selected_feature_id"
  fi

  context_json="$(resolve_restore_context_json "$restore_task" "$selected_feature_id")"
  context_bundle_json="$(printf '%s' "$context_json" | jq -c '.required_context // []' 2>/dev/null || printf '[]')"
  recommended_context_json="$(printf '%s' "$context_json" | jq -c '.recommended_context // []' 2>/dev/null || printf '[]')"
  verification_steps_json="$(printf '%s' "$context_json" | jq -c '.verification_steps // []' 2>/dev/null || printf '[]')"

  if [ "$context_bundle_json" = "[]" ]; then
    context_bundle_json="$(fallback_restore_context_bundle_json "$feature_dir")"
  fi

  if [ -n "$selected_task" ] || [ -n "$selected_title" ] || [ -n "$selected_feature_id" ] || [ -n "$selected_status" ] || [ -n "$selected_run_id" ] || [ "$feature_spec_exists" = "true" ]; then
    session_restored="true"
    report_status="restored"
  fi

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    jq -n \
      --arg status "$report_status" \
      --argjson session_restored "$session_restored" \
      --argjson feature_spec_exists "$feature_spec_exists" \
      --arg task_memory_path "$task_memory_path_output" \
      --arg progress_report_path "$progress_report_path_output" \
      --arg last_task "$selected_task" \
      --arg last_title "$selected_title" \
      --arg last_feature_id "$selected_feature_id" \
      --arg last_status "$selected_status" \
      --arg last_mode "$selected_mode" \
      --arg last_run_id "$selected_run_id" \
      --arg updated_at "$selected_updated_at" \
      --arg run_record_path "$selected_run_record_path" \
      --arg evidence_dir "$selected_evidence_dir" \
      --arg feature_dir "$feature_dir" \
      --arg status_doc_path "$status_doc_path" \
      --arg progress_summary "$progress_summary" \
      --argjson pending_steps "$pending_steps_json" \
      --argjson recent_tasks "$recent_tasks_json" \
      --argjson context_bundle "$context_bundle_json" \
      --argjson recommended_context "$recommended_context_json" \
      --argjson verification_steps "$verification_steps_json" \
      '
      {
        status: $status,
        session_restored: $session_restored,
        feature_spec_exists: $feature_spec_exists,
        task_memory_path: (if $task_memory_path != "" then $task_memory_path else null end),
        progress_report_path: (if $progress_report_path != "" then $progress_report_path else null end),
        last_task: (if $last_task != "" then $last_task else null end),
        last_title: (if $last_title != "" then $last_title else null end),
        last_feature_id: (if $last_feature_id != "" then $last_feature_id else null end),
        last_status: (if $last_status != "" then $last_status else null end),
        last_mode: (if $last_mode != "" then $last_mode else null end),
        last_run_id: (if $last_run_id != "" then $last_run_id else null end),
        updated_at: (if $updated_at != "" then $updated_at else null end),
        run_record_path: (if $run_record_path != "" then $run_record_path else null end),
        evidence_dir: (if $evidence_dir != "" then $evidence_dir else null end),
        feature_dir: (if $feature_dir != "" then $feature_dir else null end),
        status_doc_path: (if $status_doc_path != "" then $status_doc_path else null end),
        pending_steps: $pending_steps,
        context_bundle: $context_bundle,
        recommended_context: $recommended_context,
        verification_steps: $verification_steps,
        progress_summary: (if $progress_summary != "" then $progress_summary else null end),
        recent_tasks: $recent_tasks
      }
      | with_entries(select(.value != null and .value != ""))
      '
  else
    if [ "$report_status" = "empty" ]; then
      printf 'No previous harness session was found.\n'
      return 0
    fi

    printf '=== Harness Session Restore ===\n'
    if [ -n "$selected_task" ]; then
      printf 'Last task      : %s\n' "$selected_task"
    fi
    if [ -n "$selected_title" ]; then
      printf 'Last title     : %s\n' "$selected_title"
    fi
    if [ -n "$selected_feature_id" ]; then
      printf 'Feature ID     : %s\n' "$selected_feature_id"
    fi
    if [ -n "$selected_status" ]; then
      printf 'Last status    : %s\n' "$selected_status"
    fi
    if [ -n "$selected_mode" ]; then
      printf 'Last mode      : %s\n' "$selected_mode"
    fi
    if [ -n "$selected_run_id" ]; then
      printf 'Last run ID    : %s\n' "$selected_run_id"
    fi
    if [ -n "$feature_dir" ]; then
      printf 'Feature dir    : %s\n' "$feature_dir"
    fi
    printf 'Spec exists    : %s\n' "$feature_spec_exists"

    if [ "$pending_steps_json" != "[]" ]; then
      printf '\nPending steps:\n'
      printf '%s\n' "$pending_steps_json" | jq -r '.[]' | while IFS= read -r step; do
        printf '  - [ ] %s\n' "$step"
      done
    fi

    if [ "$context_bundle_json" != "[]" ]; then
      printf '\nRestore context:\n'
      printf '%s\n' "$context_bundle_json" | jq -r '.[]' | while IFS= read -r path; do
        printf '  %s\n' "$path"
      done
    fi

    if [ -n "$progress_summary" ]; then
      printf '\nProgress summary:\n%s\n' "$progress_summary"
    fi
  fi
}

finalize_with_runtime_artifacts() {
  local mode="$1"
  local result_json="$2"
  local result_tmp=""
  local final_tmp=""
  local artifacts_tmp=""
  local evidence_tmp=""
  local gc_tmp=""
  local summary_tmp=""
  local recorded_at=""
  local run_id=""
  local final_status=""
  local record_run_results="true"
  local record_metrics_ledger="true"
  local record_task_memory="true"
  local record_progress_report="true"
  local record_evidence="true"
  local run_record_path=""
  local run_record_path_output=""
  local run_ledger_path_output=""
  local metrics_ledger_path_output=""
  local task_memory_path_output=""
  local progress_path_output=""
  local evidence_dir=""
  local artifacts_evidence_dir=""
  local evidence_output=""
  local evidence_status=0
  local gc_status=0
  local gc_output=""

  ensure_runtime_dirs
  resolve_feature_metadata

  result_tmp="$(mktemp)"
  final_tmp="$(mktemp)"
  artifacts_tmp="$(mktemp)"
  evidence_tmp="$(mktemp)"
  gc_tmp="$(mktemp)"
  summary_tmp="$(mktemp)"

  printf '%s\n' "$result_json" > "$result_tmp"
  recorded_at="$(iso_timestamp)"
  run_id="$(generate_run_id "$mode")"
  final_status="$(jq -r '.status // "unknown"' "$result_tmp")"

  record_run_results="$(load_policy_bool '.record_run_results' 'true')"
  record_metrics_ledger="$(load_policy_bool '.record_metrics_ledger' 'true')"
  record_task_memory="$(load_policy_bool '.record_task_memory' 'true')"
  record_progress_report="$(load_policy_bool '.record_progress_report' 'true')"
  record_evidence="$(load_policy_bool '.record_evidence' 'true')"

  if [ "$record_run_results" = "true" ]; then
    run_record_path=".harness/runs/$run_id.json"
    run_record_path_output="$run_record_path"
    run_ledger_path_output="$RUN_LEDGER_PATH"
    touch "$RUN_LEDGER_PATH"
  fi

  if [ "$record_metrics_ledger" = "true" ]; then
    metrics_ledger_path_output="$METRICS_LEDGER_PATH"
    touch "$METRICS_LEDGER_PATH"
  fi

  if [ "$record_task_memory" = "true" ]; then
    task_memory_path_output="$TASK_MEMORY_PATH"
  fi

  if [ "$record_progress_report" = "true" ]; then
    progress_path_output="$PROGRESS_REPORT_PATH"
  fi

  jq -n \
    --arg run_id "$run_id" \
    --arg mode "$mode" \
    --arg recorded_at "$recorded_at" \
    --arg feature_id "$FEATURE_ID" \
    --arg feature_dir "$RESOLVED_FEATURE_DIR" \
    --arg task_name "$RESOLVED_TASK" \
    --arg title_name "$RESOLVED_TITLE" \
    --slurpfile result "$result_tmp" \
    '
    {
      run_id: $run_id,
      mode: $mode,
      recorded_at: $recorded_at,
      feature_id: ($feature_id | select(. != "")),
      feature_dir: ($feature_dir | select(. != "")),
      task: ($task_name | select(. != "")),
      title: ($title_name | select(. != "")),
      result: $result[0]
    }
    | with_entries(select(.value != null and .value != ""))
    ' > "$summary_tmp"

  jq -n '{status:"skipped"}' > "$evidence_tmp"
  if [ "$record_evidence" = "true" ] && policy_mode_enabled '(.evidence_on_modes // [])' "$mode"; then
    evidence_dir=".harness/evidence/$run_id"
    artifacts_evidence_dir="$evidence_dir"
    evidence_output="$(run_json_command evidence_status \
      bash "$SCRIPT_DIR/collect-runtime-evidence.sh" \
        --run-id "$run_id" \
        --task "$RESOLVED_TASK" \
        --feature-id "$FEATURE_ID" \
        --policy "$OBSERVABILITY_POLICY_PATH" \
        --output-dir "$evidence_dir" \
        --summary-file "$summary_tmp" \
        --json)"
    write_json_or_error "$evidence_output" "$evidence_tmp"
  fi

  jq -n '{status:"skipped"}' > "$gc_tmp"
  if policy_mode_enabled '(.gc_on_modes // [])' "$mode"; then
    gc_output="$(run_json_command gc_status bash "$SCRIPT_DIR/harness-gc.sh" --run-policy "$RUN_POLICY_PATH" --json)"
    write_json_or_error "$gc_output" "$gc_tmp"
  fi

  jq -n \
    --arg run_id "$run_id" \
    --arg mode "$mode" \
    --arg run_record_path "$run_record_path_output" \
    --arg run_ledger_path "$run_ledger_path_output" \
    --arg metrics_ledger_path "$metrics_ledger_path_output" \
    --arg task_memory_path "$task_memory_path_output" \
    --arg progress_path "$progress_path_output" \
    --arg evidence_dir "$artifacts_evidence_dir" \
    --slurpfile evidence "$evidence_tmp" \
    --slurpfile gc "$gc_tmp" \
    '
    {
      run_id: $run_id,
      mode: $mode,
      run_record_path: ($run_record_path | select(. != "")),
      run_ledger_path: ($run_ledger_path | select(. != "")),
      metrics_ledger_path: ($metrics_ledger_path | select(. != "")),
      task_memory_path: ($task_memory_path | select(. != "")),
      progress_report_path: ($progress_path | select(. != "")),
      evidence_dir: ($evidence_dir | select(. != "")),
      evidence: $evidence[0],
      gc: $gc[0]
    }
    | with_entries(select(.value != null and .value != ""))
    ' > "$artifacts_tmp"

  jq --slurpfile artifacts "$artifacts_tmp" '. + {artifacts:$artifacts[0]}' "$result_tmp" > "$final_tmp"

  if [ "$record_run_results" = "true" ]; then
    jq -n \
      --arg run_id "$run_id" \
      --arg mode "$mode" \
      --arg recorded_at "$recorded_at" \
      --arg feature_id "$FEATURE_ID" \
      --arg feature_dir "$RESOLVED_FEATURE_DIR" \
      --arg task_name "$RESOLVED_TASK" \
      --arg title_name "$RESOLVED_TITLE" \
      --slurpfile result "$final_tmp" \
      '
      {
        run_id: $run_id,
        mode: $mode,
        recorded_at: $recorded_at,
        feature_id: ($feature_id | select(. != "")),
        feature_dir: ($feature_dir | select(. != "")),
        task: ($task_name | select(. != "")),
        title: ($title_name | select(. != "")),
        status: ($result[0].status // "unknown"),
        result: $result[0]
      }
      | with_entries(select(.value != null and .value != ""))
      ' > "$run_record_path"

    jq -c -n \
      --arg run_id "$run_id" \
      --arg mode "$mode" \
      --arg recorded_at "$recorded_at" \
      --arg status "$final_status" \
      --arg feature_id "$FEATURE_ID" \
      --arg feature_dir "$RESOLVED_FEATURE_DIR" \
      --arg task_name "$RESOLVED_TASK" \
      --arg title_name "$RESOLVED_TITLE" \
      --arg run_record_path "$run_record_path" \
      --arg evidence_dir "$artifacts_evidence_dir" \
      '
      {
        run_id: $run_id,
        recorded_at: $recorded_at,
        mode: $mode,
        status: $status,
        feature_id: ($feature_id | select(. != "")),
        feature_dir: ($feature_dir | select(. != "")),
        task: ($task_name | select(. != "")),
        title: ($title_name | select(. != "")),
        run_record_path: $run_record_path,
        evidence_dir: ($evidence_dir | select(. != ""))
      }
      | with_entries(select(.value != null and .value != ""))
      ' >> "$RUN_LEDGER_PATH"

    if [ -n "$artifacts_evidence_dir" ] && [ -d "$artifacts_evidence_dir" ]; then
      cp "$run_record_path" "$artifacts_evidence_dir/summary.json"
    fi
  fi

  if [ "$record_metrics_ledger" = "true" ]; then
    jq -c -n \
      --arg run_id "$run_id" \
      --arg mode "$mode" \
      --arg recorded_at "$recorded_at" \
      --arg feature_id "$FEATURE_ID" \
      --arg task_name "$RESOLVED_TASK" \
      --slurpfile result "$final_tmp" \
      '
      $result[0] as $r
      | {
          run_id: $run_id,
          recorded_at: $recorded_at,
          mode: $mode,
          status: ($r.status // "unknown"),
          feature_id: ($feature_id | select(. != "")),
          task: ($task_name | select(. != "")),
          failed_check_count:
            (if ($r.checks // null) != null then
               (($r.checks | to_entries | map(select((.value.status // "") != "" and (.value.status != "passed" and .value.status != "skipped"))) | length))
             elif ($r.verify.checks // null) != null then
               (($r.verify.checks | to_entries | map(select((.value.status // "") != "" and (.value.status != "passed" and .value.status != "skipped"))) | length))
             else 0 end),
          missing_project_doc_count:
            (if ($r.checks.spec_validation.project.missing_required_docs_count // null) != null then
               ($r.checks.spec_validation.project.missing_required_docs_count // 0)
             elif ($r.verify.checks.spec_validation.project.missing_required_docs_count // null) != null then
               ($r.verify.checks.spec_validation.project.missing_required_docs_count // 0)
             else 0 end),
          invalid_feature_count:
            (if ($r.checks.spec_validation.features.invalid_count // null) != null then
               ($r.checks.spec_validation.features.invalid_count // 0)
             elif ($r.verify.checks.spec_validation.features.invalid_count // null) != null then
               ($r.verify.checks.spec_validation.features.invalid_count // 0)
             else 0 end),
          evidence_status: ($r.artifacts.evidence.status // "skipped")
        }
      | with_entries(select(.value != null and .value != ""))
      ' >> "$METRICS_LEDGER_PATH"
  fi

  if [ "$record_task_memory" = "true" ]; then
    update_task_memory \
      "$TASK_MEMORY_PATH" \
      "$FEATURE_ID" \
      "$RESOLVED_TASK" \
      "$RESOLVED_TITLE" \
      "$mode" \
      "$final_status" \
      "$run_id" \
      "$recorded_at" \
      "$artifacts_evidence_dir" \
      "$run_record_path_output"
  fi

  if [ "$record_progress_report" = "true" ]; then
    render_progress_report "$TASK_MEMORY_PATH" "$RUN_LEDGER_PATH" "$PROGRESS_REPORT_PATH" "$recorded_at"
  fi

  cat "$final_tmp"

  rm -f "$result_tmp" "$final_tmp" "$artifacts_tmp" "$evidence_tmp" "$gc_tmp" "$summary_tmp"
}

prepare_stage() {
  local feature_dir=""
  local feature_created="false"
  local feature_status=0
  local feature_json="{}"
  local plan_status=0
  local plan_json=""
  local context_status=0
  local context_json=""
  local slug=""
  local context_path=""
  local feature_cmd=()
  local plan_cmd=()
  local context_cmd=()
  local feature_tmp=""
  local plan_tmp=""
  local context_tmp=""

  if [ -z "$TASK" ]; then
    printf '{"status":"error","error":"prepare requires --task"}\n'
    return 1
  fi

  feature_dir="$(find_feature_dir)"
  if [ -n "$FEATURE_ID" ] && [ -n "$TITLE" ] && [ -z "$feature_dir" ]; then
    feature_cmd=(bash "$SCRIPT_DIR/new-feature-spec.sh" --id "$FEATURE_ID" --title "$TITLE" --owner "$OWNER")
    if [ -n "$CHANGE_TYPES" ]; then
      feature_cmd+=(--change-types "$CHANGE_TYPES")
    fi
    feature_json="$(run_json_command feature_status "${feature_cmd[@]}")"
    if [ "$feature_status" -ne 0 ]; then
      printf '%s' "$feature_json"
      return "$feature_status"
    fi
    feature_created="true"
    feature_dir="$(printf '%s' "$feature_json" | jq -r '.feature_dir')"
  fi

  plan_cmd=(bash "$SCRIPT_DIR/plan-harness.sh" --task "$TASK" --agent "$AGENT" --output-dir "$PLAN_DIR")
  if [ -n "$FEATURE_ID" ]; then
    plan_cmd+=(--feature-id "$FEATURE_ID")
  fi
  if [ -n "$CHANGE_TYPES" ]; then
    plan_cmd+=(--change-types "$CHANGE_TYPES")
  fi
  plan_json="$(run_json_command plan_status "${plan_cmd[@]}")"
  if [ "$plan_status" -ne 0 ]; then
    printf '%s' "$plan_json"
    return "$plan_status"
  fi

  slug="$(slugify "$TASK")"
  [ -n "$slug" ] || slug="context"
  context_path=".harness/runtime/context/$slug.json"
  context_cmd=(bash "$SCRIPT_DIR/resolve-task-context.sh" --task "$TASK" --json --write-bundle "$context_path")
  if [ -n "$FEATURE_ID" ]; then
    context_cmd+=(--feature-id "$FEATURE_ID")
  fi
  context_json="$(run_json_command context_status "${context_cmd[@]}")"
  if [ "$context_status" -ne 0 ]; then
    printf '%s' "$context_json"
    return "$context_status"
  fi

  feature_tmp="$(mktemp)"
  plan_tmp="$(mktemp)"
  context_tmp="$(mktemp)"
  printf '%s\n' "$feature_json" > "$feature_tmp"
  printf '%s\n' "$plan_json" > "$plan_tmp"
  printf '%s\n' "$context_json" > "$context_tmp"

  jq -n \
    --argjson feature_created "$feature_created" \
    --slurpfile feature "$feature_tmp" \
    --slurpfile plan "$plan_tmp" \
    --slurpfile context "$context_tmp" \
    '{status:"success",feature_created:$feature_created,feature:$feature[0],plan:$plan[0],context:$context[0]}'

  rm -f "$feature_tmp" "$plan_tmp" "$context_tmp"
}

verify_stage() {
  local spec_status=0
  local spec_json=""
  local doc_status=0
  local doc_json=""
  local lint_status=0
  local lint_json=""
  local freshness_status=0
  local freshness_json=""
  local rollback_status=0
  local rollback_json='{"status":"skipped"}'
  local overall="passed"
  local spec_cmd=()
  local doc_cmd=()
  local spec_tmp=""
  local doc_tmp=""
  local lint_tmp=""
  local freshness_tmp=""
  local rollback_tmp=""
  local result_json=""

  spec_cmd=(bash "$SCRIPT_DIR/validate-spec.sh" --json)
  doc_cmd=(bash "$SCRIPT_DIR/check-doc-impact.sh" --json)
  if [ "$STRICT" -eq 1 ]; then
    spec_cmd+=(--strict)
  fi
  if [ "$USE_STAGED" -eq 1 ]; then
    doc_cmd+=(--staged)
  fi

  spec_json="$(run_json_command spec_status "${spec_cmd[@]}")"
  doc_json="$(run_json_command doc_status "${doc_cmd[@]}")"
  lint_json="$(run_json_command lint_status bash "$SCRIPT_DIR/lint-architecture.sh")"
  freshness_json="$(run_json_command freshness_status bash "$SCRIPT_DIR/check-doc-freshness.sh" --json)"

  if [ -n "$FEATURE_ID" ]; then
    rollback_json="$(run_json_command rollback_status bash "$SCRIPT_DIR/check-rollback-readiness.sh" --feature-id "$FEATURE_ID" --json)"
  fi

  for status in "$spec_status" "$doc_status" "$lint_status" "$freshness_status" "$rollback_status"; do
    if [ "$status" -ne 0 ]; then
      overall="invalid"
      break
    fi
  done

  spec_tmp="$(mktemp)"
  doc_tmp="$(mktemp)"
  lint_tmp="$(mktemp)"
  freshness_tmp="$(mktemp)"
  rollback_tmp="$(mktemp)"
  printf '%s\n' "$spec_json" > "$spec_tmp"
  printf '%s\n' "$doc_json" > "$doc_tmp"
  printf '%s\n' "$lint_json" > "$lint_tmp"
  printf '%s\n' "$freshness_json" > "$freshness_tmp"
  printf '%s\n' "$rollback_json" > "$rollback_tmp"

  result_json="$(jq -n \
    --arg status "$overall" \
    --slurpfile spec_validation "$spec_tmp" \
    --slurpfile doc_impact "$doc_tmp" \
    --slurpfile architecture_lint "$lint_tmp" \
    --slurpfile doc_freshness "$freshness_tmp" \
    --slurpfile rollback_readiness "$rollback_tmp" \
    '{status:$status,checks:{spec_validation:$spec_validation[0],doc_impact:$doc_impact[0],architecture_lint:$architecture_lint[0],doc_freshness:$doc_freshness[0],rollback_readiness:$rollback_readiness[0]}}')"

  rm -f "$spec_tmp" "$doc_tmp" "$lint_tmp" "$freshness_tmp" "$rollback_tmp"

  finalize_with_runtime_artifacts "verify" "$result_json"

  if [ "$overall" = "invalid" ]; then
    return 1
  fi
}

autofix_stage() {
  bash "$SCRIPT_DIR/validate-spec.sh" --json --autofix-safe
}

run_stage() {
  local prepare_status=0
  local prepare_json=""
  local verify_status=0
  local verify_json=""
  local autofix_status=0
  local autofix_json='{"status":"skipped"}'
  local verify_after_status=0
  local verify_after_json='{"status":"skipped"}'
  local overall="passed"
  local prepare_cmd=()
  local verify_cmd=()
  local prepare_tmp=""
  local verify_tmp=""
  local autofix_tmp=""
  local verify_after_tmp=""
  local result_json=""

  prepare_cmd=(bash "$SCRIPT_DIR/harness-exec.sh" prepare --task "$TASK" --owner "$OWNER" --agent "$AGENT" --json)
  if [ -n "$FEATURE_ID" ]; then
    prepare_cmd+=(--feature-id "$FEATURE_ID")
  fi
  if [ -n "$TITLE" ]; then
    prepare_cmd+=(--title "$TITLE")
  fi
  if [ -n "$CHANGE_TYPES" ]; then
    prepare_cmd+=(--change-types "$CHANGE_TYPES")
  fi
  prepare_json="$(run_json_command prepare_status "${prepare_cmd[@]}")"
  if [ "$prepare_status" -ne 0 ]; then
    printf '%s' "$prepare_json"
    return "$prepare_status"
  fi

  verify_cmd=(bash "$SCRIPT_DIR/harness-exec.sh" verify --json)
  if [ -n "$FEATURE_ID" ]; then
    verify_cmd+=(--feature-id "$FEATURE_ID")
  fi
  if [ "$STRICT" -eq 1 ]; then
    verify_cmd+=(--strict)
  fi
  if [ "$USE_STAGED" -eq 1 ]; then
    verify_cmd+=(--staged)
  fi
  verify_json="$(run_json_command verify_status "${verify_cmd[@]}")"
  if [ "$verify_status" -ne 0 ]; then
    autofix_json="$(run_json_command autofix_status bash "$SCRIPT_DIR/harness-exec.sh" autofix-safe --json)"
    verify_after_json="$(run_json_command verify_after_status "${verify_cmd[@]}")"
    if [ "$verify_after_status" -ne 0 ]; then
      overall="invalid"
    fi
  fi

  prepare_tmp="$(mktemp)"
  verify_tmp="$(mktemp)"
  autofix_tmp="$(mktemp)"
  verify_after_tmp="$(mktemp)"
  printf '%s\n' "$prepare_json" > "$prepare_tmp"
  printf '%s\n' "$verify_json" > "$verify_tmp"
  printf '%s\n' "$autofix_json" > "$autofix_tmp"
  printf '%s\n' "$verify_after_json" > "$verify_after_tmp"

  result_json="$(jq -n \
    --arg status "$overall" \
    --slurpfile prepare "$prepare_tmp" \
    --slurpfile verify "$verify_tmp" \
    --slurpfile autofix "$autofix_tmp" \
    --slurpfile verify_after_autofix "$verify_after_tmp" \
    '{status:$status,prepare:$prepare[0],verify:$verify[0],autofix:$autofix[0],verify_after_autofix:$verify_after_autofix[0]}')"

  rm -f "$prepare_tmp" "$verify_tmp" "$autofix_tmp" "$verify_after_tmp"

  finalize_with_runtime_artifacts "run" "$result_json"

  if [ "$overall" = "invalid" ]; then
    return 1
  fi
}

main() {
  parse_args "$@"
  require_jq

  case "$MODE" in
    prepare)
      prepare_stage
      ;;
    verify)
      verify_stage
      ;;
    autofix-safe)
      autofix_stage
      ;;
    run)
      if [ -z "$TASK" ]; then
        printf '{"status":"error","error":"run requires --task"}\n'
        exit 1
      fi
      run_stage
      ;;
    restore)
      restore_stage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
