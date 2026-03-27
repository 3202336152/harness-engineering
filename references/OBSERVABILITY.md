# Observability

> Deep reference for harness-engineering.

## Purpose

Agents move faster when they can inspect machine-readable evidence instead of
guessing from prose.

## Recommended Building Blocks

- structured application logs
- JSON test output
- repeatable local startup commands
- browser automation for UI verification

## Suggested Practices

- Keep log fields predictable: timestamp, component, action, duration.
- Make startup and test commands deterministic.
- Store evidence paths in execution plans or PR notes.
- Use worktree isolation for long-running parallel tasks.
