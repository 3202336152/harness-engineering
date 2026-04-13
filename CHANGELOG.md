# Changelog

## Unreleased

- Hardened `json_escape()` so generated JSON stays valid for control characters and jq-backed escaping paths.
- Extended `lint-architecture.sh` with `allowed_cross_layer_types` glob allowlists and wildcard Java import detection.
- Added rule-level `severity` support to `lint-architecture.sh`, including non-blocking warning output and JSON metadata for each violation.
- Added `audit-harness.sh --deep` so audits can execute local harness checks and report the results under `deep_checks`.
- Made `harness-exec.sh verify` respect `run-policy.json` step ordering, fail-fast behavior, and per-step timeouts, while also fixing command status propagation for nested harness commands.
- Expanded `scan-java-project.sh` inventory coverage for additional Spring component roles such as repositories, configuration classes, controller advice, aspects, configuration properties, event listeners, and `@Bean` methods.

## 1.1.0 - 2026-04-13

- Added `doc_state: scaffold|hydrated` governance for generated project and feature docs, plus strict validation that blocks scaffold docs from passing as completed specs.
- `init-harness.sh` now reports `hydration_required_count` and `hydration_required_docs` so hosts can see which project docs still need code-backed hydration.
- Java profile initialization now defaults policy `strict_default` to true and automatically upgrades local hook/Husky spec checks to strict mode.
- Generic project spec templates now use language-neutral section headers instead of Java-only required section names.
- Added stronger strict-mode placeholder detection for common English and templating markers such as `TBD`, `FIXME`, and `{{TODO}}`.
- Extended `/harness plan` documentation with the stdout JSON contract and clarified the separate machine-plan schema.
- Extended `scripts/audit-harness.sh` to inspect `.harness/context-policy.json` and flag oversized context budgets.
- Added restore-stage guidance across the autonomous baseline flow so resumed tasks reload recorded task memory and context bundles.
- Expanded the baseline autonomous loop with `restore`, retention GC, runtime evidence capture, and task-memory/progress tracking.
- Added template governance tooling: `prepare-template-overrides.sh`, `check-template-drift.sh`, and `migrate-template-docs.sh`.
- Added project policies for context budgeting, observability, rollback readiness, and run retention under `.harness/`.

## 1.0.0

- Initial release of the `harness-engineering` skill
- Added `/harness init`, `/harness audit`, and `/harness plan` workflows
- Added architecture linting, doc freshness checks, and publish validation
- Added templates, CI starter files, and deep reference documents
