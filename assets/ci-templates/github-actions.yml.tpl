name: Harness Validation

on:
  push:
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Verify skill spec
        run: bash scripts/verify-spec-compliance.sh

      - name: Run harness tests
        run: bash tests/run-tests.sh
