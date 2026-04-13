#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_PATH="harness/.harness/doc-impact-rules.json"
OUTPUT_JSON=0
USE_STAGED=0
BASE_REF=""
HEAD_REF="HEAD"
SUGGEST_ACTIONS=0
WRITE_ACTION_PLAN=""
DIFF_SOURCE="working_tree"

CHANGED_FILES=()
TRIGGERED_RULES=()
SATISFIED_RULES=()
VIOLATIONS=()
SUGGESTED_ACTIONS=()

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

usage() {
  cat <<'EOF'
Usage: check-doc-impact.sh [--rules <path>] [--json] [--staged] [--base-ref <ref>] [--head-ref <ref>] [--suggest-actions] [--write-action-plan <path>]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --rules)
        RULES_PATH="${2:-$RULES_PATH}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --staged)
        USE_STAGED=1
        shift
        ;;
      --base-ref)
        BASE_REF="${2:-}"
        shift 2
        ;;
      --head-ref)
        HEAD_REF="${2:-HEAD}"
        shift 2
        ;;
      --suggest-actions)
        SUGGEST_ACTIONS=1
        shift
        ;;
      --write-action-plan)
        WRITE_ACTION_PLAN="${2:-}"
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

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '{"status":"error","error":"check-doc-impact.sh must run inside a git repository"}\n'
    exit 1
  fi
}

load_changed_files() {
  local diff_output=""
  local file

  if [ "$USE_STAGED" -eq 1 ]; then
    DIFF_SOURCE="staged"
    diff_output="$(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR)"
  elif [ -n "$BASE_REF" ]; then
    DIFF_SOURCE="range"
    diff_output="$(git -c core.quotePath=false diff --name-only --diff-filter=ACMR "$BASE_REF" "$HEAD_REF")"
  else
    if git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR | grep -q .; then
      DIFF_SOURCE="staged"
      diff_output="$(git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR)"
    else
      DIFF_SOURCE="working_tree"
      diff_output="$(git -c core.quotePath=false diff --name-only --diff-filter=ACMR)"
    fi
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ "${#CHANGED_FILES[@]}" -eq 0 ] || append_unique_value "$file" "${CHANGED_FILES[@]-}"; then
      CHANGED_FILES+=("$file")
    fi
  done <<EOF
$diff_output
EOF
}

matches_pattern() {
  local file="$1"
  local pattern="$2"
  printf '%s\n' "$file" | grep -Eq "$pattern"
}

matches_any_pattern() {
  local file="$1"
  shift
  local pattern
  for pattern in "$@"; do
    [ -n "$pattern" ] || continue
    if matches_pattern "$file" "$pattern"; then
      return 0
    fi
  done
  return 1
}

append_unique_value() {
  local value="$1"
  shift
  local existing
  for existing in "$@"; do
    if [ "$existing" = "$value" ]; then
      return 1
    fi
  done
  return 0
}

load_rule_field_array() {
  local rule_id="$1"
  local field="$2"
  jq -r --arg rule_id "$rule_id" --arg field "$field" '.rules[] | select(.id == $rule_id) | .[$field][]?' "$RULES_PATH"
}

load_rule_field_string() {
  local rule_id="$1"
  local field="$2"
  jq -r --arg rule_id "$rule_id" --arg field "$field" '.rules[] | select(.id == $rule_id) | .[$field] // empty' "$RULES_PATH"
}

emit_rule_records_json() {
  local mode="$1"
  local records=()
  local source_name=""
  local record
  local first=1
  local rule_id
  local description
  local guidance
  local matched_code_json
  local matched_doc_json
  local required_any_json
  local required_all_json

  if [ "$mode" = "triggered" ]; then
    source_name="TRIGGERED_RULES"
  elif [ "$mode" = "satisfied" ]; then
    source_name="SATISFIED_RULES"
  else
    source_name="VIOLATIONS"
  fi

  eval "records=(\"\${${source_name}[@]-}\")"

  printf '['
  for record in "${records[@]-}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r rule_id description guidance matched_code_json matched_doc_json required_any_json required_all_json <<EOF
$record
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{'
    printf '"rule_id":"%s",' "$(json_escape "$rule_id")"
    printf '"description":"%s",' "$(json_escape "$description")"
    if [ -n "$guidance" ]; then
      printf '"guidance":"%s",' "$(json_escape "$guidance")"
    fi
    printf '"matched_code_files":%s,' "${matched_code_json:-[]}"
    printf '"matched_doc_files":%s' "${matched_doc_json:-[]}"
    if [ "$mode" = "violation" ]; then
      printf ','
      printf '"required_doc_patterns_any":%s,' "${required_any_json:-[]}"
      printf '"required_doc_patterns_all":%s' "${required_all_json:-[]}"
    fi
    printf '}'
  done
  printf ']'
}

emit_json_report() {
  local status="passed"
  if [ "${#VIOLATIONS[@]}" -gt 0 ]; then
    status="invalid"
  fi

  printf '{'
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"rules_path":"%s",' "$(json_escape "$RULES_PATH")"
  printf '"diff_source":"%s",' "$(json_escape "$DIFF_SOURCE")"
  printf '"changed_files_count":%s,' "${#CHANGED_FILES[@]}"
  printf '"changed_files":'
  append_array_json "${CHANGED_FILES[@]-}"
  printf ','
  printf '"triggered_rules_count":%s,' "${#TRIGGERED_RULES[@]}"
  printf '"satisfied_rules_count":%s,' "${#SATISFIED_RULES[@]}"
  printf '"violation_count":%s,' "${#VIOLATIONS[@]}"
  printf '"triggered_rules":'
  emit_rule_records_json "triggered"
  printf ','
  printf '"satisfied_rules":'
  emit_rule_records_json "satisfied"
  printf ','
  printf '"violations":'
  emit_rule_records_json "violation"
  if [ "$SUGGEST_ACTIONS" -eq 1 ] || [ -n "$WRITE_ACTION_PLAN" ]; then
    printf ','
    printf '"suggested_action_count":%s,' "${#SUGGESTED_ACTIONS[@]}"
    printf '"suggested_actions":'
    emit_suggested_actions_json
  fi
  printf '}\n'
}

emit_text_report() {
  local record
  local rule_id
  local description
  local guidance
  local action

  if [ "${#VIOLATIONS[@]}" -eq 0 ]; then
    printf 'Doc impact check passed. Diff source: %s, triggered rules: %s, changed files: %s\n' "$DIFF_SOURCE" "${#TRIGGERED_RULES[@]}" "${#CHANGED_FILES[@]}"
    return
  fi

  printf 'Doc impact check failed. Diff source: %s\n' "$DIFF_SOURCE"
  for record in "${VIOLATIONS[@]-}"; do
    IFS='|' read -r rule_id description guidance _ <<EOF
$record
EOF
    printf '- [%s] %s\n' "$rule_id" "$description"
    if [ -n "$guidance" ]; then
      printf '  建议：%s\n' "$guidance"
    fi
  done

  if [ "$SUGGEST_ACTIONS" -eq 1 ] || [ -n "$WRITE_ACTION_PLAN" ]; then
    for action in "${SUGGESTED_ACTIONS[@]-}"; do
      IFS='|' read -r rule_id _ guidance _ <<EOF
$action
EOF
      printf '  可执行建议[%s]: %s\n' "$rule_id" "$guidance"
    done
  fi
}

sections_for_rule() {
  case "$1" in
    java-api-surface)
      append_array_json "## 接口清单" "## 请求设计" "## 响应与错误码"
      ;;
    java-db-change)
      append_array_json "## DDL 与结构变更" "## 数据迁移与回填" "## 回滚与验证"
      ;;
    java-security-change)
      append_array_json "## 认证、授权与审计" "## 输入校验与反序列化安全"
      ;;
    build-or-rollout-change)
      append_array_json "## 发布前检查" "## 回滚触发条件"
      ;;
    architecture-rule-change)
      append_array_json "## 分层与包结构" "## 机械化约束"
      ;;
    *)
      append_array_json
      ;;
  esac
}

candidate_path_from_pattern() {
  local pattern="$1"

  case "$pattern" in
    '^harness/docs/project/接口规范\.md$'|'^harness/docs/project/API-SPEC\.md$') printf 'harness/docs/project/接口规范.md' ;;
    '^harness/docs/project/项目设计\.md$'|'^harness/docs/project/DESIGN\.md$') printf 'harness/docs/project/项目设计.md' ;;
    '^harness/docs/project/安全规范\.md$'|'^harness/docs/project/SECURITY\.md$') printf 'harness/docs/project/安全规范.md' ;;
    '^harness/docs/project/开发规范\.md$'|'^harness/docs/project/DEVELOPMENT\.md$') printf 'harness/docs/project/开发规范.md' ;;
    '^harness/docs/project/项目架构\.md$'|'^harness/docs/project/ARCHITECTURE\.md$') printf 'harness/docs/project/项目架构.md' ;;
    '^harness/docs/features/[^/]+/接口设计\.md$'|'^harness/docs/features/[^/]+/api-spec\.md$') printf 'harness/docs/features/<feature-id>/接口设计.md' ;;
    '^harness/docs/features/[^/]+/数据设计\.md$'|'^harness/docs/features/[^/]+/db-spec\.md$') printf 'harness/docs/features/<feature-id>/数据设计.md' ;;
    '^harness/docs/features/[^/]+/方案设计\.md$'|'^harness/docs/features/[^/]+/design\.md$') printf 'harness/docs/features/<feature-id>/方案设计.md' ;;
    '^harness/docs/features/[^/]+/发布回滚\.md$'|'^harness/docs/features/[^/]+/rollout\.md$') printf 'harness/docs/features/<feature-id>/发布回滚.md' ;;
    *)
      printf '%s' "$pattern" \
        | sed -e 's/^\^//' -e 's/\$$//' -e 's#\\\.#.#g' -e 's#\\/#/#g'
      ;;
  esac
}

emit_suggested_actions_json() {
  local first=1
  local action
  local rule_id
  local action_kind
  local guidance
  local target_paths_json
  local sections_json

  printf '['
  for action in "${SUGGESTED_ACTIONS[@]-}"; do
    [ -n "$action" ] || continue
    IFS='|' read -r rule_id action_kind guidance target_paths_json sections_json <<EOF
$action
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{'
    printf '"rule_id":"%s",' "$(json_escape "$rule_id")"
    printf '"action":"%s",' "$(json_escape "$action_kind")"
    printf '"guidance":"%s",' "$(json_escape "$guidance")"
    printf '"target_paths":%s,' "${target_paths_json:-[]}"
    printf '"suggested_sections":%s' "${sections_json:-[]}"
    printf '}'
  done
  printf ']'
}

build_suggested_actions() {
  local record
  local rule_id
  local description
  local guidance
  local required_any_json
  local required_all_json
  local candidate_paths=()
  local pattern
  local path

  for record in "${VIOLATIONS[@]-}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r rule_id description guidance _ _ required_any_json required_all_json <<EOF
$record
EOF

    candidate_paths=()
    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      path="$(candidate_path_from_pattern "$pattern")"
      if [ -n "$path" ] && { [ "${#candidate_paths[@]}" -eq 0 ] || append_unique_value "$path" "${candidate_paths[@]-}"; }; then
        candidate_paths+=("$path")
      fi
    done <<EOF
$(printf '%s\n%s\n' "$required_any_json" "$required_all_json" | jq -r '.[]?' 2>/dev/null)
EOF

    SUGGESTED_ACTIONS+=(
      "$rule_id|update_docs|${guidance:-$description}|$(append_array_json "${candidate_paths[@]-}")|$(sections_for_rule "$rule_id")"
    )
  done
}

write_action_plan() {
  local output_path="$1"

  [ -n "$output_path" ] || return 0

  mkdir -p "$(dirname "$output_path")"
  printf '{\n' > "$output_path"
  printf '  "status": "planned",\n' >> "$output_path"
  printf '  "violation_count": %s,\n' "${#VIOLATIONS[@]}" >> "$output_path"
  printf '  "actions": ' >> "$output_path"
  emit_suggested_actions_json >> "$output_path"
  printf '\n}\n' >> "$output_path"
}

evaluate_rules() {
  local rule_id
  local description
  local guidance
  local code_patterns=()
  local required_any=()
  local required_all=()
  local matched_code_files=()
  local matched_doc_files=()
  local file
  local pattern
  local any_ok=1
  local all_ok=1

  while IFS= read -r rule_id; do
    [ -n "$rule_id" ] || continue

    description="$(load_rule_field_string "$rule_id" "description")"
    guidance="$(load_rule_field_string "$rule_id" "guidance")"
    code_patterns=()
    required_any=()
    required_all=()
    matched_code_files=()
    matched_doc_files=()
    any_ok=1
    all_ok=1

    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      code_patterns+=("$pattern")
    done <<EOF
$(load_rule_field_array "$rule_id" "code_patterns")
EOF

    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      required_any+=("$pattern")
    done <<EOF
$(load_rule_field_array "$rule_id" "required_doc_patterns_any")
EOF

    while IFS= read -r pattern; do
      [ -n "$pattern" ] || continue
      required_all+=("$pattern")
    done <<EOF
$(load_rule_field_array "$rule_id" "required_doc_patterns_all")
EOF

    for file in "${CHANGED_FILES[@]-}"; do
      if [ "${#code_patterns[@]}" -gt 0 ] && matches_any_pattern "$file" "${code_patterns[@]-}"; then
        matched_code_files+=("$file")
      fi

      if { [ "${#required_any[@]}" -gt 0 ] && matches_any_pattern "$file" "${required_any[@]-}"; } \
        || { [ "${#required_all[@]}" -gt 0 ] && matches_any_pattern "$file" "${required_all[@]-}"; }; then
        matched_doc_files+=("$file")
      fi
    done

    if [ "${#matched_code_files[@]}" -eq 0 ]; then
      continue
    fi

    TRIGGERED_RULES+=(
      "$rule_id|$description|$guidance|$(safe_array_json matched_code_files)|$(safe_array_json matched_doc_files)|$(safe_array_json required_any)|$(safe_array_json required_all)"
    )

    if [ "${#required_any[@]}" -eq 0 ]; then
      any_ok=0
    else
      any_ok=1
      for file in "${CHANGED_FILES[@]-}"; do
        if matches_any_pattern "$file" "${required_any[@]-}"; then
          any_ok=0
          break
        fi
      done
    fi

    if [ "${#required_all[@]}" -eq 0 ]; then
      all_ok=0
    else
      for pattern in "${required_all[@]-}"; do
        [ -n "$pattern" ] || continue
        all_ok=1
        for file in "${CHANGED_FILES[@]-}"; do
          if matches_pattern "$file" "$pattern"; then
            all_ok=0
            break
          fi
        done
        if [ "$all_ok" -ne 0 ]; then
          break
        fi
      done
    fi

    if [ "$any_ok" -eq 0 ] && [ "$all_ok" -eq 0 ]; then
      SATISFIED_RULES+=(
        "$rule_id|$description|$guidance|$(safe_array_json matched_code_files)|$(safe_array_json matched_doc_files)|$(safe_array_json required_any)|$(safe_array_json required_all)"
      )
    else
      VIOLATIONS+=(
        "$rule_id|$description|$guidance|$(safe_array_json matched_code_files)|$(safe_array_json matched_doc_files)|$(safe_array_json required_any)|$(safe_array_json required_all)"
      )
    fi
  done <<EOF
$(jq -r '.rules[]?.id // empty' "$RULES_PATH")
EOF
}

main() {
  parse_args "$@"
  require_jq
  require_git_repo

  if [ ! -f "$RULES_PATH" ]; then
    printf '{"status":"error","error":"Missing doc impact rules: %s"}\n' "$(json_escape "$RULES_PATH")"
    exit 1
  fi

  load_changed_files
  evaluate_rules
  if [ "$SUGGEST_ACTIONS" -eq 1 ] || [ -n "$WRITE_ACTION_PLAN" ]; then
    build_suggested_actions
    write_action_plan "$WRITE_ACTION_PLAN"
  fi

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report
  else
    emit_text_report
  fi

  if [ "${#VIOLATIONS[@]}" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
