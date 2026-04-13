#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

exit_if_version_flag "${1:-}"

FEATURE_ID=""
FEATURE_DIR=""
CONFIG_PATH="harness/.harness/spec-policy.json"
OUTPUT_JSON=0

usage() {
  cat <<'EOF'
Usage: check-rollback-readiness.sh [--feature-id <id> | --feature-dir <path>] [--config <path>] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --feature-id)
        FEATURE_ID="${2:-}"
        shift 2
        ;;
      --feature-dir)
        FEATURE_DIR="${2:-}"
        shift 2
        ;;
      --config)
        CONFIG_PATH="${2:-$CONFIG_PATH}"
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
}

resolve_feature_dir() {
  local feature_base_dir
  feature_base_dir="$(jq -r '.feature_spec.base_dir // "harness/docs/features"' "$CONFIG_PATH")"

  if [ -n "$FEATURE_DIR" ]; then
    printf '%s' "$FEATURE_DIR"
    return
  fi

  if [ -n "$FEATURE_ID" ] && [ -d "$feature_base_dir" ]; then
    find "$feature_base_dir" -mindepth 1 -maxdepth 1 -type d -name "$FEATURE_ID-*" | sort | head -1
  fi
}

emit_json_report() {
  local status="$1"
  local feature_dir="$2"
  shift 2
  local missing=("$@")

  printf '{'
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"feature_dir":"%s",' "$(json_escape "$feature_dir")"
  printf '"rollback_required":%s,' "$( [ "$status" = "skipped" ] && printf 'false' || printf 'true' )"
  printf '"missing_items":'
  append_array_json "${missing[@]-}"
  printf '}\n'
}

main() {
  local feature_dir=""
  local manifest_path=""
  local rollout_path=""
  local rollback_required="false"
  local missing=()
  local status="passed"

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  feature_dir="$(resolve_feature_dir)"
  if [ -z "$feature_dir" ] || [ ! -d "$feature_dir" ]; then
    printf '{"status":"error","error":"Unable to resolve feature directory"}\n'
    exit 1
  fi

  manifest_path="$feature_dir/manifest.json"
  rollout_path="$(first_existing_feature_doc "$feature_dir" rollout || true)"

  if [ -f "$manifest_path" ] && [ "$(jq -r '.rollback_required // false' "$manifest_path")" = "true" ]; then
    rollback_required="true"
  fi

  if [ "$rollback_required" != "true" ]; then
    status="skipped"
  else
    if [ ! -f "$rollout_path" ]; then
      missing+=("$(feature_doc_filename rollout)")
    else
      grep -Fq "## 发布前检查" "$rollout_path" || missing+=("## 发布前检查")
      grep -Fq "## 回滚方案" "$rollout_path" || missing+=("## 回滚方案")
      grep -Fq "## 回滚触发条件" "$rollout_path" || missing+=("## 回滚触发条件")
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
      status="invalid"
    fi
  fi

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report "$status" "$feature_dir" "${missing[@]-}"
  else
    printf 'Rollback readiness %s for %s\n' "$status" "$feature_dir"
  fi

  if [ "$status" = "invalid" ]; then
    exit 1
  fi
}

main "$@"
