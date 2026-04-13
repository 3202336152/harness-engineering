#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"
# shellcheck source=scripts/lib/stack-detect.sh
. "$SCRIPT_DIR/lib/stack-detect.sh"

TASK=""
FEATURE_ID=""
CONFIG_PATH="harness/.harness/spec-policy.json"
POLICY_PATH="harness/.harness/context-policy.json"
RUN_POLICY_PATH="harness/.harness/run-policy.json"
OUTPUT_JSON=0
WRITE_BUNDLE=""
STACK="unknown"

REQUIRED_CONTEXT=()
RECOMMENDED_CONTEXT=()
VERIFICATION_STEPS=()
CHANGE_TYPES=()

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

append_safe_array_json() {
  local array_name="$1"
  local length=0

  eval "length=\${#${array_name}[@]}"
  if [ "$length" -eq 0 ]; then
    printf '[]'
    return
  fi

  eval "append_array_json \"\${${array_name}[@]}\""
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

append_required_context() {
  local path="$1"
  [ -n "$path" ] || return 0
  if [ "${#REQUIRED_CONTEXT[@]}" -eq 0 ] || append_unique "$path" "${REQUIRED_CONTEXT[@]}"; then
    REQUIRED_CONTEXT+=("$path")
  fi
}

append_recommended_context() {
  local path="$1"
  [ -n "$path" ] || return 0
  if [ "${#RECOMMENDED_CONTEXT[@]}" -eq 0 ] || append_unique "$path" "${RECOMMENDED_CONTEXT[@]}"; then
    RECOMMENDED_CONTEXT+=("$path")
  fi
}

append_verification_step() {
  local step="$1"
  [ -n "$step" ] || return 0
  if [ "${#VERIFICATION_STEPS[@]}" -eq 0 ] || append_unique "$step" "${VERIFICATION_STEPS[@]}"; then
    VERIFICATION_STEPS+=("$step")
  fi
}

append_change_type() {
  local change_type="$1"
  [ -n "$change_type" ] || return 0
  if [ "${#CHANGE_TYPES[@]}" -eq 0 ] || append_unique "$change_type" "${CHANGE_TYPES[@]}"; then
    CHANGE_TYPES+=("$change_type")
  fi
}

resolve_project_doc_policy_path() {
  local path="$1"

  if printf '%s' "$path" | grep -q '^harness/docs/project/'; then
    first_existing_project_doc_by_path "$path" || printf '%s' "$path"
    return 0
  fi

  printf '%s' "$path"
}

usage() {
  cat <<'EOF'
Usage: resolve-task-context.sh --task <description> [--feature-id <id>] [--config <path>] [--policy <path>] [--json] [--write-bundle <path>]
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
      --config)
        CONFIG_PATH="${2:-$CONFIG_PATH}"
        shift 2
        ;;
      --policy)
        POLICY_PATH="${2:-$POLICY_PATH}"
        shift 2
        ;;
      --run-policy)
        RUN_POLICY_PATH="${2:-$RUN_POLICY_PATH}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --write-bundle)
        WRITE_BUNDLE="${2:-}"
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

  if [ -z "$TASK" ]; then
    printf '{"status":"error","error":"Missing required --task"}\n'
    exit 1
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '{"status":"error","error":"jq is required for resolve-task-context.sh"}\n'
    exit 1
  fi
}

detect_stack() {
  STACK="$(detect_project_stack)"
}

test_command() {
  case "$STACK" in
    node) printf 'npm test' ;;
    java-maven) printf './mvnw clean test' ;;
    java-gradle) printf './gradlew clean test' ;;
    python) printf 'python -m pytest' ;;
    go) printf 'go test ./...' ;;
    rust) printf 'cargo test' ;;
    *) printf '<test-command>' ;;
  esac
}

risk_level() {
  local joined
  joined="$(printf '%s,' "${CHANGE_TYPES[@]-}")"
  if printf '%s' "$joined" | grep -Eq '(^|,)\s*(db|rollout)\s*(,|$)'; then
    printf 'high'
  elif printf '%s' "$joined" | grep -Eq '(^|,)\s*api\s*(,|$)'; then
    printf 'medium'
  else
    printf 'low'
  fi
}

resolve_feature_dir() {
  local feature_base_dir
  feature_base_dir="$(jq -r '.feature_spec.base_dir // "harness/docs/features"' "$CONFIG_PATH")"

  if [ -z "$FEATURE_ID" ] || [ ! -d "$feature_base_dir" ]; then
    return 0
  fi

  find "$feature_base_dir" -mindepth 1 -maxdepth 1 -type d -name "$FEATURE_ID-*" | sort | head -1
}

load_change_types() {
  local manifest_path="$1"
  local overview_path="$2"
  local change_type

  if [ -f "$manifest_path" ]; then
    while IFS= read -r change_type; do
      [ -n "$change_type" ] || continue
      append_change_type "$change_type"
    done <<EOF
$(jq -r '.change_types[]?' "$manifest_path")
EOF
    return
  fi

  if [ -f "$overview_path" ]; then
    while IFS= read -r change_type; do
      [ -n "$change_type" ] || continue
      append_change_type "$change_type"
    done <<EOF
$(awk '
  BEGIN { in_frontmatter=0 }
  /^---$/ {
    if (in_frontmatter == 0) {
      in_frontmatter=1
      next
    }
    exit
  }
  in_frontmatter == 1 && /^change_types:/ {
    line=$0
    sub(/^change_types:[[:space:]]*"?/, "", line)
    gsub(/"$/, "", line)
    gsub(/,/, "\n", line)
    print line
    exit
  }
' "$overview_path")
EOF
  fi
}

build_context_lists() {
  local feature_dir="$1"
  local manifest_path=""
  local overview_path=""
  local item
  local doc
  local path
  local change_type

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    item="$(resolve_project_doc_policy_path "$item")"
    [ -f "$item" ] && append_required_context "$item"
  done <<EOF
$(jq -r '.always_include[]?' "$POLICY_PATH")
EOF

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    [ -f "$item" ] && append_recommended_context "$item"
  done <<EOF
$(jq -r '.support_files[]?' "$POLICY_PATH")
EOF

  if [ -n "$feature_dir" ]; then
    manifest_path="$feature_dir/manifest.json"
    overview_path="$(first_existing_feature_doc "$feature_dir" overview || true)"
    [ -f "$manifest_path" ] && append_required_context "$manifest_path"
    [ -f "$overview_path" ] && append_required_context "$overview_path"
    load_change_types "$manifest_path" "$overview_path"

    if [ -f "$manifest_path" ]; then
      while IFS= read -r doc; do
        [ -n "$doc" ] || continue
        path="$(first_existing_feature_doc_by_name "$feature_dir" "$doc" || true)"
        [ -f "$path" ] && append_required_context "$path"
      done <<EOF
$(jq -r '.required_docs[]?' "$manifest_path")
EOF

      while IFS= read -r path; do
        [ -n "$path" ] || continue
        path="$(resolve_project_doc_policy_path "$path")"
        [ -f "$path" ] && append_recommended_context "$path"
      done <<EOF
$(jq -r '.related_project_docs[]?' "$manifest_path")
EOF
    else
      while IFS= read -r doc; do
        [ -n "$doc" ] || continue
        path="$(first_existing_feature_doc_by_name "$feature_dir" "$doc" || true)"
        [ -f "$path" ] && append_required_context "$path"
      done <<EOF
$(jq -r '.feature_required_docs[]?' "$POLICY_PATH")
EOF
    fi

    for change_type in "${CHANGE_TYPES[@]-}"; do
      [ -n "$change_type" ] || continue
      while IFS= read -r item; do
        [ -n "$item" ] || continue
        if printf '%s' "$item" | grep -q '/'; then
          item="$(resolve_project_doc_policy_path "$item")"
          [ -f "$item" ] && append_required_context "$item"
        else
          path="$(first_existing_feature_doc_by_name "$feature_dir" "$item" || true)"
          [ -f "$path" ] && append_required_context "$path"
        fi
      done <<EOF
$(jq -r --arg change_type "$change_type" '.change_type_context[$change_type][]?' "$POLICY_PATH")
EOF
    done
  fi

  if [ -f "$RUN_POLICY_PATH" ]; then
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      append_verification_step "$item"
    done <<EOF
$(jq -r '.verify_steps[]?' "$RUN_POLICY_PATH")
EOF
  fi
}

emit_json_report() {
  local feature_dir="$1"

  printf '{'
  printf '"status":"success",'
  printf '"task":"%s",' "$(json_escape "$TASK")"
  printf '"feature_id":"%s",' "$(json_escape "$FEATURE_ID")"
  printf '"feature_dir":"%s",' "$(json_escape "$feature_dir")"
  printf '"risk_level":"%s",' "$(json_escape "$(risk_level)")"
  printf '"project_test_command":"%s",' "$(json_escape "$(test_command)")"
  printf '"required_context":'
  append_safe_array_json "REQUIRED_CONTEXT"
  printf ','
  printf '"recommended_context":'
  append_safe_array_json "RECOMMENDED_CONTEXT"
  printf ','
  printf '"change_types":'
  append_safe_array_json "CHANGE_TYPES"
  printf ','
  printf '"verification_steps":'
  append_safe_array_json "VERIFICATION_STEPS"
  if [ -n "$WRITE_BUNDLE" ]; then
    printf ',"bundle_path":"%s"' "$(json_escape "$WRITE_BUNDLE")"
  fi
  printf '}\n'
}

write_bundle() {
  local feature_dir="$1"
  [ -n "$WRITE_BUNDLE" ] || return 0

  mkdir -p "$(dirname "$WRITE_BUNDLE")"
  emit_json_report "$feature_dir" > "$WRITE_BUNDLE"
}

main() {
  local feature_dir=""
  local report=""

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  if [ ! -f "$POLICY_PATH" ]; then
    printf '{"status":"error","error":"Missing context policy: %s"}\n' "$(json_escape "$POLICY_PATH")"
    exit 1
  fi

  detect_stack
  feature_dir="$(resolve_feature_dir)"
  build_context_lists "$feature_dir"
  write_bundle "$feature_dir"
  report="$(emit_json_report "$feature_dir")"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    printf '%s' "$report"
  else
    printf 'Resolved %s required context file(s) for task "%s".\n' "${#REQUIRED_CONTEXT[@]}" "$TASK"
  fi
}

main "$@"
