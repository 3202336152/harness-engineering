#!/bin/bash

set -euo pipefail

has_any_file() {
  local pattern="$1"
  find . \
    \( -path './.git' -o -path './harness' -o -path './target' -o -path './build' -o -path './.build' -o -path './node_modules' \) -prune -o \
    -type f -name "$pattern" -print -quit 2>/dev/null | grep -q .
}

detect_project_stack() {
  if [ -f pom.xml ] || has_any_file 'pom.xml'; then
    printf 'java-maven'
  elif [ -f build.gradle ] || [ -f build.gradle.kts ] || has_any_file 'build.gradle' || has_any_file 'build.gradle.kts'; then
    printf 'java-gradle'
  elif [ -f pyproject.toml ] || [ -f setup.py ]; then
    printf 'python'
  elif [ -f go.mod ]; then
    printf 'go'
  elif [ -f Cargo.toml ]; then
    printf 'rust'
  elif [ -f package.json ]; then
    printf 'node'
  else
    printf 'unknown'
  fi
}
