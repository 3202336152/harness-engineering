# harness-engineering

An Agent Skill for scaffolding, auditing, and maintaining AI coding agent
work environments using Harness Engineering principles.

## Install

```bash
npx skills add <owner>/harness-engineering
```

## Commands

| Command | Description |
|---------|-------------|
| `/harness init` | Initialize AGENTS.md, docs, and harness templates |
| `/harness audit` | Score the current harness maturity and suggest fixes |
| `/harness plan` | Generate a structured execution plan for a task |

## What It Includes

- `SKILL.md` with the Phase 1 command guidance
- `scripts/init-harness.sh` for scaffolding a project harness
- `scripts/audit-harness.sh` for maturity auditing
- `scripts/plan-harness.sh` for execution-plan generation
- `scripts/lint-architecture.sh` for configurable architecture checks
- `scripts/check-doc-freshness.sh` for stale-doc reporting
- `scripts/verify-spec-compliance.sh` for package validation
- `assets/templates/` for the generated project files
- `assets/ci-templates/` for downstream CI starters
- `references/MATURITY-MODEL.md` for maturity-level guidance
- `references/` deep guides for architecture, context, task specs, PR workflow,
  observability, entropy management, metrics, and security
- `tests/` for shell-based verification

## Development

```bash
bash tests/run-tests.sh
```

## Advanced Scripts

```bash
bash scripts/plan-harness.sh --task "Add search"
bash scripts/lint-architecture.sh
bash scripts/check-doc-freshness.sh --threshold 30 --json
bash scripts/verify-spec-compliance.sh
bash scripts/publish-check.sh --skip-official
```

## Release Flow

1. Run `bash scripts/publish-check.sh` for the full local and official checks.
2. Ensure the repository name is `harness-engineering`.
3. Push this directory to a public GitHub repository named `harness-engineering`.
4. Confirm GitHub contains `SKILL.md` at the repository root.
5. Verify install from GitHub with `npx skills add <owner>/harness-engineering`.

If you only want the offline/local checks first, use:

```bash
bash scripts/publish-check.sh --skip-official
```

## License

MIT
