stages:
  - validate

variables:
  HARNESS_SKILL_ROOT: "{{HARNESS_SKILL_ROOT}}"

validate:harness:
  stage: validate
  image: bash:latest
  script:
    - test -d "$HARNESS_SKILL_ROOT"
    - |
      if [ -n "${CI_MERGE_REQUEST_DIFF_BASE_SHA:-}" ]; then
        bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --json --base-ref "$CI_MERGE_REQUEST_DIFF_BASE_SHA" --head-ref "$CI_COMMIT_SHA"
      elif [ -n "${CI_COMMIT_BEFORE_SHA:-}" ] && [ "$CI_COMMIT_BEFORE_SHA" != "0000000000000000000000000000000000000000" ]; then
        bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --json --base-ref "$CI_COMMIT_BEFORE_SHA" --head-ref "$CI_COMMIT_SHA"
      else
        bash "$HARNESS_SKILL_ROOT/scripts/check-doc-impact.sh" --json
      fi
    - bash "$HARNESS_SKILL_ROOT/scripts/validate-spec.sh" --json --strict
    - bash "$HARNESS_SKILL_ROOT/scripts/lint-architecture.sh"
    - bash "$HARNESS_SKILL_ROOT/scripts/check-doc-freshness.sh" --json
