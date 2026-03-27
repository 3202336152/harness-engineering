---
name: harness-engineering
description: >
  Scaffold, audit, and maintain AI coding agent work environments using
  Harness Engineering principles. Use when a project needs AGENTS.md,
  architecture constraints, harness maturity auditing, execution plans,
  or general optimization for AI coding agents.
license: MIT
compatibility: Requires bash and git. Works with any language or framework.
metadata:
  author: "OpenAI Codex"
  version: "1.0.0"
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

This skill focuses on three Phase 1 capabilities:

1. `/harness init` scaffolds the core project harness.
2. `/harness audit` scores current harness maturity and recommends fixes.
3. `/harness plan` creates a structured execution plan for real work.

Supporting scripts extend the flow:

- `scripts/lint-architecture.sh` checks configured dependency boundaries.
- `scripts/check-doc-freshness.sh` reports stale markdown documentation.
- `scripts/verify-spec-compliance.sh` validates the skill package layout.

## Command: /harness init

Use this when the project is missing `AGENTS.md`, missing core docs, or the
user asks to prepare a repo for AI coding agents.

Execution flow:

1. Detect whether the current directory is a git repository.
2. Detect the stack from `package.json`, `pyproject.toml`, `go.mod`, or
   `Cargo.toml`.
3. Create the standard `docs/`, `docs/design-docs/`,
   `docs/exec-plans/{active,completed,tech-debt}/`, `docs/product-specs/`,
   `docs/references/`, and `.github/` directories.
4. Render templates from `assets/templates/`.
5. Skip existing files unless `--force` is supplied.
6. Output a JSON summary with created files, skipped files, and next steps.

Command:

```bash
bash scripts/init-harness.sh [--project-name <name>] [--description <text>] [--force] [--dry-run]
```

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
bash scripts/audit-harness.sh [--json] [--verbose]
```

The script prints JSON only on stdout so agents can parse it safely.

## Command: /harness plan

Use this when the user asks to implement a feature following harness rules.

Plan template:

```markdown
# Execution Plan: <title>

## Status
Active

## Objective
<clear goal>

## Constraints
- Follow docs/ARCHITECTURE.md
- Follow docs/CONVENTIONS.md
- Keep tests and docs updated

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

Store plans in `docs/exec-plans/active/`.

Command:

```bash
bash scripts/plan-harness.sh --task "<task description>" --agent "<agent-name>"
```

## Architecture Constraints Quick Reference

Recommended dependency flow:

```text
Types -> Config -> Repo -> Service -> Runtime -> UI
```

Rules:

- Dependencies flow left to right only.
- Same-layer imports should be avoided.
- Cross-domain communication should go through provider interfaces.
- CI should enforce the important boundaries mechanically.

## Context Engineering Quick Reference

- Keep `AGENTS.md` under 100 lines when possible.
- Use progressive disclosure: short index at the top, deep docs on demand.
- Knowledge outside the repo is invisible to the agent.
- Prefer machine-readable outputs such as JSON.

## Entropy Management Quick Reference

- Prefer shared utilities over duplication.
- Validate data at system boundaries.
- Keep docs fresh and close to code changes.
- Run routine checks for dead code, drift, and stale instructions.

## Anti-Patterns

- Huge `AGENTS.md` files that try to explain everything inline.
- Architecture rules that exist only in prose and never in CI.
- Unstructured test output that an agent cannot parse.
- Manual project knowledge trapped in chat history instead of the repo.
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
