#!/bin/bash

set -euo pipefail

CONFIG_PATH="harness/.harness/architecture.json"
SRC_ROOTS=()

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
}

usage() {
  cat <<'EOF'
Usage: lint-architecture.sh [--config <path>]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config)
        CONFIG_PATH="${2:-}"
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
    printf '{"status":"error","error":"jq is required for lint-architecture.sh"}\n'
    exit 1
  fi
}

layer_index() {
  local target="$1"
  local index=0
  local layer
  for layer in $LAYERS; do
    if [ "$layer" = "$target" ]; then
      printf '%s' "$index"
      return
    fi
    index=$((index + 1))
  done
  printf '%s' "-1"
}

dependency_forbidden() {
  local current_layer="$1"
  local target_layer="$2"
  local rule
  local normalized
  local source
  local target

  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    normalized="$(printf '%s' "$rule" | tr '→' '-' | sed 's/[[:space:]]*-[[:space:]]*>[[:space:]]*/->/g')"
    source="${normalized%%->*}"
    target="${normalized##*->}"
    if [ "$source" = "$current_layer" ] && [ "$target" = "$target_layer" ]; then
      return 0
    fi
  done <<EOF
$FORBIDDEN_DEPENDENCIES
EOF

  return 1
}

path_layer() {
  local path="$1"
  local normalized=""
  local layer

  normalized="$(printf '%s' "$path" | sed 's#[/\\]#.#g')"
  for layer in $LAYERS; do
    case "$path" in
      *"/$layer/"*|*"../$layer/"*|*"./$layer/"*)
        printf '%s' "$layer"
        return
        ;;
    esac
    case "$normalized" in
      "$layer"|*".$layer"|"$layer".*|*".$layer".*)
        printf '%s' "$layer"
        return
        ;;
    esac
  done
}

path_domain() {
  local path="$1"
  local normalized=""
  local segments=()
  local index=0
  local layer=""

  normalized="$(printf '%s' "$path" | sed 's#[/\\]#.#g')"
  IFS='.' read -r -a segments <<< "$normalized"
  for index in "${!segments[@]}"; do
    for layer in $LAYERS; do
      if [ "${segments[$index]}" = "$layer" ]; then
        if [ "$index" -gt 0 ] && [ -n "${segments[$((index - 1))]}" ] && [ "${segments[$((index - 1))]}" != ".." ]; then
          printf '%s' "${segments[$((index - 1))]}"
        fi
        return
      fi
    done
  done
}

java_package_name() {
  local file="$1"
  awk '
    /^[[:space:]]*package[[:space:]]+/ {
      line=$0
      sub(/^[[:space:]]*package[[:space:]]+/, "", line)
      sub(/;[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$file"
}

file_layer() {
  local file="$1"
  local relative_file=""
  local package_name=""

  if [[ "$file" == *.java ]]; then
    package_name="$(java_package_name "$file")"
    if [ -n "$package_name" ]; then
      path_layer "$package_name"
      return
    fi
  fi

  relative_file="$(relative_to_source_root "$file")"
  path_layer "$relative_file"
}

file_domain() {
  local file="$1"
  local relative_file=""
  local package_name=""

  if [[ "$file" == *.java ]]; then
    package_name="$(java_package_name "$file")"
    if [ -n "$package_name" ]; then
      path_domain "$package_name"
      return
    fi
  fi

  relative_file="$(relative_to_source_root "$file")"
  path_domain "$relative_file"
}

relative_to_source_root() {
  local file="$1"
  local src_root=""
  local prefix=""

  for src_root in "${SRC_ROOTS[@]-}"; do
    prefix="${src_root%/}/"
    case "$file" in
      "$prefix"*)
        printf '%s' "${file#"$prefix"}"
        return
        ;;
    esac
  done

  printf '%s' "$file"
}

source_file_list() {
  local src_root=""

  for src_root in "${SRC_ROOTS[@]-}"; do
    [ -d "$src_root" ] || continue
    find "$src_root" -type f
  done | sort -u
}

record_violation() {
  local file="$1"
  local line="$2"
  local current_layer="$3"
  local target_layer="$4"
  local import_path="$5"
  local message="$6"
  local fix="$7"

  if [ -n "$VIOLATIONS" ]; then
    VIOLATIONS="$VIOLATIONS
$file|$line|$current_layer|$target_layer|$import_path|$message|$fix"
  else
    VIOLATIONS="$file|$line|$current_layer|$target_layer|$import_path|$message|$fix"
  fi
}

check_file() {
  local file="$1"
  local relative_file
  local domain
  local current_layer
  local import_line
  local line_number
  local import_path
  local target_layer
  local target_domain
  local current_index
  local target_index

  relative_file="$(relative_to_source_root "$file")"
  domain="$(file_domain "$file")"
  current_layer="$(file_layer "$file")"
  current_index="$(layer_index "$current_layer")"
  if [ "$current_index" -lt 0 ]; then
    return
  fi

  while IFS= read -r import_line; do
    [ -n "$import_line" ] || continue
    line_number="${import_line%%|*}"
    import_path="${import_line#*|}"
    target_layer="$(path_layer "$import_path")"
    target_domain="$(path_domain "$import_path")"
    if [ -z "$target_layer" ]; then
      continue
    fi

    if dependency_forbidden "$current_layer" "$target_layer"; then
      record_violation \
        "$file" \
        "$line_number" \
        "$current_layer" \
        "$target_layer" \
        "$import_path" \
        "Forbidden dependency: $current_layer must not import $target_layer" \
        "Move the dependency to an allowed layer or introduce a domain-facing contract."
      continue
    fi

    if [ -n "$PROVIDERS_DIR" ] && printf '%s' "$import_path" | grep -q "$PROVIDERS_DIR"; then
      continue
    fi

    target_index="$(layer_index "$target_layer")"
    if [ "$target_index" -gt "$current_index" ]; then
      record_violation \
        "$file" \
        "$line_number" \
        "$current_layer" \
        "$target_layer" \
        "$import_path" \
        "Layer $current_layer must not import higher layer $target_layer" \
        "Move shared contracts downward or invert the dependency with an interface."
    fi

    if [ -n "$domain" ] && [ -n "$target_domain" ] && [ "$domain" != "$target_domain" ]; then
      record_violation \
        "$file" \
        "$line_number" \
        "$current_layer" \
        "$target_layer" \
        "$import_path" \
        "Direct cross-domain import detected from $domain" \
        "Use provider interfaces for cross-domain communication."
    fi
  done <<EOF
$(awk '
  {
    line=$0
    path=""
    if (match(line, /^[[:space:]]*import[[:space:]]+static[[:space:]]+[A-Za-z0-9_.]+[[:space:]]*;/)) {
      path=substr(line, RSTART, RLENGTH)
      sub(/^[[:space:]]*import[[:space:]]+static[[:space:]]+/, "", path)
      sub(/[[:space:]]*;[[:space:]]*$/, "", path)
    } else if (match(line, /^[[:space:]]*import[[:space:]]+[A-Za-z0-9_.]+[[:space:]]*;/)) {
      path=substr(line, RSTART, RLENGTH)
      sub(/^[[:space:]]*import[[:space:]]+/, "", path)
      sub(/[[:space:]]*;[[:space:]]*$/, "", path)
    } else if (match(line, /from[[:space:]]*["\047][^"\047]+["\047]/)) {
      path=substr(line, RSTART, RLENGTH)
      sub(/^from[[:space:]]*["\047]/, "", path)
      sub(/["\047]$/, "", path)
    } else if (match(line, /require\([[:space:]]*["\047][^"\047]+["\047]\)/)) {
      path=substr(line, RSTART, RLENGTH)
      sub(/^require\([[:space:]]*["\047]/, "", path)
      sub(/["\047]\)$/, "", path)
    } else if (match(line, /import[[:space:]]*["\047][^"\047]+["\047]/)) {
      path=substr(line, RSTART, RLENGTH)
      sub(/^import[[:space:]]*["\047]/, "", path)
      sub(/["\047]$/, "", path)
    }
    if (path != "") {
      printf "%d|%s\n", NR, path
    }
  }
' "$file")
EOF
}

emit_violations_json() {
  local count=0
  local record
  local file
  local line
  local current_layer
  local target_layer
  local import_path
  local message
  local fix

  printf '{'
  if [ -z "$VIOLATIONS" ]; then
    printf '"status":"passed","config":"%s","violations":[]}\n' "$(json_escape "$CONFIG_PATH")"
    return 0
  fi

  printf '"status":"violations","config":"%s","violations":[' "$(json_escape "$CONFIG_PATH")"
  while IFS='|' read -r file line current_layer target_layer import_path message fix; do
    [ -n "$file" ] || continue
    if [ "$count" -gt 0 ]; then
      printf ','
    fi
    printf '{"file":"%s","line":%s,"layer":"%s","target_layer":"%s","import":"%s","message":"%s","fix":"%s"}' \
      "$(json_escape "$file")" \
      "$line" \
      "$(json_escape "$current_layer")" \
      "$(json_escape "$target_layer")" \
      "$(json_escape "$import_path")" \
      "$(json_escape "$message")" \
      "$(json_escape "$fix")"
    count=$((count + 1))
  done <<EOF
$VIOLATIONS
EOF
  printf ']}\n'
  return 1
}

main() {
  local src_root=""
  local file

  parse_args "$@"
  require_jq

  if [ ! -f "$CONFIG_PATH" ]; then
    printf '{"status":"error","error":"Missing architecture config: %s"}\n' "$(json_escape "$CONFIG_PATH")"
    exit 1
  fi

  LAYERS="$(jq -r '.layers[]?' "$CONFIG_PATH")"
  PROVIDERS_DIR="$(jq -r '.cross_domain_allowed_via // "providers"' "$CONFIG_PATH")"
  FORBIDDEN_DEPENDENCIES="$(jq -r '.forbidden_dependencies[]? // empty' "$CONFIG_PATH")"
  VIOLATIONS=""

  while IFS= read -r src_root; do
    [ -n "$src_root" ] || continue
    SRC_ROOTS+=("$src_root")
  done <<EOF
$(jq -r '.src_roots[]? // empty' "$CONFIG_PATH")
EOF

  if [ "${#SRC_ROOTS[@]}" -eq 0 ]; then
    src_root="$(jq -r '.src_root // "src"' "$CONFIG_PATH")"
    SRC_ROOTS+=("$src_root")
  fi

  if ! printf '%s\n' "${SRC_ROOTS[@]-}" | while IFS= read -r src_root; do [ -d "$src_root" ] && exit 0; done; then
    printf '{"status":"passed","config":"%s","violations":[]}\n' "$(json_escape "$CONFIG_PATH")"
    exit 0
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    check_file "$file"
  done <<EOF
$(source_file_list)
EOF

  if emit_violations_json; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
