name: Harness Guardrails

on:
  push:
  pull_request:

env:
  HARNESS_SKILL_ROOT: .agents/skills/harness-engineering

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Ensure harness skill is available
        run: test -d "$HARNESS_SKILL_ROOT"

      - name: Check doc impact against code changes
        shell: bash
        env:
          PR_BASE_SHA: ${{ github.event.pull_request.base.sha }}
          PUSH_BEFORE_SHA: ${{ github.event.before }}
          CURRENT_SHA: ${{ github.sha }}
        run: |
          set -euo pipefail
          base_ref="${PR_BASE_SHA:-}"
          if [ -z "$base_ref" ] || [ "$base_ref" = "null" ]; then
            base_ref="${PUSH_BEFORE_SHA:-}"
          fi

          if [ -n "$base_ref" ] && [ "$base_ref" != "0000000000000000000000000000000000000000" ]; then
            bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --json --base-ref "$base_ref" --head-ref "$CURRENT_SHA"
          else
            bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --json
          fi

      - name: Validate spec completeness and quality
        run: bash "$HARNESS_SKILL_ROOT/scripts/validate-spec.sh" --json --strict

      - name: Check architecture boundaries
        run: bash scripts/lint-architecture.sh

      - name: Check doc freshness
        run: bash "$HARNESS_SKILL_ROOT/scripts/check-doc-freshness.sh" --json
