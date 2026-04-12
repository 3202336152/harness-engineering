# Harness Maturity Model

The Harness Maturity Model describes how ready a repository is for AI coding
agents.

Use it as an upgrade path, not just a label. The most reliable rollout is to
advance one level at a time and make each level mechanically true before
claiming the next one.

## Level 0: No Harness

- No entry document
- No core docs
- No repeatable workflow for an agent

## Level 1: Basic Harness

- Entry document exists
- Core docs structure exists
- Basic test and lint commands are documented

Upgrade from Level 0:

1. Run `bash scripts/init-harness.sh` to create the entry docs, project docs, and `.harness/` policies.
2. Fill the project-level docs with real architecture, testing, and development constraints.
3. Make sure the entry doc stays a short index instead of turning into a giant knowledge dump.

## Level 2: Constrained Harness

- Architecture boundaries are documented
- CI enforces important checks
- Team conventions are stored in the repo

Upgrade from Level 1:

1. Add doc impact, spec validation, and architecture lint checks to local hooks or CI.
2. Turn placeholder-friendly docs into governed docs by using `validate-spec --strict`.
3. Keep `.harness/spec-policy.json`, `.harness/doc-impact-rules.json`, and `.harness/context-policy.json` aligned with the actual project rules.

## Level 3: Observable Harness

- Machine-readable logs and tests
- Better feedback loops
- Work is isolated and auditable

Upgrade from Level 2:

1. Start using `harness-exec.sh verify` or `run` so run records, task memory, progress, and evidence are captured automatically.
2. Configure `.harness/observability-policy.json` so evidence collection is explicit instead of ad hoc.
3. Review `.harness/runtime/last-audit.json`, `.harness/runs/`, `.harness/metrics/`, and `.harness/evidence/` as part of project hygiene.

## Level 4: Autonomous Harness

- Agents can work end to end with little supervision
- Metrics and rollback paths are visible
- Entropy management is routine

Upgrade from Level 3:

1. Use `harness-exec.sh prepare -> verify -> run -> restore` as a repeatable operating loop, not one-off helper commands.
2. Add retention cleanup with `harness-gc.sh`, template governance with drift/migration scripts, and rollback readiness checks to normal delivery.
3. Treat audits, evidence bundles, and machine-readable plans as ongoing control loops instead of special-event tooling.

## Practical Boundary

Level 4 does not mean "the repo can deploy and roll back itself without any
other system." In this project, autonomy means the coding harness can:

- scaffold and validate work mechanically,
- keep recent task memory and evidence on disk,
- restore execution context after session breaks,
- and surface rollback readiness before high-risk changes move forward.
