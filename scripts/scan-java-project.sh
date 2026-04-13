#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_JSON=1
OUTPUT_PATH="harness/.harness/runtime/java-doc-scan.json"
STACK="unknown"
GENERATED_AT="$(date +%FT%T%z)"

BUILD_FILES=()
MODULE_PATHS=()
SOURCE_ROOTS=()
RESOURCE_ROOTS=()
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
REPOSITORIES=()
COMPONENTS=()
CONFIGURATIONS=()
CONTROLLER_ADVICES=()
ASPECTS=()
PROPERTIES_BINDINGS=()
EVENT_LISTENERS=()
BEAN_METHODS=()
RECOMMENDED_READS=()

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

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
  if find . \
    \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
    -type f -name 'pom.xml' -print -quit 2>/dev/null | grep -q .; then
    STACK="java-maven"
  elif find . \
    \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
    \( -type f -name 'build.gradle' -o -type f -name 'build.gradle.kts' \) -print -quit 2>/dev/null | grep -q .; then
    STACK="java-gradle"
  else
    STACK="unknown"
  fi
}

require_java_repo() {
  if [ "$STACK" = "unknown" ] && [ "${#SOURCE_ROOTS[@]}" -eq 0 ]; then
    printf '{"status":"error","error":"No Java build file or src/main/java directory found"}\n'
    exit 1
  fi
}

is_package_root_suffix_segment() {
  case "$1" in
    interfaces|interface|http|web|rest|mq|messaging|listener|listeners|job|jobs|task|tasks|controller|controllers|facade|facades|adapter|adapters|consumer|consumers|producer|producers|persistence|scheduler|scheduling|repository|repositories|client|clients|gateway|gateways|application|domain|infrastructure|infra|impl)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

package_root_from_package() {
  local package_name="$1"
  local -a segments=()
  local count=0
  local last_segment=""
  local previous_segment=""
  local index=0
  local root=""

  IFS='.' read -r -a segments <<< "$package_name"
  count="${#segments[@]}"

  while [ "$count" -gt 3 ]; do
    last_segment="${segments[$((count - 1))]}"
    previous_segment=""
    if [ "$count" -gt 1 ]; then
      previous_segment="${segments[$((count - 2))]}"
    fi

    if is_package_root_suffix_segment "$last_segment"; then
      count=$((count - 1))
      continue
    fi

    if [ "$last_segment" = "service" ] && {
      [ "$previous_segment" = "application" ] || \
      [ "$previous_segment" = "domain" ] || \
      [ "$previous_segment" = "infrastructure" ] || \
      [ "$previous_segment" = "infra" ];
    }; then
      count=$((count - 1))
      continue
    fi

    break
  done

  root="${segments[0]}"
  index=1
  while [ "$index" -lt "$count" ]; do
    root="$root.${segments[$index]}"
    index=$((index + 1))
  done

  printf '%s' "$root"
}

has_java_annotation() {
  local path="$1"
  local annotation_pattern="$2"

  awk -v annotation_pattern="$annotation_pattern" '
    {
      line=$0
      sub(/[[:space:]]*\/\/.*$/, "", line)
      if (line ~ ("^[[:space:]]*@(" annotation_pattern ")(\\(|[[:space:]]|$)")) {
        found=1
        exit
      }
    }
    END { exit found ? 0 : 1 }
  ' "$path"
}

bean_method_names() {
  local path="$1"

  awk '
    {
      line=$0
      sub(/[[:space:]]*\/\/.*$/, "", line)
      if (line ~ /^[[:space:]]*@Bean(\(|[[:space:]]|$)/) {
        pending=1
        next
      }
      if (pending != 1) {
        next
      }
      if (line ~ /^[[:space:]]*$/) {
        next
      }
      if (line ~ /^[[:space:]]*@/) {
        next
      }
      if (index(line, "(") > 0) {
        signature=line
        sub(/\(.*/, "", signature)
        gsub(/[[:space:]]+/, " ", signature)
        sub(/^ /, "", signature)
        sub(/ $/, "", signature)
        if (signature != "") {
          count=split(signature, parts, " ")
          name=parts[count]
          if (name != "if" && name != "for" && name != "while" && name != "switch" && name != "catch" && name != "return" && name != "new") {
            print name
            pending=0
          }
        }
      }
    }
  ' "$path"
}

discover_build_files() {
  local path=""
  local build_path=""

  while IFS= read -r build_path; do
    [ -n "$build_path" ] || continue
    append_unique_to_array "BUILD_FILES" "$build_path"
  done <<EOF
$(find . \
  \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
  \( -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' -o -name 'settings.gradle' -o -name 'settings.gradle.kts' \) -print | sed 's#^\./##' | sort -u)
EOF

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    append_unique_to_array "MODULE_PATHS" "$path"
  done <<EOF
$(find . \
  \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
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

discover_source_roots() {
  local module_path=""
  local source_root=""
  local resource_root=""

  for module_path in "${MODULE_PATHS[@]-}"; do
    if [ "$module_path" = "." ]; then
      source_root="src/main/java"
      resource_root="src/main/resources"
    else
      source_root="$module_path/src/main/java"
      resource_root="$module_path/src/main/resources"
    fi

    if [ -d "$source_root" ]; then
      append_unique_to_array "SOURCE_ROOTS" "$source_root"
    fi
    if [ -d "$resource_root" ]; then
      append_unique_to_array "RESOURCE_ROOTS" "$resource_root"
    fi
  done
}

discover_config_files() {
  local resource_root=""

  for resource_root in "${RESOURCE_ROOTS[@]-}"; do
    [ -d "$resource_root" ] || continue

    while IFS= read -r path; do
      [ -n "$path" ] || continue
      append_unique_to_array "CONFIG_FILES" "$path"
      append_unique_to_array "RECOMMENDED_READS" "$path"
    done <<EOF
$(find "$resource_root" -type f \
  \( -name 'application*.yml' -o -name 'application*.yaml' -o -name 'application*.properties' -o \
     -name 'bootstrap*.yml' -o -name 'bootstrap*.yaml' -o -name 'bootstrap*.properties' -o \
     -name 'logback-spring.xml' -o -name 'logback.xml' -o -name 'spring.factories' -o \
     -name 'org.springframework.boot.autoconfigure.AutoConfiguration.imports' \) | sort)
EOF
  done
}

java_file_list() {
  local source_root=""
  for source_root in "${SOURCE_ROOTS[@]-}"; do
    [ -d "$source_root" ] || continue
    if command -v rg >/dev/null 2>&1; then
      rg --files "$source_root" -g '*.java'
    else
      find "$source_root" -type f -name '*.java'
    fi
  done | sort -u
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

  if [[ "$class_name" == *Application ]] || has_java_annotation "$path" 'SpringBootApplication' || grep -Eq 'public[[:space:]]+static[[:space:]]+void[[:space:]]+main[[:space:]]*\(' "$path"; then
    append_named_path "ENTRYPOINTS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Controller ]] || has_java_annotation "$path" 'RestController|Controller'; then
    append_named_path "CONTROLLERS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Facade ]]; then
    append_named_path "FACADES" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Listener ]] || has_java_annotation "$path" 'KafkaListener|RabbitListener|RocketMQMessageListener|JmsListener'; then
    append_named_path "LISTENERS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Job ]] || [[ "$class_name" == *Task ]] || has_java_annotation "$path" 'Scheduled'; then
    append_named_path "JOBS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Client ]] || [[ "$class_name" == *Gateway ]] || [[ "$class_name" == *FeignClient ]] || has_java_annotation "$path" 'FeignClient'; then
    append_named_path "CLIENTS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *ApplicationService ]] || [[ "$class_name" == *AppService ]] || [[ "$path" == */application/* && "$class_name" == *Service ]]; then
    append_named_path "APPLICATION_SERVICES" "$class_name" "$path"
  fi

  if [[ "$class_name" == *DomainService ]] || [[ "$path" == */domain/* && "$class_name" == *Service ]]; then
    append_named_path "DOMAIN_SERVICES" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Repository ]] || [[ "$class_name" == *Mapper ]] || has_java_annotation "$path" 'Repository|Mapper'; then
    append_named_path "REPOSITORIES" "$class_name" "$path"
  fi

  if has_java_annotation "$path" 'Component'; then
    append_named_path "COMPONENTS" "$class_name" "$path"
  fi

  if [[ "$class_name" == *Configuration ]] || has_java_annotation "$path" 'Configuration'; then
    append_named_path "CONFIGURATIONS" "$class_name" "$path"
  fi

  if has_java_annotation "$path" 'ControllerAdvice'; then
    append_named_path "CONTROLLER_ADVICES" "$class_name" "$path"
  fi

  if has_java_annotation "$path" 'Aspect'; then
    append_named_path "ASPECTS" "$class_name" "$path"
  fi

  if has_java_annotation "$path" 'ConfigurationProperties'; then
    append_named_path "PROPERTIES_BINDINGS" "$class_name" "$path"
  fi

  if has_java_annotation "$path" 'EventListener'; then
    append_named_path "EVENT_LISTENERS" "$class_name" "$path"
  fi

  while IFS= read -r bean_method_name; do
    [ -n "$bean_method_name" ] || continue
    append_named_path "BEAN_METHODS" "$bean_method_name" "$path"
  done <<EOF
$(bean_method_names "$path")
EOF
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
  printf ','
  printf '"repositories":'
  emit_named_path_json "REPOSITORIES"
  printf ','
  printf '"components":'
  emit_named_path_json "COMPONENTS"
  printf ','
  printf '"configurations":'
  emit_named_path_json "CONFIGURATIONS"
  printf ','
  printf '"controller_advices":'
  emit_named_path_json "CONTROLLER_ADVICES"
  printf ','
  printf '"aspects":'
  emit_named_path_json "ASPECTS"
  printf ','
  printf '"properties_bindings":'
  emit_named_path_json "PROPERTIES_BINDINGS"
  printf ','
  printf '"event_listeners":'
  emit_named_path_json "EVENT_LISTENERS"
  printf ','
  printf '"bean_methods":'
  emit_named_path_json "BEAN_METHODS"
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
  discover_build_files
  discover_source_roots
  require_java_repo
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
