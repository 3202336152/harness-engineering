#!/bin/bash

set -euo pipefail

RUN_POLICY_PATH=".harness/run-policy.json"
CONTEXT_DIR=".harness/runtime/context"
RUNS_DIR=".harness/runs"
EVIDENCE_DIR=".harness/evidence"
KEEP_CONTEXT=-1
KEEP_RUNS=-1
KEEP_EVIDENCE=-1
OUTPUT_JSON=0

PRUNED_CONTEXT=()
PRUNED_RUNS=()
PRUNED_EVIDENCE=()

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
Usage: harness-gc.sh [--run-policy <path>] [--context-dir <path>] [--runs-dir <path>] [--evidence-dir <path>] [--keep-context <n>] [--keep-runs <n>] [--keep-evidence <n>] [--json]
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --run-policy)
        RUN_POLICY_PATH="${2:-$RUN_POLICY_PATH}"
        shift 2
        ;;
      --context-dir)
        CONTEXT_DIR="${2:-$CONTEXT_DIR}"
        shift 2
        ;;
      --runs-dir)
        RUNS_DIR="${2:-$RUNS_DIR}"
        shift 2
        ;;
      --evidence-dir)
        EVIDENCE_DIR="${2:-$EVIDENCE_DIR}"
        shift 2
        ;;
      --keep-context)
        KEEP_CONTEXT="${2:-$KEEP_CONTEXT}"
        shift 2
        ;;
      --keep-runs)
        KEEP_RUNS="${2:-$KEEP_RUNS}"
        shift 2
        ;;
      --keep-evidence)
        KEEP_EVIDENCE="${2:-$KEEP_EVIDENCE}"
        shift 2
        ;;
      --json)
        OUTPUT_JSON=1
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
    printf '{"status":"error","error":"jq is required for harness-gc.sh"}\n'
    exit 1
  fi
}

file_mtime() {
  local path="$1"
  if stat -f %m "$path" >/dev/null 2>&1; then
    stat -f %m "$path"
  elif stat -c %Y "$path" >/dev/null 2>&1; then
    stat -c %Y "$path"
  else
    date +%s
  fi
}

load_retention_defaults() {
  if [ ! -f "$RUN_POLICY_PATH" ]; then
    return
  fi

  if [ "$KEEP_CONTEXT" -lt 0 ]; then
    KEEP_CONTEXT="$(jq -r '.retention.keep_context_bundles // 20' "$RUN_POLICY_PATH")"
  fi
  if [ "$KEEP_RUNS" -lt 0 ]; then
    KEEP_RUNS="$(jq -r '.retention.keep_run_records // 50' "$RUN_POLICY_PATH")"
  fi
  if [ "$KEEP_EVIDENCE" -lt 0 ]; then
    KEEP_EVIDENCE="$(jq -r '.retention.keep_evidence_dirs // 20' "$RUN_POLICY_PATH")"
  fi
}

prune_files() {
  local dir="$1"
  local keep="$2"
  local result_array="$3"
  local path
  local count=0
  local tmp

  [ -d "$dir" ] || return 0
  tmp="$(mktemp)"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    printf '%s\t%s\n' "$(file_mtime "$path")" "$path" >> "$tmp"
  done <<EOF
$(find "$dir" -maxdepth 1 -type f -name '*.json' | sort)
EOF

  while IFS=$'\t' read -r _ path; do
    [ -n "$path" ] || continue
    count=$((count + 1))
    if [ "$count" -gt "$keep" ]; then
      rm -f "$path"
      eval "$result_array+=(\"\$path\")"
    fi
  done <<EOF
$(sort -rn "$tmp")
EOF

  rm -f "$tmp"
}

prune_dirs() {
  local dir="$1"
  local keep="$2"
  local result_array="$3"
  local path
  local count=0
  local tmp

  [ -d "$dir" ] || return 0
  tmp="$(mktemp)"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    printf '%s\t%s\n' "$(file_mtime "$path")" "$path" >> "$tmp"
  done <<EOF
$(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
EOF

  while IFS=$'\t' read -r _ path; do
    [ -n "$path" ] || continue
    count=$((count + 1))
    if [ "$count" -gt "$keep" ]; then
      rm -rf "$path"
      eval "$result_array+=(\"\$path\")"
    fi
  done <<EOF
$(sort -rn "$tmp")
EOF

  rm -f "$tmp"
}

emit_json_report() {
  printf '{'
  printf '"status":"success",'
  printf '"context_dir":"%s",' "$(json_escape "$CONTEXT_DIR")"
  printf '"runs_dir":"%s",' "$(json_escape "$RUNS_DIR")"
  printf '"evidence_dir":"%s",' "$(json_escape "$EVIDENCE_DIR")"
  printf '"retention":{"keep_context":%s,"keep_runs":%s,"keep_evidence":%s},' "$KEEP_CONTEXT" "$KEEP_RUNS" "$KEEP_EVIDENCE"
  printf '"pruned":{"context_bundles":%s,"run_records":%s,"evidence_dirs":%s},' "${#PRUNED_CONTEXT[@]}" "${#PRUNED_RUNS[@]}" "${#PRUNED_EVIDENCE[@]}"
  printf '"pruned_paths":{"context_bundles":'
  append_array_json "${PRUNED_CONTEXT[@]-}"
  printf ',"run_records":'
  append_array_json "${PRUNED_RUNS[@]-}"
  printf ',"evidence_dirs":'
  append_array_json "${PRUNED_EVIDENCE[@]-}"
  printf '}}\n'
}

main() {
  parse_args "$@"
  require_jq
  load_retention_defaults

  [ "$KEEP_CONTEXT" -ge 0 ] || KEEP_CONTEXT=20
  [ "$KEEP_RUNS" -ge 0 ] || KEEP_RUNS=50
  [ "$KEEP_EVIDENCE" -ge 0 ] || KEEP_EVIDENCE=20

  prune_files "$CONTEXT_DIR" "$KEEP_CONTEXT" "PRUNED_CONTEXT"
  prune_files "$RUNS_DIR" "$KEEP_RUNS" "PRUNED_RUNS"
  prune_dirs "$EVIDENCE_DIR" "$KEEP_EVIDENCE" "PRUNED_EVIDENCE"

  if [ "$OUTPUT_JSON" -eq 1 ]; then
    emit_json_report
  else
    printf 'Harness GC pruned %s context bundle(s), %s run record(s), and %s evidence dir(s).\n' \
      "${#PRUNED_CONTEXT[@]}" "${#PRUNED_RUNS[@]}" "${#PRUNED_EVIDENCE[@]}"
  fi
}

main "$@"
