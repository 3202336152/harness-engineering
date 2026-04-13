#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKIP_OFFICIAL=0
SMOKE_AGENTS="${HARNESS_PUBLISH_SMOKE_AGENTS:-codex,claude-code}"

# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

exit_if_version_flag "${1:-}"

usage() {
  cat <<'EOF'
Usage: publish-check.sh [--skip-official]

Runs publish-readiness checks for the harness-engineering skill.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skip-official)
        SKIP_OFFICIAL=1
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n' "$1" >&2
        exit 1
        ;;
    esac
  done
}

run_step() {
  local label="$1"
  shift
  printf '\n[%s]\n' "$label"
  "$@"
}

run_agent_install_smoke_test() {
  local agent="$1"
  local tmpdir=""

  tmpdir="$(mktemp -d)"
  (
    cd "$tmpdir"
    env CI=1 npx skills add "$REPO_ROOT" --project -a "$agent" -y >/dev/null </dev/null
    test -f ./.agents/skills/harness-engineering/SKILL.md
  )
  rm -rf "$tmpdir"
}

trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

run_official_checks() {
  local agents=()
  local agent=""

  run_step "official validator" bash -lc 'env CI=1 npx skills-ref validate "'"$REPO_ROOT"'" </dev/null'
  run_step "skills discovery list" bash -lc 'env CI=1 npx skills add "'"$REPO_ROOT"'" --list </dev/null'
  IFS=',' read -r -a agents <<< "$SMOKE_AGENTS"
  for agent in "${agents[@]}"; do
    agent="$(trim_whitespace "$agent")"
    [ -n "$agent" ] || continue
    run_step "project install smoke test ($agent)" run_agent_install_smoke_test "$agent"
  done
}

main() {
  parse_args "$@"

  cd "$REPO_ROOT"

  run_step "spec compliance" bash "$REPO_ROOT/scripts/verify-spec-compliance.sh"
  run_step "shell tests" env SKIP_PUBLISH_CHECK_TEST=1 bash "$REPO_ROOT/tests/run-tests.sh"

  if [ "$SKIP_OFFICIAL" -eq 0 ]; then
    run_official_checks
  else
    printf '\n[official validator]\nSkipped by request (--skip-official).\n'
  fi

  printf '\nPublish readiness checks passed.\n'
}

main "$@"
