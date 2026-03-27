#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$REPO_ROOT/tests/test-init.sh"
bash "$REPO_ROOT/tests/test-audit.sh"
bash "$REPO_ROOT/tests/test-plan.sh"
bash "$REPO_ROOT/tests/test-lint-architecture.sh"
bash "$REPO_ROOT/tests/test-doc-freshness.sh"
bash "$REPO_ROOT/tests/test-skillmd.sh"
bash "$REPO_ROOT/tests/test-package-layout.sh"
if [ "${SKIP_PUBLISH_CHECK_TEST:-0}" != "1" ]; then
  bash "$REPO_ROOT/tests/test-publish-check.sh"
fi
