#!/bin/bash

: "${HARNESS_SKILL_VERSION:=1.1.0}"

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
