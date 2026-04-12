#!/bin/bash

set -euo pipefail

OUTPUT_JSON=1
OUTPUT_PATH=".harness/runtime/java-doc-scan.json"
SRC_ROOT="src/main/java"
RES_ROOT="src/main/resources"
STACK="unknown"
GENERATED_AT="$(date +%FT%T%z)"

BUILD_FILES=()
MODULE_PATHS=()
PACKAGE_ROOTS=()
CONFIG_FILES=()
ENTRYPOINTS=()
CONTROLLERS=()
FACADES=()
LISTENERS=()
JOBS=()
CLIENTS=()
APPLICATION_SERVICES=()
DOMAIN_SERVICES=()
RECOMMENDED_READS=()

json_escape() {
  local text="$1"
  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '%s' "$text"
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

append_unique_to_array() {
  local array_name="$1"
  local value="$2"
  local existing=()

  [ -n "$value" ] || return 0
  eval "existing=(\"\${${array_name}[@]-}\")"
  if [ "${#existing[@]}" -eq 0 ] || append_unique "$value" "${existing[@]}"; then
    eval "$array_name+=(\"\$value\")"
  fi
}

append_named_path() {
  local array_name="$1"
  local name="$2"
  local path="$3"

  [ -n "$name" ] || return 0
  [ -n "$path" ] || return 0
  append_unique_to_array "$array_name" "$name|$path"
  append_unique_to_array "RECOMMENDED_READS" "$path"
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

emit_named_path_json() {
  local array_name="$1"
  local records=()
  local first=1
  local record
  local name
  local path

  eval "records=(\"\${${array_name}[@]-}\")"

  printf '['
  for record in "${records[@]-}"; do
    [ -n "$record" ] || continue
    name="${record%%|*}"
    path="${record#*|}"
    if [ "$first" -eq 0 ]; then
      printf ','
    fi
    first=0
    printf '{"name":"%s","path":"%s"}' \
      "$(json_escape "$name")" \
      "$(json_escape "$path")"
  done
  printf ']'
}

usage() {
  cat <<'EOF'
Usage: scan-java-project.sh [--output <path>] [--json] [--text]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --output)
        OUTPUT_PATH="${2:-$OUTPUT_PATH}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
        shift
        ;;
      --text)
        OUTPUT_JSON=0
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf '{"status":"error","error":"Unknown argument: %s"}\n' "$(json_escape "$1")"
        exit 1
        ;;
    esac
  done
}

detect_stack() {
  if [ -f pom.xml ]; then
    STACK="java-maven"
  elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
    STACK="java-gradle"
  else
    STACK="unknown"
  fi
}

require_java_repo() {
  if [ "$STACK" = "unknown" ] && [ ! -d "$SRC_ROOT" ]; then
    printf '{"status":"error","error":"No Java build file or src/main/java directory found"}\n'
    exit 1
  fi
}

package_root_from_package() {
  local package_name="$1"
  printf '%s' "$package_name" | awk -F. 'NF >= 3 { printf "%s.%s.%s", $1, $2, $3; next } { printf "%s", $0 }'
}

discover_build_files() {
  [ -f pom.xml ] && append_unique_to_array "BUILD_FILES" "pom.xml"
  [ -f build.gradle ] && append_unique_to_array "BUILD_FILES" "build.gradle"
  [ -f build.gradle.kts ] && append_unique_to_array "BUILD_FILES" "build.gradle.kts"
  [ -f settings.gradle ] && append_unique_to_array "BUILD_FILES" "settings.gradle"
  [ -f settings.gradle.kts ] && append_unique_to_array "BUILD_FILES" "settings.gradle.kts"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    append_unique_to_array "MODULE_PATHS" "$path"
  done <<EOF
$(find . \
  \( -path './.git' -o -path './.harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
  \( -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' \) -print | sed 's#^\./##' | xargs -I{} dirname "{}" | sort -u)
EOF

  if [ "${#MODULE_PATHS[@]}" -eq 0 ]; then
    append_unique_to_array "MODULE_PATHS" "."
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    append_unique_to_array "RECOMMENDED_READS" "$path"
  done <<EOF
$(printf '%s\n' "${BUILD_FILES[@]-}" | sort -u)
EOF
}

discover_config_files() {
  [ -d "$RES_ROOT" ] || return 0

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    append_unique_to_array "CONFIG_FILES" "$path"
    append_unique_to_array "RECOMMENDED_READS" "$path"
  done <<EOF
$(find "$RES_ROOT" -maxdepth 1 -type f \( -name 'application*.yml' -o -name 'application*.yaml' -o -name 'application*.properties' \) | sort)
EOF
}

java_file_list() {
  if [ ! -d "$SRC_ROOT" ]; then
    return 0
  fi

  if command -v rg >/dev/null 2>&1; then
    rg --files "$SRC_ROOT" -g '*.java' | sort
  else
    find "$SRC_ROOT" -type f -name '*.java' | sort
  fi
}

classify_java_file() {
  local path="$1"
  local class_name=""
  local package_name=""
  local package_root=""

  class_name="$(basename "$path" .java)"
  package_name="$(awk '
    /^package[[:space:]]+/ {
      line=$0
      sub(/^package[[:space:]]+/, "", line)
      sub(/;[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$path")"
  if [ -n "$package_name" ]; then
    package_root="$(package_root_from_package "$package_name")"
    append_unique_to_array "PACKAGE_ROOTS" "$package_root"
  fi

  if [[ "$class_name" == *Application ]] || grep -Eq '@SpringBootApplication|public[[:space:]]+static[[:space:]]+void[[:space:]]+main[[:space:]]*\(' "$path"; then
    append_named_path "ENTRYPOINTS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Controller ]] || grep -Eq '@RestController|@Controller' "$path"; then
    append_named_path "CONTROLLERS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Facade ]]; then
    append_named_path "FACADES" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Listener ]] || grep -Eq '@KafkaListener|@RabbitListener|@RocketMQMessageListener|@JmsListener' "$path"; then
    append_named_path "LISTENERS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Job ]] || [[ "$class_name" == *Task ]] || grep -Eq '@Scheduled' "$path"; then
    append_named_path "JOBS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Client ]] || [[ "$class_name" == *Gateway ]] || [[ "$class_name" == *FeignClient ]] || grep -Eq '@FeignClient' "$path"; then
    append_named_path "CLIENTS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *ApplicationService ]] || [[ "$class_name" == *AppService ]] || [[ "$path" == */application/* && "$class_name" == *Service ]]; then
    append_named_path "APPLICATION_SERVICES" "$class_name" "$path"
  fi

  if [[ "$class_name" == *DomainService ]] || [[ "$path" == */domain/* && "$class_name" == *Service ]]; then
    append_named_path "DOMAIN_SERVICES" "$class_name" "$path"
  fi
}

discover_java_inventory() {
  local path=""

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    classify_java_file "$path"
  done <<EOF
$(java_file_list)
EOF
}

emit_json() {
  printf '{'
  printf '"status":"success",'
  printf '"stack":"%s",' "$(json_escape "$STACK")"
  printf '"generated_at":"%s",' "$(json_escape "$GENERATED_AT")"
  printf '"scan_path":"%s",' "$(json_escape "$OUTPUT_PATH")"
  printf '"inventory":{'
  printf '"build_files":'
  append_array_json "${BUILD_FILES[@]-}"
  printf ','
  printf '"module_paths":'
  append_array_json "${MODULE_PATHS[@]-}"
  printf ','
  printf '"package_roots":'
  append_array_json "${PACKAGE_ROOTS[@]-}"
  printf ','
  printf '"config_files":'
  append_array_json "${CONFIG_FILES[@]-}"
  printf ','
  printf '"entrypoints":'
  emit_named_path_json "ENTRYPOINTS"
  printf ','
  printf '"controllers":'
  emit_named_path_json "CONTROLLERS"
  printf ','
  printf '"facades":'
  emit_named_path_json "FACADES"
  printf ','
  printf '"listeners":'
  emit_named_path_json "LISTENERS"
  printf ','
  printf '"jobs":'
  emit_named_path_json "JOBS"
  printf ','
  printf '"clients":'
  emit_named_path_json "CLIENTS"
  printf ','
  printf '"application_services":'
  emit_named_path_json "APPLICATION_SERVICES"
  printf ','
  printf '"domain_services":'
  emit_named_path_json "DOMAIN_SERVICES"
  printf '},'
  printf '"recommended_reads":'
  append_array_json "${RECOMMENDED_READS[@]-}"
  printf '}\n'
}

emit_text() {
  local total_reads="${#RECOMMENDED_READS[@]}"
  printf 'Java inventory written to %s. Recommended reads: %s.\n' "$OUTPUT_PATH" "$total_reads"
}

main() {
  local json_output=""

  parse_args "$@"
  detect_stack
  require_java_repo
  discover_build_files
  discover_config_files
  discover_java_inventory

  json_output="$(emit_json)"
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  printf '%s' "$json_output" > "$OUTPUT_PATH"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    printf '%s' "$json_output"
  else
    emit_text
  fi
}

main "$@"
