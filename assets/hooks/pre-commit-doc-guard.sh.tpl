#!/bin/sh

set -eu

HARNESS_SKILL_ROOT="${HARNESS_SKILL_ROOT:-{{HARNESS_SKILL_ROOT}}}"

if [ ! -d "$HARNESS_SKILL_ROOT" ]; then
  echo "[harness] HARNESS_SKILL_ROOT not found: $HARNESS_SKILL_ROOT"
  echo "[harness] Skip doc guard hook."
  exit 0
fi

echo "[harness] Checking staged code/doc consistency..."
bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --staged

echo "[harness] Checking spec structure..."
bash "$HARNESS_SKILL_ROOT/scripts/validate-spec.sh" {{HARNESS_VALIDATE_SPEC_FLAGS}} >/dev/null
