#!/bin/bash

set -euo pipefail

RULES_PATH=".harness/doc-impact-rules.json"
OUTPUT_JSON=0
USE_STAGED=0
BASE_REF=""
HEAD_REF="HEAD"

CHANGED_FILES=()
TRIGGERED_RULES=()
SATISFIED_RULES=()
VIOLATIONS=()

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

safe_array_json() {
  local array_name="$1"
  local length=0

  eval "length=\${#${array_name}[@]}"
  if [ "$length" -eq 0 ]; then
    printf '[]'
  else
    eval "append_array_json \"\${${array_name}[@]}\""
  fi
}

usage() {
  cat <<'EOF'
Usage: check-doc-impact.sh [--rules <path>] [--json] [--staged] [--base-ref <ref>] [--head-ref <ref>]
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
    printf '{"status":"error","error":"jq is required for check-doc-impact.sh"}\n'
    exit 1
  fi
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
    diff_output="$(git diff --cached --name-only --diff-filter=ACMR)"
  elif [ -n "$BASE_REF" ]; then
    diff_output="$(git diff --name-only --diff-filter=ACMR "$BASE_REF" "$HEAD_REF")"
  else
    diff_output="$(git diff --name-only --diff-filter=ACMR)"
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    CHANGED_FILES+=("$file")
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
  for record in "${records[@]}"; do
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
  printf '"changed_files_count":%s,' "${#CHANGED_FILES[@]}"
  printf '"changed_files":'
  append_array_json "${CHANGED_FILES[@]}"
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
  printf '}\n'
}

emit_text_report() {
  local record
  local rule_id
  local description
  local guidance

  if [ "${#VIOLATIONS[@]}" -eq 0 ]; then
    printf 'Doc impact check passed. Triggered rules: %s, changed files: %s\n' "${#TRIGGERED_RULES[@]}" "${#CHANGED_FILES[@]}"
    return
  fi

  printf 'Doc impact check failed.\n'
  for record in "${VIOLATIONS[@]}"; do
    IFS='|' read -r rule_id description guidance _ <<EOF
$record
EOF
    printf '- [%s] %s\n' "$rule_id" "$description"
    if [ -n "$guidance" ]; then
      printf '  建议：%s\n' "$guidance"
    fi
  done
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

    for file in "${CHANGED_FILES[@]}"; do
      if [ "${#code_patterns[@]}" -gt 0 ] && matches_any_pattern "$file" "${code_patterns[@]}"; then
        matched_code_files+=("$file")
      fi

      if { [ "${#required_any[@]}" -gt 0 ] && matches_any_pattern "$file" "${required_any[@]}"; } \
        || { [ "${#required_all[@]}" -gt 0 ] && matches_any_pattern "$file" "${required_all[@]}"; }; then
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
      for file in "${CHANGED_FILES[@]}"; do
        if matches_any_pattern "$file" "${required_any[@]}"; then
          any_ok=0
          break
        fi
      done
    fi

    if [ "${#required_all[@]}" -eq 0 ]; then
      all_ok=0
    else
      for pattern in "${required_all[@]}"; do
        [ -n "$pattern" ] || continue
        all_ok=1
        for file in "${CHANGED_FILES[@]}"; do
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
