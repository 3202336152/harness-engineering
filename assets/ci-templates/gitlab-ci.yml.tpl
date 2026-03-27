stages:
  - validate

validate:harness:
  stage: validate
  image: bash:latest
  script:
    - bash scripts/verify-spec-compliance.sh
    - bash tests/run-tests.sh
