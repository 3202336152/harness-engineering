#!/bin/bash

set -euo pipefail

CONFIG_PATH=".harness/spec-policy.json"
OUTPUT_JSON=0
STRICT_MODE=-1

MISSING_PROJECT_DOCS=()
INVALID_FEATURES=()
PROJECT_QUALITY_ISSUES=()
FEATURE_QUALITY_ISSUES=()

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
  else
    eval "append_array_json \"\${${array_name}[@]}\""
  fi
}

usage() {
  cat <<'EOF'
Usage: validate-spec.sh [--config <path>] [--json] [--strict]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config)
        CONFIG_PATH="${2:-$CONFIG_PATH}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --strict)
        STRICT_MODE=1
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
    printf '{"status":"error","error":"jq is required for validate-spec.sh"}\n'
    exit 1
  fi
}

has_frontmatter() {
  local file="$1"
  [ -f "$file" ] && head -1 "$file" | grep -q '^---$'
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

record_quality_issue() {
  local scope="$1"
  local feature="$2"
  local path="$3"
  local kind="$4"
  local detail="$5"

  if [ "$scope" = "project" ]; then
    PROJECT_QUALITY_ISSUES+=("$path|$kind|$detail")
  else
    FEATURE_QUALITY_ISSUES+=("$feature|$path|$kind|$detail")
  fi
}

determine_strict_mode() {
  if [ "$STRICT_MODE" -ne -1 ]; then
    return
  fi

  if [ "$(jq -r '.quality_gate.strict_default // false' "$CONFIG_PATH")" = "true" ]; then
    STRICT_MODE=1
  else
    STRICT_MODE=0
  fi
}

check_placeholder_patterns() {
  local scope="$1"
  local feature="$2"
  local file="$3"
  local pattern

  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    if grep -Fq "$pattern" "$file" 2>/dev/null; then
      record_quality_issue "$scope" "$feature" "$file" "placeholder_pattern" "$pattern"
    fi
  done <<EOF
$(jq -r '.quality_gate.placeholder_patterns[]?' "$CONFIG_PATH")
EOF
}

check_template_pack_consistency() {
  local scope="$1"
  local feature="$2"
  local file="$3"
  local expected
  local actual

  expected="$(jq -r '.template_pack.version // empty' "$CONFIG_PATH")"
  actual="$(extract_frontmatter_value "$file" "template_version")"
  if [ -n "$expected" ] && [ -n "$actual" ] && [ "$actual" != "$expected" ]; then
    record_quality_issue "$scope" "$feature" "$file" "frontmatter_mismatch" "template_version=$actual expected=$expected"
  fi

  expected="$(jq -r '.template_pack.profile // empty' "$CONFIG_PATH")"
  actual="$(extract_frontmatter_value "$file" "template_profile")"
  if [ -n "$expected" ] && [ -n "$actual" ] && [ "$actual" != "$expected" ]; then
    record_quality_issue "$scope" "$feature" "$file" "frontmatter_mismatch" "template_profile=$actual expected=$expected"
  fi

  expected="$(jq -r '.template_pack.language // empty' "$CONFIG_PATH")"
  actual="$(extract_frontmatter_value "$file" "template_language")"
  if [ -n "$expected" ] && [ -n "$actual" ] && [ "$actual" != "$expected" ]; then
    record_quality_issue "$scope" "$feature" "$file" "frontmatter_mismatch" "template_language=$actual expected=$expected"
  fi
}

check_project_doc_quality() {
  local path="$1"
  local field
  local section
  local actual

  while IFS= read -r field; do
    [ -n "$field" ] || continue
    actual="$(extract_frontmatter_value "$path" "$field")"
    if [ -z "$actual" ]; then
      record_quality_issue "project" "" "$path" "missing_frontmatter" "$field"
    fi
  done <<EOF
$(jq -r --arg path "$path" '.project_docs[] | select(.path == $path) | .required_frontmatter[]?' "$CONFIG_PATH")
EOF

  while IFS= read -r section; do
    [ -n "$section" ] || continue
    if ! grep -Fq "$section" "$path" 2>/dev/null; then
      record_quality_issue "project" "" "$path" "missing_section" "$section"
    fi
  done <<EOF
$(jq -r --arg path "$path" '.project_docs[] | select(.path == $path) | .required_sections[]?' "$CONFIG_PATH")
EOF

  check_template_pack_consistency "project" "" "$path"
  check_placeholder_patterns "project" "" "$path"
}

check_feature_doc_quality() {
  local feature="$1"
  local path="$2"
  local doc_name="$3"
  local field
  local section
  local actual

  while IFS= read -r field; do
    [ -n "$field" ] || continue
    actual="$(extract_frontmatter_value "$path" "$field")"
    if [ -z "$actual" ]; then
      record_quality_issue "feature" "$feature" "$path" "missing_frontmatter" "$field"
    fi
  done <<EOF
$(jq -r --arg doc "$doc_name" '.feature_spec.doc_rules[$doc].required_frontmatter[]?' "$CONFIG_PATH")
EOF

  while IFS= read -r section; do
    [ -n "$section" ] || continue
    if ! grep -Fq "$section" "$path" 2>/dev/null; then
      record_quality_issue "feature" "$feature" "$path" "missing_section" "$section"
    fi
  done <<EOF
$(jq -r --arg doc "$doc_name" '.feature_spec.doc_rules[$doc].required_sections[]?' "$CONFIG_PATH")
EOF

  check_template_pack_consistency "feature" "$feature" "$path"
  check_placeholder_patterns "feature" "$feature" "$path"
}

check_project_docs() {
  local path
  local required

  while IFS=$'\t' read -r path required; do
    [ -n "$path" ] || continue
    if [ "$required" = "true" ] && ! has_frontmatter "$path"; then
      MISSING_PROJECT_DOCS+=("$path")
      continue
    fi

    if has_frontmatter "$path"; then
      check_project_doc_quality "$path"
    fi
  done <<EOF
$(jq -r '.project_docs[] | [.path, (.required // false)] | @tsv' "$CONFIG_PATH")
EOF
}

check_feature_dir() {
  local feature_dir="$1"
  local feature_name
  local overview_file="$feature_dir/overview.md"
  local change_types
  local doc
  local doc_path
  local change_type
  local expected_docs=()
  local missing_docs=()
  local missing_summary=""

  feature_name="$(basename "$feature_dir")"

  if ! has_frontmatter "$overview_file"; then
    INVALID_FEATURES+=("$feature_name|overview.md")
    return
  fi

  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    if [ "${#expected_docs[@]}" -eq 0 ] || append_unique "$doc" "${expected_docs[@]}"; then
      expected_docs+=("$doc")
    fi
  done <<EOF
$(jq -r '.feature_spec.required_docs[]?' "$CONFIG_PATH")
EOF

  change_types="$(extract_frontmatter_value "$overview_file" "change_types")"
  for change_type in $(printf '%s' "$change_types" | tr ',' '\n' | sed 's/ //g'); do
    [ -n "$change_type" ] || continue
    while IFS= read -r doc; do
      [ -n "$doc" ] || continue
      if [ "${#expected_docs[@]}" -eq 0 ] || append_unique "$doc" "${expected_docs[@]}"; then
        expected_docs+=("$doc")
      fi
    done <<EOF
$(jq -r --arg change_type "$change_type" '.feature_spec.change_type_docs[$change_type][]?' "$CONFIG_PATH")
EOF
  done

  for doc in "${expected_docs[@]}"; do
    doc_path="$feature_dir/$doc"
    if ! has_frontmatter "$doc_path"; then
      missing_docs+=("$doc")
    else
      check_feature_doc_quality "$feature_name" "$doc_path" "$doc"
    fi
  done

  if [ "${#missing_docs[@]}" -gt 0 ]; then
    missing_summary="$(printf '%s,' "${missing_docs[@]}")"
    missing_summary="${missing_summary%,}"
    INVALID_FEATURES+=("$feature_name|$missing_summary")
  fi
}

emit_project_quality_issues_json() {
  local first=1
  local record
  local path
  local rest
  local kind
  local detail

  printf '['
  for record in "${PROJECT_QUALITY_ISSUES[@]-}"; do
    [ -n "$record" ] || continue
    path="${record%%|*}"
    rest="${record#*|}"
    kind="${rest%%|*}"
    detail="${rest#*|}"
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"path":"%s","kind":"%s","detail":"%s"}' \
      "$(json_escape "$path")" \
      "$(json_escape "$kind")" \
      "$(json_escape "$detail")"
  done
  printf ']'
}

emit_feature_quality_issues_json() {
  local first=1
  local record
  local feature
  local rest
  local path
  local kind
  local detail

  printf '['
  for record in "${FEATURE_QUALITY_ISSUES[@]-}"; do
    [ -n "$record" ] || continue
    feature="${record%%|*}"
    rest="${record#*|}"
    path="${rest%%|*}"
    rest="${rest#*|}"
    kind="${rest%%|*}"
    detail="${rest#*|}"
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"feature":"%s","path":"%s","kind":"%s","detail":"%s"}' \
      "$(json_escape "$feature")" \
      "$(json_escape "$path")" \
      "$(json_escape "$kind")" \
      "$(json_escape "$detail")"
  done
  printf ']'
}

emit_json() {
  local status="$1"
  local invalid_count="$2"
  local checked_features="$3"
  local project_quality_count="${#PROJECT_QUALITY_ISSUES[@]}"
  local feature_quality_count="${#FEATURE_QUALITY_ISSUES[@]}"
  local total_quality_count=$((project_quality_count + feature_quality_count))
  local first=1
  local record
  local feature
  local missing

  printf '{'
  printf '"status":"%s",' "$(json_escape "$status")"
  printf '"strict_mode":%s,' "$( [ "$STRICT_MODE" -eq 1 ] && printf 'true' || printf 'false' )"
  printf '"template_pack":{"name":"%s","version":"%s","profile":"%s","language":"%s"},' \
    "$(json_escape "$(jq -r '.template_pack.name // ""' "$CONFIG_PATH")")" \
    "$(json_escape "$(jq -r '.template_pack.version // ""' "$CONFIG_PATH")")" \
    "$(json_escape "$(jq -r '.template_pack.profile // ""' "$CONFIG_PATH")")" \
    "$(json_escape "$(jq -r '.template_pack.language // ""' "$CONFIG_PATH")")"
  printf '"project":{"missing_required_docs_count":%s,"missing_required_docs":' "${#MISSING_PROJECT_DOCS[@]}"
  append_safe_array_json "MISSING_PROJECT_DOCS"
  printf ',"quality_issue_count":%s,"quality_issues":' "$project_quality_count"
  emit_project_quality_issues_json
  printf '},'
  printf '"features":{"checked":%s,"invalid_count":%s,"invalid_features":[' "$checked_features" "$invalid_count"
  if [ "${#INVALID_FEATURES[@]}" -gt 0 ]; then
    for record in "${INVALID_FEATURES[@]-}"; do
      [ -n "$record" ] || continue
      feature="${record%%|*}"
      missing="${record#*|}"
      if [ "$first" -eq 0 ]; then
        printf ','
      fi
      first=0
      printf '{"feature":"%s","missing_docs":' "$(json_escape "$feature")"
      if [ "$missing" = "$record" ]; then
        append_array_json
      else
        append_array_json $(printf '%s' "$missing" | tr ',' ' ')
      fi
      printf '}'
    done
  fi
  printf '],"quality_issue_count":%s,"quality_issues":' "$feature_quality_count"
  emit_feature_quality_issues_json
  printf '},'
  printf '"quality":{"total_issue_count":%s}}\n' "$total_quality_count"
}

emit_text() {
  local status="$1"
  local invalid_count="$2"
  local checked_features="$3"
  local total_quality_count=$(( ${#PROJECT_QUALITY_ISSUES[@]} + ${#FEATURE_QUALITY_ISSUES[@]} ))

  printf 'Spec validation %s. Missing project docs: %s. Invalid feature dirs: %s/%s. Quality issues: %s. Strict mode: %s.\n' \
    "$status" "${#MISSING_PROJECT_DOCS[@]}" "$invalid_count" "$checked_features" "$total_quality_count" \
    "$( [ "$STRICT_MODE" -eq 1 ] && printf 'true' || printf 'false' )"
}

main() {
  local feature_base_dir
  local feature_dir
  local checked_features=0
  local invalid_count=0
  local total_quality_count=0
  local status="passed"

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  determine_strict_mode
  check_project_docs

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"
  if [ -d "$feature_base_dir" ]; then
    while IFS= read -r feature_dir; do
      [ -n "$feature_dir" ] || continue
      checked_features=$((checked_features + 1))
      check_feature_dir "$feature_dir"
    done <<EOF
$(find "$feature_base_dir" -mindepth 1 -maxdepth 1 -type d | sort)
EOF
  fi

  invalid_count="${#INVALID_FEATURES[@]}"
  total_quality_count=$(( ${#PROJECT_QUALITY_ISSUES[@]} + ${#FEATURE_QUALITY_ISSUES[@]} ))
  if [ "${#MISSING_PROJECT_DOCS[@]}" -gt 0 ] || [ "$invalid_count" -gt 0 ]; then
    status="invalid"
  fi
  if [ "$STRICT_MODE" -eq 1 ] && [ "$total_quality_count" -gt 0 ]; then
    status="invalid"
  fi

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json "$status" "$invalid_count" "$checked_features"
  else
    emit_text "$status" "$invalid_count" "$checked_features"
  fi

  if [ "$status" = "passed" ]; then
    exit 0
  fi
  exit 1
}

main "$@"
