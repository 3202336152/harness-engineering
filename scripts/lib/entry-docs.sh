#!/bin/bash

all_supported_entry_doc_files() {
  printf '%s\n' "AGENTS.md" "CLAUDE.md" "GEMINI.md"
}

default_entry_doc_files() {
  printf '%s\n' "CLAUDE.md" "AGENTS.md"
}

supported_entry_tool_names() {
  printf '%s\n' "codex" "claude-code" "gemini-cli" "all"
}

normalize_entry_tool_name() {
  local tool="${1:-}"

  tool="$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')"
  case "$tool" in
    codex|codex-cli|openai-codex|agents|cursor|windsurf)
      printf 'codex'
      ;;
    claude|claude-cli|claude-code|anthropic-claude)
      printf 'claude-code'
      ;;
    gemini|gemini-cli|google-gemini)
      printf 'gemini-cli'
      ;;
    all)
      printf 'all'
      ;;
    *)
      return 1
      ;;
  esac
}

entry_doc_files_for_tool() {
  local normalized=""

  normalized="$(normalize_entry_tool_name "$1")" || return 1
  case "$normalized" in
    codex)
      printf '%s\n' "AGENTS.md"
      ;;
    claude-code)
      printf '%s\n' "CLAUDE.md"
      ;;
    gemini-cli)
      printf '%s\n' "GEMINI.md"
      ;;
    all)
      all_supported_entry_doc_files
      ;;
  esac
}

first_existing_entry_document_path() {
  local entry_doc=""

  while IFS= read -r entry_doc; do
    [ -n "$entry_doc" ] || continue
    if [ -f "$entry_doc" ]; then
      printf '%s' "$entry_doc"
      return 0
    fi
  done <<EOF
$(all_supported_entry_doc_files)
EOF

  return 1
}
