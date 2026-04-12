#!/bin/bash

set -euo pipefail

CONFIG_PATH=".harness/spec-policy.json"
OUTPUT_JSON=0
STRICT_MODE=-1
WRITE_FIX_PLAN=""
AUTOFIX_SAFE=0
JAVA_DOC_SCAN_PATH=".harness/runtime/java-doc-scan.json"

MISSING_PROJECT_DOCS=()
INVALID_FEATURES=()
PROJECT_QUALITY_ISSUES=()
FEATURE_QUALITY_ISSUES=()
AUTOFIXED_FILES=()

PROJECT_NAME="$(basename "$(pwd)")"
OWNER="team"
TODAY="$(date +%F)"
STACK="unknown"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"
USER_TEMPLATE_ROOT="${HARNESS_TEMPLATE_ROOT:-}"
TEMPLATE_PACK_NAME="${TEMPLATE_PACK_NAME_DEFAULT:-harness-engineering-default}"
TEMPLATE_VERSION="${TEMPLATE_VERSION_DEFAULT:-1.1.0}"
TEMPLATE_LANGUAGE="${TEMPLATE_LANGUAGE_DEFAULT:-zh-CN}"
TEMPLATE_PROFILE="generic"
PROFILE_DESCRIPTION=""

# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"
# shellcheck source=scripts/lib/template-profile.sh
. "$SCRIPT_DIR/lib/template-profile.sh"
# shellcheck source=scripts/lib/doc-paths.sh
. "$SCRIPT_DIR/lib/doc-paths.sh"

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
Usage: validate-spec.sh [--config <path>] [--json] [--strict] [--write-fix-plan <path>] [--autofix-safe]
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
      --write-fix-plan)
        WRITE_FIX_PLAN="${2:-}"
        shift 2
        ;;
      --autofix-safe)
        AUTOFIX_SAFE=1
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

mark_autofixed() {
  local path="$1"
  if [ "${#AUTOFIXED_FILES[@]}" -eq 0 ] || append_unique "$path" "${AUTOFIXED_FILES[@]}"; then
    AUTOFIXED_FILES+=("$path")
  fi
}

reset_results() {
  MISSING_PROJECT_DOCS=()
  INVALID_FEATURES=()
  PROJECT_QUALITY_ISSUES=()
  FEATURE_QUALITY_ISSUES=()
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

detect_stack() {
  if [ -f package.json ]; then
    STACK="node"
  elif [ -f pom.xml ]; then
    STACK="java-maven"
  elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
    STACK="java-gradle"
  elif [ -f pyproject.toml ] || [ -f setup.py ]; then
    STACK="python"
  elif [ -f go.mod ]; then
    STACK="go"
  elif [ -f Cargo.toml ]; then
    STACK="rust"
  else
    STACK="unknown"
  fi
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

load_template_pack_metadata() {
  TEMPLATE_PACK_NAME="$(jq -r '.template_pack.name // "'"$TEMPLATE_PACK_NAME"'"' "$CONFIG_PATH")"
  TEMPLATE_VERSION="$(jq -r '.template_pack.version // "'"$TEMPLATE_VERSION"'"' "$CONFIG_PATH")"
  TEMPLATE_LANGUAGE="$(jq -r '.template_pack.language // "'"$TEMPLATE_LANGUAGE"'"' "$CONFIG_PATH")"
  TEMPLATE_PROFILE="$(jq -r '.template_pack.profile // "'"$TEMPLATE_PROFILE"'"' "$CONFIG_PATH")"
  PROFILE_DESCRIPTION="$(describe_template_profile "$TEMPLATE_PROFILE")"
}

java_doc_coverage_enabled() {
  case "$TEMPLATE_PROFILE" in
    java-backend-service|java-batch-job|java-adapter)
      return 0
      ;;
  esac

  [ "$STACK" = "java-maven" ] || [ "$STACK" = "java-gradle" ]
}

configured_project_doc_path_by_id() {
  local doc_id="$1"
  jq -r --arg id "$doc_id" '.project_docs[]? | select(.id == $id) | .path // empty' "$CONFIG_PATH" | head -n 1
}

project_doc_reference_path_by_id() {
  local doc_id="$1"
  local path=""

  path="$(configured_project_doc_path_by_id "$doc_id" || true)"
  if [ -n "$path" ] && [ "$path" != "null" ]; then
    first_existing_project_doc_by_path "$path" || printf '%s' "$path"
    return 0
  fi

  first_existing_project_doc "$doc_id" || project_doc_path "$doc_id" 2>/dev/null || true
}

docs_contain_symbol() {
  local symbol="$1"
  shift
  local path

  for path in "$@"; do
    [ -f "$path" ] || continue
    if grep -Fq "$symbol" "$path" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

record_missing_java_scan_symbols() {
  local issue_kind="$1"
  local issue_path="$2"
  local jq_query="$3"
  shift 3
  local docs=("$@")
  local symbol=""
  local seen=()

  while IFS= read -r symbol; do
    [ -n "$symbol" ] || continue
    if [ "${#seen[@]}" -gt 0 ] && ! append_unique "$symbol" "${seen[@]}"; then
      continue
    fi
    seen+=("$symbol")

    if ! docs_contain_symbol "$symbol" "${docs[@]-}"; then
      record_quality_issue "project" "" "${issue_path:-$JAVA_DOC_SCAN_PATH}" "$issue_kind" "$symbol"
    fi
  done <<EOF
$(jq -r "$jq_query" "$JAVA_DOC_SCAN_PATH" 2>/dev/null)
EOF
}

check_java_doc_scan_coverage() {
  local architecture_path=""
  local design_path=""
  local api_path=""

  if ! java_doc_coverage_enabled; then
    return 0
  fi

  if [ ! -f "$JAVA_DOC_SCAN_PATH" ]; then
    record_quality_issue "project" "" "$JAVA_DOC_SCAN_PATH" "missing_java_doc_scan" "$JAVA_DOC_SCAN_PATH"
    return 0
  fi

  if ! jq -e . "$JAVA_DOC_SCAN_PATH" >/dev/null 2>&1; then
    record_quality_issue "project" "" "$JAVA_DOC_SCAN_PATH" "invalid_java_doc_scan" "$JAVA_DOC_SCAN_PATH"
    return 0
  fi

  architecture_path="$(project_doc_reference_path_by_id architecture)"
  design_path="$(project_doc_reference_path_by_id design)"
  api_path="$(project_doc_reference_path_by_id api-spec)"

  record_missing_java_scan_symbols \
    "java_scan_missing_module_reference" \
    "${architecture_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.module_paths[]? | select(. != "." and . != "")' \
    "$architecture_path"

  record_missing_java_scan_symbols \
    "java_scan_missing_package_reference" \
    "${architecture_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.package_roots[]? | select(. != "")' \
    "$architecture_path"

  record_missing_java_scan_symbols \
    "java_scan_missing_entrypoint_reference" \
    "${architecture_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.entrypoints[]?.name' \
    "$architecture_path" "$design_path"

  record_missing_java_scan_symbols \
    "java_scan_missing_api_entry_reference" \
    "${api_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.controllers[]?.name, .inventory.facades[]?.name, .inventory.listeners[]?.name, .inventory.jobs[]?.name' \
    "$api_path" "$architecture_path" "$design_path"

  record_missing_java_scan_symbols \
    "java_scan_missing_outbound_reference" \
    "${api_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.clients[]?.name' \
    "$api_path" "$architecture_path" "$design_path"

  record_missing_java_scan_symbols \
    "java_scan_missing_service_reference" \
    "${design_path:-$JAVA_DOC_SCAN_PATH}" \
    '.inventory.application_services[]?.name, .inventory.domain_services[]?.name' \
    "$design_path" "$architecture_path"
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
  local config_path="$2"
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
$(jq -r --arg path "$config_path" '.project_docs[] | select(.path == $path) | .required_frontmatter[]?' "$CONFIG_PATH")
EOF

  while IFS= read -r section; do
    [ -n "$section" ] || continue
    if ! grep -Fq "$section" "$path" 2>/dev/null; then
      record_quality_issue "project" "" "$path" "missing_section" "$section"
    fi
  done <<EOF
$(jq -r --arg path "$config_path" '.project_docs[] | select(.path == $path) | .required_sections[]?' "$CONFIG_PATH")
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
  local actual_path
  local required

  while IFS=$'\t' read -r path required; do
    [ -n "$path" ] || continue
    actual_path="$(first_existing_project_doc_by_path "$path" || true)"
    if [ "$required" = "true" ] && ! has_frontmatter "$actual_path"; then
      MISSING_PROJECT_DOCS+=("$path")
      continue
    fi

    if has_frontmatter "$actual_path"; then
      check_project_doc_quality "$actual_path" "$path"
    fi
  done <<EOF
$(jq -r '.project_docs[] | [.path, (.required // false)] | @tsv' "$CONFIG_PATH")
EOF

  check_java_doc_scan_coverage
}

check_feature_dir() {
  local feature_dir="$1"
  local feature_name
  local overview_file=""
  local overview_required_doc=""
  local change_types
  local doc
  local doc_path
  local change_type
  local expected_docs=()
  local missing_docs=()
  local missing_summary=""

  feature_name="$(basename "$feature_dir")"
  overview_file="$(first_existing_feature_doc "$feature_dir" overview || true)"
  overview_required_doc="$(jq -r '.feature_spec.required_docs[0] // "功能概览.md"' "$CONFIG_PATH")"

  if ! has_frontmatter "$overview_file"; then
    INVALID_FEATURES+=("$feature_name|$overview_required_doc")
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
    doc_path="$(first_existing_feature_doc_by_name "$feature_dir" "$doc" || true)"
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

evaluate_repo() {
  local feature_base_dir
  local feature_dir
  CHECKED_FEATURES=0

  reset_results
  check_project_docs

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"
  if [ -d "$feature_base_dir" ]; then
    while IFS= read -r feature_dir; do
      [ -n "$feature_dir" ] || continue
      CHECKED_FEATURES=$((CHECKED_FEATURES + 1))
      check_feature_dir "$feature_dir"
    done <<EOF
$(find "$feature_base_dir" -mindepth 1 -maxdepth 1 -type d | sort)
EOF
  fi
}

determine_status() {
  local invalid_count="$1"
  local total_quality_count="$2"
  local status="passed"

  if [ "${#MISSING_PROJECT_DOCS[@]}" -gt 0 ] || [ "$invalid_count" -gt 0 ]; then
    status="invalid"
  fi
  if [ "$STRICT_MODE" -eq 1 ] && [ "$total_quality_count" -gt 0 ]; then
    status="invalid"
  fi
  printf '%s' "$status"
}

set_frontmatter_field() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  tmp="$(mktemp)"
  awk -v target="$key" -v value="$value" '
    BEGIN { in_frontmatter=0; inserted=0 }
    NR == 1 && $0 !~ /^---$/ {
      print "---"
      print target ": " value
      print "---"
      print $0
      next
    }
    /^---$/ {
      if (in_frontmatter == 0) {
        in_frontmatter=1
        print
        next
      }
      if (inserted == 0) {
        print target ": " value
        inserted=1
      }
      print
      in_frontmatter=2
      next
    }
    in_frontmatter == 1 && $0 ~ ("^" target ":") {
      if (inserted == 0) {
        print target ": " value
        inserted=1
      }
      next
    }
    { print }
    END {
      if (NR == 0) {
        print "---"
        print target ": " value
        print "---"
      }
    }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  mark_autofixed "$file"
}

ensure_section() {
  local file="$1"
  local section="$2"
  if grep -Fq "$section" "$file" 2>/dev/null; then
    return
  fi
  printf '\n%s\n\n待补充。\n' "$section" >> "$file"
  mark_autofixed "$file"
}

render_project_doc() {
  local path="$1"
  local logical_template=""
  local template_file=""
  local content=""

  if ! logical_template="$(project_template_file_for_path "$path")"; then
    return 1
  fi

  if ! template_file="$(resolve_template_file "$logical_template")"; then
    return 1
  fi

  content="$(cat "$template_file")"
  content="${content//'{{PROJECT_NAME}}'/$PROJECT_NAME}"
  content="${content//'{{DESCRIPTION}}'/Autofixed by validate-spec.sh.}"
  content="${content//'{{OWNER}}'/$OWNER}"
  content="${content//'{{DATE}}'/$TODAY}"
  content="${content//'{{TEST_COMMAND}}'/$(test_command)}"
  content="${content//'{{TEMPLATE_PACK_NAME}}'/$TEMPLATE_PACK_NAME}"
  content="${content//'{{TEMPLATE_VERSION}}'/$TEMPLATE_VERSION}"
  content="${content//'{{TEMPLATE_PROFILE}}'/$TEMPLATE_PROFILE}"
  content="${content//'{{TEMPLATE_LANGUAGE}}'/$TEMPLATE_LANGUAGE}"
  content="${content//'{{PROFILE_DESCRIPTION}}'/$PROFILE_DESCRIPTION}"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  mark_autofixed "$path"
}

render_feature_doc() {
  local feature_dir="$1"
  local doc_name="$2"
  local target="$feature_dir/$doc_name"
  local overview_file=""
  local feature_id=""
  local feature_title=""
  local feature_owner=""
  local change_types=""
  local logical_template=""
  local template_file=""
  local content=""

  overview_file="$(first_existing_feature_doc "$feature_dir" overview || true)"
  feature_id="$(extract_frontmatter_value "$overview_file" "id")"
  feature_title="$(extract_frontmatter_value "$overview_file" "title")"
  feature_owner="$(extract_frontmatter_value "$overview_file" "owner")"
  change_types="$(extract_frontmatter_value "$overview_file" "change_types")"

  if [ -z "$feature_id" ]; then
    feature_id="$(basename "$feature_dir" | cut -d- -f1)"
  fi
  if [ -z "$feature_title" ]; then
    feature_title="$(basename "$feature_dir")"
  fi
  if [ -z "$feature_owner" ]; then
    feature_owner="$OWNER"
  fi

  if ! logical_template="$(feature_template_file_for_doc "$doc_name")"; then
    return 1
  fi

  if ! template_file="$(resolve_template_file "$logical_template")"; then
    return 1
  fi

  content="$(cat "$template_file")"
  content="${content//'{{FEATURE_ID}}'/$feature_id}"
  content="${content//'{{FEATURE_TITLE}}'/$feature_title}"
  content="${content//'{{OWNER}}'/$feature_owner}"
  content="${content//'{{CHANGE_TYPES}}'/$change_types}"
  content="${content//'{{DATE}}'/$TODAY}"
  content="${content//'{{TEMPLATE_PACK_NAME}}'/$TEMPLATE_PACK_NAME}"
  content="${content//'{{TEMPLATE_VERSION}}'/$TEMPLATE_VERSION}"
  content="${content//'{{TEMPLATE_PROFILE}}'/$TEMPLATE_PROFILE}"
  content="${content//'{{TEMPLATE_LANGUAGE}}'/$TEMPLATE_LANGUAGE}"
  content="${content//'{{PROFILE_DESCRIPTION}}'/$PROFILE_DESCRIPTION}"
  printf '%s\n' "$content" > "$target"
  mark_autofixed "$target"
}

autofix_missing_project_docs() {
  local path
  for path in "${MISSING_PROJECT_DOCS[@]-}"; do
    [ -n "$path" ] || continue
    render_project_doc "$path" || true
  done
}

autofix_missing_feature_docs() {
  local record
  local feature
  local missing
  local doc
  local feature_base_dir
  local feature_dir

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"
  for record in "${INVALID_FEATURES[@]-}"; do
    [ -n "$record" ] || continue
    feature="${record%%|*}"
    missing="${record#*|}"
    feature_dir="$feature_base_dir/$feature"
    [ -d "$feature_dir" ] || continue
    for doc in $(printf '%s' "$missing" | tr ',' ' '); do
      [ -n "$doc" ] || continue
      render_feature_doc "$feature_dir" "$doc" || true
    done
  done
}

expected_value_for_field() {
  case "$1" in
    template_version) printf '%s' "$TEMPLATE_VERSION" ;;
    template_profile) printf '%s' "$TEMPLATE_PROFILE" ;;
    template_language) printf '%s' "$TEMPLATE_LANGUAGE" ;;
    last_updated) printf '%s' "$TODAY" ;;
    owner) printf '%s' "$OWNER" ;;
    *) printf '' ;;
  esac
}

autofix_quality_issues() {
  local record
  local path
  local rest
  local kind
  local detail
  local feature
  local field
  local value
  local expected

  for record in "${PROJECT_QUALITY_ISSUES[@]-}"; do
    [ -n "$record" ] || continue
    path="${record%%|*}"
    rest="${record#*|}"
    kind="${rest%%|*}"
    detail="${rest#*|}"
    case "$kind" in
      missing_frontmatter)
        value="$(expected_value_for_field "$detail")"
        [ -n "$value" ] && set_frontmatter_field "$path" "$detail" "$value"
        ;;
      missing_section)
        ensure_section "$path" "$detail"
        ;;
      frontmatter_mismatch)
        field="${detail%%=*}"
        expected="${detail##*expected=}"
        [ -n "$field" ] && [ -n "$expected" ] && set_frontmatter_field "$path" "$field" "$expected"
        ;;
    esac
  done

  for record in "${FEATURE_QUALITY_ISSUES[@]-}"; do
    [ -n "$record" ] || continue
    feature="${record%%|*}"
    rest="${record#*|}"
    path="${rest%%|*}"
    rest="${rest#*|}"
    kind="${rest%%|*}"
    detail="${rest#*|}"
    case "$kind" in
      missing_frontmatter)
        value="$(expected_value_for_field "$detail")"
        [ -n "$value" ] && set_frontmatter_field "$path" "$detail" "$value"
        ;;
      missing_section)
        ensure_section "$path" "$detail"
        ;;
      frontmatter_mismatch)
        field="${detail%%=*}"
        expected="${detail##*expected=}"
        [ -n "$field" ] && [ -n "$expected" ] && set_frontmatter_field "$path" "$field" "$expected"
        ;;
    esac
  done
}

perform_autofix() {
  autofix_missing_project_docs
  autofix_missing_feature_docs
  autofix_quality_issues
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

emit_fix_actions_json() {
  local first=1
  local path
  local record
  local feature
  local missing
  local doc
  local feature_base_dir

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"

  printf '['
  for path in "${MISSING_PROJECT_DOCS[@]-}"; do
    [ -n "$path" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"action":"create_project_doc","path":"%s"}' "$(json_escape "$path")"
  done

  for record in "${INVALID_FEATURES[@]-}"; do
    [ -n "$record" ] || continue
    feature="${record%%|*}"
    missing="${record#*|}"
    for doc in $(printf '%s' "$missing" | tr ',' ' '); do
      [ -n "$doc" ] || continue
      if [ "$first" -eq 0 ]; then
        printf ','
      fi
      first=0
      printf '{"action":"create_feature_doc","feature":"%s","path":"%s"}' \
        "$(json_escape "$feature")" \
        "$(json_escape "$feature_base_dir/$feature/$doc")"
    done
  done
  printf ']'
}

write_fix_plan() {
  local output_path="$1"
  [ -n "$output_path" ] || return 0

  mkdir -p "$(dirname "$output_path")"
  printf '{\n' > "$output_path"
  printf '  "status": "planned",\n' >> "$output_path"
  printf '  "config_path": "%s",\n' "$(json_escape "$CONFIG_PATH")" >> "$output_path"
  printf '  "actions": ' >> "$output_path"
  emit_fix_actions_json >> "$output_path"
  printf '\n}\n' >> "$output_path"
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
  printf '"autofix_count":%s,' "${#AUTOFIXED_FILES[@]}"
  printf '"autofixed_files":'
  append_safe_array_json "AUTOFIXED_FILES"
  if [ -n "$WRITE_FIX_PLAN" ]; then
    printf ',"fix_plan_path":"%s"' "$(json_escape "$WRITE_FIX_PLAN")"
  fi
  printf ','
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
      append_array_json $(printf '%s' "$missing" | tr ',' ' ')
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

  printf 'Spec validation %s. Missing project docs: %s. Invalid feature dirs: %s/%s. Quality issues: %s. Strict mode: %s. Autofixed files: %s.\n' \
    "$status" "${#MISSING_PROJECT_DOCS[@]}" "$invalid_count" "$checked_features" "$total_quality_count" \
    "$( [ "$STRICT_MODE" -eq 1 ] && printf 'true' || printf 'false' )" "${#AUTOFIXED_FILES[@]}"
}

main() {
  local invalid_count=0
  local total_quality_count=0
  local status="passed"
  local initial_status="passed"

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  detect_stack
  load_template_pack_metadata
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "$USER_TEMPLATE_ROOT" ".harness/templates"
  determine_strict_mode
  evaluate_repo

  invalid_count="${#INVALID_FEATURES[@]}"
  total_quality_count=$(( ${#PROJECT_QUALITY_ISSUES[@]} + ${#FEATURE_QUALITY_ISSUES[@]} ))
  initial_status="$(determine_status "$invalid_count" "$total_quality_count")"

  if [ -n "$WRITE_FIX_PLAN" ] && [ "$initial_status" != "passed" ]; then
    write_fix_plan "$WRITE_FIX_PLAN"
  fi

  if [ "$AUTOFIX_SAFE" -eq 1 ] && [ "$initial_status" != "passed" ]; then
    perform_autofix
    evaluate_repo
    invalid_count="${#INVALID_FEATURES[@]}"
    total_quality_count=$(( ${#PROJECT_QUALITY_ISSUES[@]} + ${#FEATURE_QUALITY_ISSUES[@]} ))
  fi

  status="$(determine_status "$invalid_count" "$total_quality_count")"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json "$status" "$invalid_count" "$CHECKED_FEATURES"
  else
    emit_text "$status" "$invalid_count" "$CHECKED_FEATURES"
  fi

  if [ "$status" = "passed" ]; then
    exit 0
  fi
  exit 1
}

main "$@"
