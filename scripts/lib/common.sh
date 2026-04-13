#!/bin/bash

: "${HARNESS_SKILL_VERSION:=1.1.0}"

json_escape() {
  local text="$1"
  local escaped=""
  local index=0
  local char=""
  local replacement=""

  if command -v jq >/dev/null 2>&1; then
    escaped="$(printf '%s' "$text" | jq -Rsa .)"
    escaped="${escaped#\"}"
    escaped="${escaped%\"}"
    printf '%s' "$escaped"
    return 0
  fi

  text=${text//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\b'/\\b}
  text=${text//$'\f'/\\f}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}

  while [ "$index" -le 31 ]; do
    case "$index" in
      8|9|10|12|13)
        index=$((index + 1))
        continue
        ;;
    esac
    printf -v char '%b' "\\x$(printf '%02x' "$index")"
    printf -v replacement '\\u%04x' "$index"
    text=${text//"$char"/$replacement}
    index=$((index + 1))
  done

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
    return 0
  fi

  eval "append_array_json \"\${${array_name}[@]}\""
}

safe_array_json() {
  append_safe_array_json "$@"
}

require_jq() {
  local script_name="${1:-$(basename "${0:-script}")}"

  if ! command -v jq >/dev/null 2>&1; then
    printf '{"status":"error","error":"jq is required for %s"}\n' "$script_name"
    exit 1
  fi
}

print_harness_version() {
  printf 'harness-engineering %s\n' "$HARNESS_SKILL_VERSION"
}

exit_if_version_flag() {
  case "${1:-}" in
    --version|-V)
      print_harness_version
      exit 0
      ;;
  esac
}
