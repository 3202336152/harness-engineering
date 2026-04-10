#!/bin/bash

set -euo pipefail

CONFIG_PATH=".harness/spec-policy.json"
FEATURE_ID=""
TITLE=""
OWNER="team"
CHANGE_TYPES=""
DRY_RUN=0
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SKILL_DIR/assets/templates"
USER_TEMPLATE_ROOT="${HARNESS_TEMPLATE_ROOT:-}"
TODAY="$(date +%F)"
TEMPLATE_PACK_NAME="${TEMPLATE_PACK_NAME_DEFAULT:-harness-engineering-default}"
TEMPLATE_VERSION="${TEMPLATE_VERSION_DEFAULT:-1.1.0}"
TEMPLATE_LANGUAGE="${TEMPLATE_LANGUAGE_DEFAULT:-zh-CN}"
TEMPLATE_PROFILE="generic"
PROFILE_DESCRIPTION=""

CREATED_FILES=()
REQUIRED_DOCS=()
RELATED_PROJECT_DOCS=()
VERIFICATION_CHECKS=()

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

usage() {
  cat <<'EOF'
Usage: new-feature-spec.sh --id <feature-id> --title <title> [--owner <name>] [--change-types <csv>] [--config <path>] [--dry-run]
EOF
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
  while [[ "$slug" == .* ]]; do
    slug="${slug#.}"
  done
  while [[ "$slug" == *. ]]; do
    slug="${slug%.}"
  done

  printf '%s' "$slug"
}

append_required_doc() {
  local doc="$1"
  local existing
  if [ "${#REQUIRED_DOCS[@]}" -gt 0 ]; then
    for existing in "${REQUIRED_DOCS[@]}"; do
      if [ "$existing" = "$doc" ]; then
        return
      fi
    done
  fi
  REQUIRED_DOCS+=("$doc")
}

append_related_project_doc() {
  local doc="$1"
  local existing
  if [ "${#RELATED_PROJECT_DOCS[@]}" -gt 0 ]; then
    for existing in "${RELATED_PROJECT_DOCS[@]}"; do
      if [ "$existing" = "$doc" ]; then
        return
      fi
    done
  fi
  RELATED_PROJECT_DOCS+=("$doc")
}

append_verification_check() {
  local check="$1"
  local existing
  if [ "${#VERIFICATION_CHECKS[@]}" -gt 0 ]; then
    for existing in "${VERIFICATION_CHECKS[@]}"; do
      if [ "$existing" = "$check" ]; then
        return
      fi
    done
  fi
  VERIFICATION_CHECKS+=("$check")
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

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --id)
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
      --config)
        CONFIG_PATH="${2:-$CONFIG_PATH}"
        shift 2
        ;;
      --template-root)
        USER_TEMPLATE_ROOT="${2:-}"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
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

  if [ -z "$FEATURE_ID" ] || [ -z "$TITLE" ]; then
    printf '{"status":"error","error":"Missing required --id or --title"}\n'
    exit 1
  fi
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '{"status":"error","error":"jq is required for new-feature-spec.sh"}\n'
    exit 1
  fi
}

load_required_docs() {
  local change_type

  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    append_required_doc "$doc"
  done <<EOF
$(jq -r '.feature_spec.required_docs[]?' "$CONFIG_PATH")
EOF

  for change_type in $(printf '%s' "$CHANGE_TYPES" | tr ',' '\n' | sed 's/ //g'); do
    [ -n "$change_type" ] || continue
    while IFS= read -r doc; do
      [ -n "$doc" ] || continue
      append_required_doc "$doc"
    done <<EOF
$(jq -r --arg change_type "$change_type" '.feature_spec.change_type_docs[$change_type][]?' "$CONFIG_PATH")
EOF
  done
}

load_related_project_docs() {
  local change_type

  append_related_project_doc "$(project_doc_path architecture)"
  append_related_project_doc "$(project_doc_path requirements)"
  append_related_project_doc "$(project_doc_path testing)"

  for change_type in $(printf '%s' "$CHANGE_TYPES" | tr ',' '\n' | sed 's/ //g'); do
    [ -n "$change_type" ] || continue
    case "$change_type" in
      api) append_related_project_doc "$(project_doc_path api-spec)" ;;
      db) append_related_project_doc "$(project_doc_path design)" ;;
      rollout)
        append_related_project_doc "$(project_doc_path development)"
        append_related_project_doc "$(project_doc_path operations)"
        append_related_project_doc "$(project_doc_path observability)"
        ;;
    esac
  done
}

load_verification_checks() {
  append_verification_check "resolve-task-context"
  append_verification_check "validate-spec"
  append_verification_check "check-doc-impact"

  if [ "$(rollback_required)" = "true" ]; then
    append_verification_check "check-rollback-readiness"
  fi
}

load_template_pack_metadata() {
  TEMPLATE_PACK_NAME="$(jq -r '.template_pack.name // "'"$TEMPLATE_PACK_NAME"'"' "$CONFIG_PATH")"
  TEMPLATE_VERSION="$(jq -r '.template_pack.version // "'"$TEMPLATE_VERSION"'"' "$CONFIG_PATH")"
  TEMPLATE_LANGUAGE="$(jq -r '.template_pack.language // "'"$TEMPLATE_LANGUAGE"'"' "$CONFIG_PATH")"
  TEMPLATE_PROFILE="$(jq -r '.template_pack.profile // "'"$TEMPLATE_PROFILE"'"' "$CONFIG_PATH")"
  PROFILE_DESCRIPTION="$(describe_template_profile "$TEMPLATE_PROFILE")"
}

risk_level() {
  if printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*(db|rollout)\s*(,|$)'; then
    printf 'high'
  elif printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*api\s*(,|$)'; then
    printf 'medium'
  else
    printf 'low'
  fi
}

rollback_required() {
  if printf '%s' "$CHANGE_TYPES" | grep -Eq '(^|,)\s*(db|rollout)\s*(,|$)'; then
    printf 'true'
  else
    printf 'false'
  fi
}

render_template() {
  local logical_template="$1"
  local target_file="$2"
  local content
  local template_file

  if ! template_file="$(resolve_template_file "$logical_template")"; then
    printf '{"status":"error","error":"Missing template: %s"}\n' "$(json_escape "$logical_template")"
    exit 1
  fi

  content="$(cat "$template_file")"
  content="${content//'{{FEATURE_ID}}'/$FEATURE_ID}"
  content="${content//'{{FEATURE_TITLE}}'/$TITLE}"
  content="${content//'{{OWNER}}'/$OWNER}"
  content="${content//'{{CHANGE_TYPES}}'/$CHANGE_TYPES}"
  content="${content//'{{DATE}}'/$TODAY}"
  content="${content//'{{TEMPLATE_PACK_NAME}}'/$TEMPLATE_PACK_NAME}"
  content="${content//'{{TEMPLATE_VERSION}}'/$TEMPLATE_VERSION}"
  content="${content//'{{TEMPLATE_PROFILE}}'/$TEMPLATE_PROFILE}"
  content="${content//'{{TEMPLATE_LANGUAGE}}'/$TEMPLATE_LANGUAGE}"
  content="${content//'{{PROFILE_DESCRIPTION}}'/$PROFILE_DESCRIPTION}"

  if [ "$DRY_RUN" -eq 0 ]; then
    printf '%s\n' "$content" > "$target_file"
  fi
  CREATED_FILES+=("$target_file")
}

write_manifest() {
  local feature_dir="$1"
  local manifest_path="$feature_dir/manifest.json"

  if [ "$DRY_RUN" -eq 0 ]; then
    printf '{\n' > "$manifest_path"
    printf '  "feature_id": "%s",\n' "$(json_escape "$FEATURE_ID")" >> "$manifest_path"
    printf '  "title": "%s",\n' "$(json_escape "$TITLE")" >> "$manifest_path"
    printf '  "owner": "%s",\n' "$(json_escape "$OWNER")" >> "$manifest_path"
    printf '  "feature_dir": "%s",\n' "$(json_escape "$feature_dir")" >> "$manifest_path"
    printf '  "change_types": ' >> "$manifest_path"
    if [ -n "$CHANGE_TYPES" ]; then
      append_array_json $(printf '%s' "$CHANGE_TYPES" | tr ',' ' ')
    else
      append_array_json
    fi >> "$manifest_path"
    printf ',\n' >> "$manifest_path"
    printf '  "required_docs": ' >> "$manifest_path"
    append_safe_array_json "REQUIRED_DOCS" >> "$manifest_path"
    printf ',\n' >> "$manifest_path"
    printf '  "related_project_docs": ' >> "$manifest_path"
    append_safe_array_json "RELATED_PROJECT_DOCS" >> "$manifest_path"
    printf ',\n' >> "$manifest_path"
    printf '  "verification_checks": ' >> "$manifest_path"
    append_safe_array_json "VERIFICATION_CHECKS" >> "$manifest_path"
    printf ',\n' >> "$manifest_path"
    printf '  "risk_level": "%s",\n' "$(json_escape "$(risk_level)")" >> "$manifest_path"
    printf '  "rollback_required": %s,\n' "$(rollback_required)" >> "$manifest_path"
    printf '  "template_pack": {\n' >> "$manifest_path"
    printf '    "name": "%s",\n' "$(json_escape "$TEMPLATE_PACK_NAME")" >> "$manifest_path"
    printf '    "version": "%s",\n' "$(json_escape "$TEMPLATE_VERSION")" >> "$manifest_path"
    printf '    "profile": "%s",\n' "$(json_escape "$TEMPLATE_PROFILE")" >> "$manifest_path"
    printf '    "language": "%s"\n' "$(json_escape "$TEMPLATE_LANGUAGE")" >> "$manifest_path"
    printf '  }\n' >> "$manifest_path"
    printf '}\n' >> "$manifest_path"
  fi
  CREATED_FILES+=("$manifest_path")
}

output_report() {
  local feature_dir="$1"
  printf '{'
  printf '"status":"success",'
  printf '"feature_id":"%s",' "$(json_escape "$FEATURE_ID")"
  printf '"title":"%s",' "$(json_escape "$TITLE")"
  printf '"feature_dir":"%s",' "$(json_escape "$feature_dir")"
  printf '"owner":"%s",' "$(json_escape "$OWNER")"
  printf '"manifest_path":"%s",' "$(json_escape "$feature_dir/manifest.json")"
  printf '"dry_run":%s,' "$( [ "$DRY_RUN" -eq 1 ] && printf 'true' || printf 'false' )"
  printf '"required_docs":'
  append_safe_array_json "REQUIRED_DOCS"
  printf ','
  printf '"risk_level":"%s",' "$(json_escape "$(risk_level)")"
  printf '"rollback_required":%s,' "$(rollback_required)"
  printf '"related_project_docs":'
  append_safe_array_json "RELATED_PROJECT_DOCS"
  printf ','
  printf '"created_files":'
  append_safe_array_json "CREATED_FILES"
  printf '}\n'
}

main() {
  local feature_base_dir
  local feature_dir
  local doc
  local title_slug

  parse_args "$@"
  require_jq
  init_template_resolver "$DEFAULT_TEMPLATES_DIR" "$USER_TEMPLATE_ROOT" ".harness/templates"

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing spec policy: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  load_template_pack_metadata
  feature_base_dir="$(jq -r '.feature_spec.base_dir // "docs/features"' "$CONFIG_PATH")"
  load_required_docs
  load_related_project_docs
  load_verification_checks

  title_slug="$(slugify "$TITLE")"
  if [ -z "$title_slug" ]; then
    title_slug="feature"
  fi
  feature_dir="$feature_base_dir/$FEATURE_ID-$title_slug"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$feature_dir"
  fi

  for doc in "${REQUIRED_DOCS[@]}"; do
    render_template "$(feature_template_file_for_doc "$doc")" "$feature_dir/$doc"
  done
  write_manifest "$feature_dir"

  output_report "$feature_dir"
}

main "$@"
