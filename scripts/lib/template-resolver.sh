#!/bin/bash

: "${DEFAULT_TEMPLATE_ROOT:=}"
: "${PROJECT_TEMPLATE_ROOT:=.harness/templates}"
: "${USER_TEMPLATE_ROOT:=}"

normalize_template_root() {
  local path="$1"
  while [ -n "$path" ] && [ "${path%/}" != "$path" ]; do
    path="${path%/}"
  done
  printf '%s' "$path"
}

init_template_resolver() {
  DEFAULT_TEMPLATE_ROOT="$(normalize_template_root "$1")"
  USER_TEMPLATE_ROOT="$(normalize_template_root "${2:-}")"
  PROJECT_TEMPLATE_ROOT="$(normalize_template_root "${3:-.harness/templates}")"
}

resolve_template_file() {
  local logical_path="$1"
  local candidate

  if [ -n "$USER_TEMPLATE_ROOT" ]; then
    candidate="$USER_TEMPLATE_ROOT/$logical_path"
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  if [ -n "$PROJECT_TEMPLATE_ROOT" ]; then
    candidate="$PROJECT_TEMPLATE_ROOT/$logical_path"
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  candidate="$DEFAULT_TEMPLATE_ROOT/$logical_path"
  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

default_template_file() {
  local logical_path="$1"
  local candidate="$DEFAULT_TEMPLATE_ROOT/$logical_path"
  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

list_default_template_files() {
  (
    cd "$DEFAULT_TEMPLATE_ROOT" >/dev/null 2>&1 || exit 1
    find . -type f | sort | sed 's#^\./##'
  )
}
