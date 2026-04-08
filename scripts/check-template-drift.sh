#!/bin/bash

set -euo pipefail

CONFIG_PATH=".harness/spec-policy.json"
OUTPUT_JSON=0
USER_TEMPLATE_ROOT="${HARNESS_TEMPLATE_ROOT:-}"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"

EXPECTED_TEMPLATE_VERSION=""
EXPECTED_TEMPLATE_PROFILE=""
EXPECTED_TEMPLATE_LANGUAGE=""

DOC_DRIFTS=()
DOC_MISSING_METADATA=()
OVERRIDE_ROOTS=()
REDUNDANT_OVERRIDES=()
CUSTOM_OVERRIDES=()
ORPHAN_OVERRIDES=()

DOCS_CHECKED=0
OVERRIDES_CHECKED=0

# shellcheck source=scripts/lib/template-resolver.sh
. "$SCRIPT_DIR/lib/template-resolver.sh"

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

usage() {
  cat <<'EOF'
Usage: check-template-drift.sh [--config <path>] [--json] [--template-root <path>]
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
      --template-root)
        USER_TEMPLATE_ROOT="${2:-}"
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
    printf '{"status":"error","error":"jq is required for check-template-drift.sh"}\n'
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

record_doc_drift() {
  local scope="$1"
  local feature="$2"
  local path="$3"
  local field="$4"
  local actual="$5"
  local expected="$6"
  DOC_DRIFTS+=("$scope|$feature|$path|$field|$actual|$expected")
}

record_missing_metadata() {
  local scope="$1"
  local feature="$2"
  local path="$3"
  local field="$4"
  DOC_MISSING_METADATA+=("$scope|$feature|$path|$field")
}

add_override_root() {
  local root="$1"
  [ -n "$root" ] || return 0
  [ -d "$root" ] || return 0
  if [ "${#OVERRIDE_ROOTS[@]}" -eq 0 ] || append_unique "$root" "${OVERRIDE_ROOTS[@]}"; then
    OVERRIDE_ROOTS+=("$root")
  fi
}

check_doc_metadata_field() {
  local scope="$1"
  local feature="$2"
  local path="$3"
  local field="$4"
  local expected="$5"
  local actual

  actual="$(extract_frontmatter_value "$path" "$field")"
  if [ -z "$actual" ]; then
    record_missing_metadata "$scope" "$feature" "$path" "$field"
    return
  fi

  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then
    record_doc_drift "$scope" "$feature" "$path" "$field" "$actual" "$expected"
  fi
}

check_doc_metadata() {
  local scope="$1"
  local feature="$2"
  local path="$3"

  if ! has_frontmatter "$path"; then
    return
  fi

  DOCS_CHECKED=$((DOCS_CHECKED + 1))
  check_doc_metadata_field "$scope" "$feature" "$path" "template_version" "$EXPECTED_TEMPLATE_VERSION"
  check_doc_metadata_field "$scope" "$feature" "$path" "template_profile" "$EXPECTED_TEMPLATE_PROFILE"
  check_doc_metadata_field "$scope" "$feature" "$path" "template_language" "$EXPECTED_TEMPLATE_LANGUAGE"
}

check_project_docs() {
  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -f "$path" ]; then
      check_doc_metadata "project" "" "$path"
    fi
  done <<EOF
$(jq -r '.project_docs[]?.path // empty' "$CONFIG_PATH")
EOF
}

check_feature_docs() {
  local feature_base_dir
  local doc_file
  local feature_name

  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"
  [ -d "$feature_base_dir" ] || return

  while IFS= read -r doc_file; do
    [ -n "$doc_file" ] || continue
    feature_name="$(basename "$(dirname "$doc_file")")"
    check_doc_metadata "feature" "$feature_name" "$doc_file"
  done <<EOF
$(find "$feature_base_dir" -type f -name '*.md' | sort)
EOF
}

check_override_root() {
  local root="$1"
  local override_file
  local relative_path
  local default_file

  while IFS= read -r override_file; do
    [ -n "$override_file" ] || continue
    OVERRIDES_CHECKED=$((OVERRIDES_CHECKED + 1))
    relative_path="${override_file#"$root"/}"

    if ! default_file="$(default_template_file "$relative_path")"; then
      ORPHAN_OVERRIDES+=("$override_file")
      continue
    fi

    if cmp -s "$override_file" "$default_file"; then
      REDUNDANT_OVERRIDES+=("$override_file")
    else
      CUSTOM_OVERRIDES+=("$override_file")
    fi
  done <<EOF
$(find "$root" -type f | sort)
EOF
}

emit_doc_drift_json() {
  local first=1
  local record
  local scope
  local feature
  local path
  local field
  local actual
  local expected

  printf '['
  for record in "${DOC_DRIFTS[@]}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r scope feature path field actual expected <<EOF
$record
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{'
    printf '"scope":"%s",' "$(json_escape "$scope")"
    printf '"feature":"%s",' "$(json_escape "$feature")"
    printf '"path":"%s",' "$(json_escape "$path")"
    printf '"field":"%s",' "$(json_escape "$field")"
    printf '"actual":"%s",' "$(json_escape "$actual")"
    printf '"expected":"%s"' "$(json_escape "$expected")"
    printf '}'
  done
  printf ']'
}

emit_missing_metadata_json() {
  local first=1
  local record
  local scope
  local feature
  local path
  local field

  printf '['
  for record in "${DOC_MISSING_METADATA[@]}"; do
    [ -n "$record" ] || continue
    IFS='|' read -r scope feature path field <<EOF
$record
EOF
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{'
    printf '"scope":"%s",' "$(json_escape "$scope")"
    printf '"feature":"%s",' "$(json_escape "$feature")"
    printf '"path":"%s",' "$(json_escape "$path")"
    printf '"field":"%s"' "$(json_escape "$field")"
    printf '}'
  done
  printf ']'
}

emit_json_report() {
  local issue_count=0
  issue_count=$(( ${#DOC_DRIFTS[@]} + ${#DOC_MISSING_METADATA[@]} + ${#REDUNDANT_OVERRIDES[@]} + ${#ORPHAN_OVERRIDES[@]} ))

  printf '{'
  if [ "$issue_count" -gt 0 ]; then
    printf '"status":"drifted",'
  else
    printf '"status":"passed",'
  fi
  printf '"config_path":"%s",' "$(json_escape "$CONFIG_PATH")"
  printf '"template_pack":{'
  printf '"version":"%s",' "$(json_escape "$EXPECTED_TEMPLATE_VERSION")"
  printf '"profile":"%s",' "$(json_escape "$EXPECTED_TEMPLATE_PROFILE")"
  printf '"language":"%s"' "$(json_escape "$EXPECTED_TEMPLATE_LANGUAGE")"
  printf '},'
  printf '"docs":{'
  printf '"checked_count":%s,' "$DOCS_CHECKED"
  printf '"drifted_count":%s,' "${#DOC_DRIFTS[@]}"
  printf '"missing_metadata_count":%s,' "${#DOC_MISSING_METADATA[@]}"
  printf '"drifted":'
  emit_doc_drift_json
  printf ','
  printf '"missing_metadata":'
  emit_missing_metadata_json
  printf '},'
  printf '"overrides":{'
  printf '"roots":'
  append_array_json "${OVERRIDE_ROOTS[@]}"
  printf ','
  printf '"checked_count":%s,' "$OVERRIDES_CHECKED"
  printf '"custom_count":%s,' "${#CUSTOM_OVERRIDES[@]}"
  printf '"redundant_count":%s,' "${#REDUNDANT_OVERRIDES[@]}"
  printf '"orphan_count":%s,' "${#ORPHAN_OVERRIDES[@]}"
  printf '"custom_overrides":'
  append_array_json "${CUSTOM_OVERRIDES[@]}"
  printf ','
  printf '"redundant_overrides":'
  append_array_json "${REDUNDANT_OVERRIDES[@]}"
  printf ','
  printf '"orphan_overrides":'
  append_array_json "${ORPHAN_OVERRIDES[@]}"
  printf '},'
  printf '"summary":{"issue_count":%s}' "$issue_count"
  printf '}\n'
}

emit_text_report() {
  local issue_count=0
  issue_count=$(( ${#DOC_DRIFTS[@]} + ${#DOC_MISSING_METADATA[@]} + ${#REDUNDANT_OVERRIDES[@]} + ${#ORPHAN_OVERRIDES[@]} ))

  printf 'Template drift audit\n'
  printf 'Config: %s\n' "$CONFIG_PATH"
  printf 'Template pack: version=%s profile=%s language=%s\n' \
    "$EXPECTED_TEMPLATE_VERSION" "$EXPECTED_TEMPLATE_PROFILE" "$EXPECTED_TEMPLATE_LANGUAGE"
  printf 'Checked docs: %s\n' "$DOCS_CHECKED"
  printf 'Checked overrides: %s\n' "$OVERRIDES_CHECKED"
  printf 'Doc drift issues: %s\n' "${#DOC_DRIFTS[@]}"
  printf 'Missing metadata: %s\n' "${#DOC_MISSING_METADATA[@]}"
  printf 'Redundant overrides: %s\n' "${#REDUNDANT_OVERRIDES[@]}"
  printf 'Orphan overrides: %s\n' "${#ORPHAN_OVERRIDES[@]}"
  printf 'Custom overrides: %s\n' "${#CUSTOM_OVERRIDES[@]}"

  if [ "$issue_count" -eq 0 ]; then
    printf 'Status: passed\n'
  else
    printf 'Status: drifted\n'
  fi
}

main() {
  local issue_count=0

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "" ".harness/templates"

  EXPECTED_TEMPLATE_VERSION="$(jq -r '.template_pack.version // empty' "$CONFIG_PATH")"
  EXPECTED_TEMPLATE_PROFILE="$(jq -r '.template_pack.profile // empty' "$CONFIG_PATH")"
  EXPECTED_TEMPLATE_LANGUAGE="$(jq -r '.template_pack.language // empty' "$CONFIG_PATH")"

  check_project_docs
  check_feature_docs

  add_override_root ".harness/templates"
  add_override_root "$USER_TEMPLATE_ROOT"

  if [ "${#OVERRIDE_ROOTS[@]}" -gt 0 ]; then
    local root
    for root in "${OVERRIDE_ROOTS[@]}"; do
      check_override_root "$root"
    done
  fi

  issue_count=$(( ${#DOC_DRIFTS[@]} + ${#DOC_MISSING_METADATA[@]} + ${#REDUNDANT_OVERRIDES[@]} + ${#ORPHAN_OVERRIDES[@]} ))

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report
  else
    emit_text_report
  fi

  if [ "$issue_count" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
