---
name: harness-engineering
description: >
  Scaffold, audit, and maintain AI coding agent work environments using
  Harness Engineering principles. Use when the user wants to initialize
  entry docs or harness/docs structure, audit harness maturity, generate execution
  plans, validate specs, check doc impact or freshness, restore recent
  task context from harness/.harness/runtime, or prepare a project for AI coding
  agent workflows.
license: MIT
compatibility: Requires bash, git, and jq. Works with any language or framework. Windows users should run it from WSL2 or another POSIX-compatible shell.
metadata:
  author: "harness-engineering"
  version: "1.1.0"
  tags: "harness-engineering,agent-environment,scaffolding,code-quality"
allowed-tools: Bash(git:*) Read Write Edit Glob Grep
---

# Harness Engineering

Harness Engineering is the practice of designing the environment,
constraints, and feedback loops that make AI coding agents reliable.

Core formula:

```text
Coding Agent = AI Model + Harness
```

This skill focuses on three core capabilities plus a spec workflow:

1. `/harness init` scaffolds the core project harness.
2. `/harness audit` scores current harness maturity and recommends fixes.
3. `/harness plan` creates a structured execution plan for real work.
4. Supporting scripts scaffold and validate project-level and feature-level specs.
5. The autonomous baseline scripts create a machine-readable prepare/verify/run loop.

Supporting scripts extend the flow:

- `scripts/lint-architecture.sh` checks configured dependency boundaries.
- `scripts/check-doc-freshness.sh` reports stale markdown documentation.
- `scripts/check-runtime-deps.sh` verifies local runtime dependencies such as `bash`, `git`, and `jq`.
- `scripts/new-feature-spec.sh` creates feature-level spec packs from change types.
- `scripts/resolve-task-context.sh` resolves the minimum required context bundle for a task.
- `scripts/check-doc-impact.sh` blocks code changes that should have updated specs or project docs.
- `scripts/validate-spec.sh` validates project-level and feature-level spec completeness.
- `scripts/check-rollback-readiness.sh` checks whether rollout-heavy features have rollback docs ready.
- `scripts/harness-exec.sh` orchestrates `prepare`, `verify`, `run`, and `restore` stages for a baseline autonomous loop.
- `scripts/prepare-template-overrides.sh` exports built-in templates into a writable override directory.
- `scripts/check-template-drift.sh` audits template metadata drift and override hygiene.
- `scripts/migrate-template-docs.sh` migrates historical docs to the current template pack with backup-first safety.
- `scripts/collect-runtime-evidence.sh` captures configured commands and file artifacts into an evidence bundle.
- `scripts/harness-gc.sh` prunes old context bundles, run records, and evidence directories.
- `scripts/verify-spec-compliance.sh` validates the skill package layout.
- `schemas/plan-machine.schema.json` defines the machine-readable execution-plan contract for downstream automation.

## Command: /harness init

Use this when the project is missing an entry doc such as `AGENTS.md` or
`CLAUDE.md`, missing core docs, or the
user asks to prepare a repo for AI coding agents and spec-driven delivery.

All generated project-local directories now live under `harness/` so they do not
collide with an application's own root-level `docs/` tree. Root-level files are
kept only when tool or platform conventions require them, such as `AGENTS.md`,
`CLAUDE.md`, `.github/`, or git hooks.

Execution flow:

1. Detect whether the current directory is a git repository.
2. Detect the stack from `package.json`, `pyproject.toml`, `go.mod`, or
   `Cargo.toml`.
3. Create the standard `harness/docs/project/`, `harness/docs/features/`, `harness/docs/decisions/`,
   `harness/.harness/exec-plans/{active,completed,tech-debt}/`,
   `harness/.harness/product-specs/`, `harness/.harness/references/`, and `.github/`
   directories.
4. Render the canonical entry template into the requested tool-specific filenames, plus the project-level spec templates from `assets/templates/`.
5. Create `harness/.harness/architecture.json`, `harness/.harness/spec-policy.json`, `harness/.harness/doc-impact-rules.json`, `harness/.harness/context-policy.json`, `harness/.harness/run-policy.json`, and `harness/.harness/observability-policy.json`.
6. Create `harness/.harness/runtime/task-memory.json`, `harness/.harness/runtime/last-audit.json`, `harness/.harness/runtime/progress.md`, `harness/.harness/evidence/`, and `harness/.harness/metrics/`.
7. Optionally vendor the runtime bundle and scaffold local guardrails when strong constraints are requested.
8. When `--with-strong-constraints` is requested, also enable strict spec validation in the generated local hook so placeholder docs are blocked before commit.
9. Skip existing files unless `--force` is supplied, so rerunning init can add missing tool-specific entry files without overwriting the existing docs.
10. Output a JSON summary with entry files, created files, skipped files, enabled guardrails, and next steps.

Command:

```bash
bash scripts/init-harness.sh [--project-name <name>] [--description <text>] [--template-root <path>] [--profile <name>] [--tool <name>] [--entry-file <path>] [--with-git-hook] [--with-husky] [--with-github-actions] [--with-strong-constraints] [--with-strict-spec-checks] [--force] [--dry-run]
```

Template lookup order for scaffolding:

1. `--template-root <path>`
2. `HARNESS_TEMPLATE_ROOT`
3. `harness/.harness/templates/`
4. Built-in defaults under `assets/templates/`

Generated project-level docs also include `template_version`, `template_profile`, `template_language`, and `doc_state` frontmatter.
The scaffold also adds `harness/docs/project/运行基线.md` and `harness/docs/project/可观测性基线.md` so rollout, on-call, and telemetry rules are part of the shared truth.
By default, init renders both `CLAUDE.md` and `AGENTS.md` from the same canonical entry template so common agent tools share identical content.
Use `--tool codex`, `--tool claude-code`, `--tool gemini-cli`, or `--tool all` to target specific tool filenames; rerunning init with another tool adds the missing entry file instead of replacing the previous one.
Accepted aliases also normalize to the same targets: `cursor` and `windsurf` map to `codex`, `anthropic-claude` maps to `claude-code`, and `google-gemini` maps to `gemini-cli`.
Use `--entry-file <path>` when a tool expects a custom entry filename that is not built in.
For Java repos, the default profile is `java-backend-service`, and you can override it with `--profile`.
For Java profiles, generated policy now defaults to strict doc-state enforcement, and enabling `--with-git-hook` or `--with-husky` automatically upgrades local spec checks to strict mode.
For Java repos that want commit-time and CI-time enforcement instead of “remember to run commands,” prefer `--with-strong-constraints`.
Before first use on a new machine, run `bash scripts/check-runtime-deps.sh --json` to confirm `bash`, `git`, and `jq` are available.

### Post-init Project Hydration

`/harness init` only scaffolds structure, templates, and policy files. It does not semantically read the whole repository or auto-fill project truth. New docs start as `doc_state: scaffold`, and should be flipped to `doc_state: hydrated` only after the host model has read the relevant code and replaced template-only content with verified project facts.

For Java repos, first refresh `harness/.harness/runtime/java-doc-scan.json` with `bash scripts/scan-java-project.sh --json`. The scan is the full inventory baseline for package roots, entrypoints, controllers, listeners, jobs, clients, application services, domain services, repositories, components, configurations, controller advices, aspects, configuration properties, event listeners, and `@Bean` factory methods.

After initialization, the host coding model should inspect the repo before filling `harness/docs/project/*`:

1. Read build files such as `pom.xml` or `build.gradle*`.
2. Read the main startup class or equivalent entrypoint.
3. Inspect the `src/main/java` package structure at least two levels deep.
4. Read representative adapters such as `Controller`, `Facade`, `Listener`, or `Job`.
5. Read core orchestration and domain services such as `ApplicationService` or `DomainService`.
6. Read `application.yml` or `application-*.yml`.

Do not confuse “full inventory scan” with “load every source file into context.” The intended flow is full scan first, then targeted deep reading. If coverage is incomplete, record `待确认` or `未覆盖范围` rather than guessing. After hydrating project docs, run `bash scripts/validate-spec.sh --json --strict`; strict mode now checks `doc_state`, and for Java profiles it also verifies that the scan inventory is reflected in project docs.

## Command: /harness audit

Use this when the user wants a harness health check, maturity assessment,
architecture readiness review, or project environment audit.

The audit evaluates eight dimensions:

1. Entry document
2. Documentation structure
3. Documentation freshness
4. Architecture constraints
5. Test coverage readiness
6. Automation
7. Execution plans
8. Security governance

Scores map to maturity levels:

- `0-24`: Level 0, No Harness
- `25-49`: Level 1, Basic Harness
- `50-69`: Level 2, Constrained Harness
- `70-89`: Level 3, Observable Harness
- `90-100`: Level 4, Autonomous Harness

Command:

```bash
bash scripts/audit-harness.sh [--deep]
```

The script prints JSON only on stdout so agents can parse it safely.
When `harness/.harness/` already exists, the audit also refreshes `harness/.harness/runtime/last-audit.json` so the entry document can reason about audit staleness without relying on chat memory.
Use `--deep` when you want the audit to run project-local harness checks such as `scripts/lint-architecture.sh` and `scripts/validate-spec.sh` instead of scoring maturity from file presence alone.

## Command: /harness plan

Use this when the user asks to implement a feature following harness rules.
The plan should align with the project-level spec set in `harness/docs/project/`
and remind the user to update the related feature spec pack in `harness/docs/features/`.
If the required feature spec pack does not exist yet, create it with `harness-exec.sh prepare` or `new-feature-spec.sh` before relying on the execution plan alone.

Plan template:

```markdown
# Execution Plan: <title>

## Status
Active

## Objective
<clear goal>

## Constraints
- Follow harness/docs/project/项目架构.md
- Follow harness/docs/project/开发规范.md
- Keep tests, docs, and related feature specs updated

## Acceptance Criteria
- [ ] Tests pass
- [ ] Type check passes
- [ ] Lint passes
- [ ] Relevant docs updated

## Implementation Steps
### Phase 1
- [ ] Data or infrastructure work
### Phase 2
- [ ] Service or domain work
### Phase 3
- [ ] Integration or UI work
```

Store plans in `harness/.harness/exec-plans/active/`.

Command:

```bash
bash scripts/plan-harness.sh --task "<task description>" --agent "<agent-name>"
```

The plan command now writes both a Markdown execution plan and a machine-readable JSON plan, so downstream automation can reason over risk level, required checks, and rollback expectations.

Output JSON fields:

| Field | Type | Description |
|---|---|---|
| `status` | string | `"success"` or `"error"` |
| `title` | string | Original task description |
| `path` | string | Markdown execution plan path |
| `machine_plan_path` | string | Machine-readable JSON plan path |
| `agent` | string | Agent name passed to the command |
| `dry_run` | bool | Whether the command ran in dry-run mode |
| `references` | array | Required project doc paths that the task should follow |

The JSON file referenced by `machine_plan_path` uses a different schema from stdout and is intended for automation consumers that need `required_checks`, `risk_level`, `rollback_required`, and related metadata. A formal schema is published at `schemas/plan-machine.schema.json`.

## Baseline Autonomous Flow

Use this when the user wants a mechanically constrained local loop instead of scattered ad-hoc commands.

Commands:

```bash
bash scripts/harness-exec.sh prepare --task "Add search" --feature-id FEAT-001 --title "Add search" --agent <agent-name> --json
bash scripts/harness-exec.sh verify --feature-id FEAT-001 --json
bash scripts/harness-exec.sh run --task "Add search" --feature-id FEAT-001 --title "Add search" --agent <agent-name> --json
bash scripts/harness-exec.sh restore --feature-id FEAT-001 --json
```

Behavior:

- `prepare` creates a feature spec pack if needed, writes the Markdown plus JSON execution plan, and records a task context bundle under `harness/.harness/runtime/context/`.
- `verify` aggregates spec validation, doc impact, architecture lint, doc freshness, and rollback readiness, then writes a run record, metrics ledger entry, task memory snapshot, progress report, and evidence bundle.
- `verify` now honors `harness/.harness/run-policy.json` for `verify_steps`, `verify_fail_fast`, and `verify_timeout_seconds`, so warning-only checks can stay non-blocking while hard failures short-circuit or time out predictably.
- `run` chains `prepare -> verify -> autofix-safe -> reverify`, records the final run result, and can trigger retention GC from `harness/.harness/run-policy.json`.
- `restore` reconstructs the latest task summary, pending checklist items, and recommended context files from `harness/.harness/runtime/`.

Rerun semantics:

- `prepare` refreshes the current plan and context bundle for the task; it is safe to rerun when the task definition changes.
- `verify` and `run` append new run records and refresh the latest task-memory snapshot; they are repeatable verification loops, not transactional one-shot commands.
- For template upgrades or broad scaffold changes, prefer dedicated migration scripts over forcing the autonomous loop to rewrite historical docs.

When resuming after context compaction, agent restart, or a paused task handoff, run `bash scripts/harness-exec.sh restore --feature-id <id> --json` before making new edits so the next session starts from recorded task memory instead of chat recall.

Current boundary:

- This is a baseline autonomous loop, not full autonomy.
- Historical migration is safe and structural; it does not semantically rewrite whole documents.
- Runtime ledgers and evidence are local repo artifacts, not a hosted metrics or observability backend.
- `autofix-safe` only repairs safe structural spec issues, not business-code semantics.

## Spec Workflow

Project-level specs live under `harness/docs/project/` and act as shared project truth:

- `核心信念.md`
- `项目架构.md`
- `项目设计.md`
- `接口规范.md`
- `开发规范.md`
- `运行基线.md`
- `可观测性基线.md`
- `需求说明.md`
- `测试策略.md`
- `安全规范.md`

Feature-level specs live under `harness/docs/features/<feature-id>-<title-slug>/`.
Human-facing spec content and generated Markdown file names default to Chinese.
Each feature pack also includes a `manifest.json` with required docs, related project docs, verification checks, risk level, rollback requirement, and template metadata.

Default required docs:

- `功能概览.md`
- `方案设计.md`
- `测试方案.md`
- `状态.md`

Additional docs are triggered by `change_types` from `harness/.harness/spec-policy.json`.
Examples: `接口设计.md`, `数据设计.md`, `发布回滚.md`.

Commands:

```bash
bash scripts/new-feature-spec.sh --id FEAT-001 --title "Add search" --owner "alice" --change-types api,db [--template-root <path>]
bash scripts/resolve-task-context.sh --task "Add search" --feature-id FEAT-001 --json
bash scripts/check-doc-impact.sh --json --staged
bash scripts/validate-spec.sh --json
bash scripts/validate-spec.sh --json --strict
bash scripts/validate-spec.sh --json --autofix-safe
bash scripts/check-rollback-readiness.sh --feature-id FEAT-001 --json
bash scripts/harness-exec.sh verify --feature-id FEAT-001 --json
bash scripts/prepare-template-overrides.sh --list
bash scripts/prepare-template-overrides.sh --template feature/overview.md.tpl
bash scripts/check-template-drift.sh --json
bash scripts/migrate-template-docs.sh --json
bash scripts/harness-gc.sh --json
```

The generated feature docs inherit the template metadata from `harness/.harness/spec-policy.json`.
The generated project scaffold also includes `harness/.harness/doc-impact-rules.json` so teams can gate manual code changes against required doc updates.
Use `--strict` when the team is ready to fail validation on placeholder text, missing sections, and missing template metadata.
Use `check-template-drift.sh` when the template pack has evolved and you need to identify stale generated docs, redundant overrides, or orphaned custom templates.

## Architecture Constraints Quick Reference

Recommended dependency flow:

```text
Generic profile: Types -> Config -> Repo -> Service -> Runtime -> UI
Java profiles: Interfaces -> Application -> Domain; Infrastructure -> Domain
```

Rules:

- Dependencies follow the active `harness/.harness/architecture.json` profile.
- Same-layer imports should be avoided.
- Cross-domain communication should go through provider interfaces or the configured anti-corruption boundary.
- CI should enforce the important boundaries mechanically.

## Context Engineering Quick Reference

- Keep the active entry doc under 100 lines when possible.
- Use progressive disclosure: short index at the top, deep docs on demand.
- Knowledge outside the repo is invisible to the agent.
- Prefer machine-readable outputs such as JSON.

## Entropy Management Quick Reference

- Prefer shared utilities over duplication.
- Validate data at system boundaries.
- Keep docs fresh and close to code changes.
- Run routine checks for dead code, drift, and stale instructions.

## Anti-Patterns

- Huge entry docs that try to explain everything inline.
- Architecture rules that exist only in prose and never in CI.
- Unstructured test output that an agent cannot parse.
- Manual project knowledge trapped in chat history instead of the repo.
- Resuming a compacted task without running `harness-exec.sh restore` to reload the recorded task state and context bundle.
- Unbounded agent permissions.

## References

- `references/MATURITY-MODEL.md`: maturity levels and upgrade path.
- `references/ARCHITECTURE-PATTERNS.md`: layering and dependency guidance.
- `references/AGENTS-MD-GUIDE.md`: entry document guidance.
- `references/CONTEXT-ENGINEERING.md`: context budgeting model.
- `references/TASK-SPEC-FORMAT.md`: execution plan structure.
- `references/PR-WORKFLOW.md`: pull request review workflow.
- `references/OBSERVABILITY.md`: feedback-loop guidance.
- `references/ENTROPY-MANAGEMENT.md`: cleanup and drift control.
- `references/METRICS.md`: harness success measures.
- `references/SECURITY.md`: least-privilege and audit guidance.
- `assets/templates/`: scaffold templates copied by `/harness init`.
- `assets/ci-templates/`: downstream CI starting points.
- `scripts/init-harness.sh`: initialization logic.
- `scripts/audit-harness.sh`: maturity audit logic.
- `scripts/plan-harness.sh`: execution-plan generation.
- `scripts/new-feature-spec.sh`: feature-level spec generation.
- `scripts/resolve-task-context.sh`: task-to-context bundle resolution.
- `scripts/check-doc-impact.sh`: diff-based code/doc consistency gate.
- `scripts/validate-spec.sh`: project/feature spec validation.
- `scripts/check-rollback-readiness.sh`: rollout/rollback readiness gate.
- `scripts/harness-exec.sh`: prepare/verify/run/restore orchestration.
- `scripts/prepare-template-overrides.sh`: template export and discovery.
- `scripts/check-template-drift.sh`: template drift and override audit.
- `scripts/migrate-template-docs.sh`: backup-first historical template migration.
- `scripts/collect-runtime-evidence.sh`: configurable runtime evidence capture.
- `scripts/harness-gc.sh`: retention cleanup for runtime artifacts.
