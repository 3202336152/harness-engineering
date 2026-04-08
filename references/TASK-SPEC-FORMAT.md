# Task Spec Format

> Deep reference for harness-engineering.

## Standard Structure

Every implementation task should have:

1. An objective
2. Constraints
3. Acceptance criteria
4. Ordered implementation steps
5. Links to the related feature-level spec pack when the change is substantial

## Example

```markdown
# Execution Plan: Add search

## Objective
Allow users to search results by name.

## Constraints
- Follow docs/project/ARCHITECTURE.md
- Follow docs/project/DEVELOPMENT.md
- Reuse existing services
- Keep docs, tests, and feature specs updated

## Acceptance Criteria
- [ ] Tests pass
- [ ] Type check passes
- [ ] Search behavior works for empty, partial, and exact matches
```

## Notes

- Keep phases actionable.
- Prefer checklist items that map to real verification steps.
- Record decisions that change scope or tradeoffs.
- Treat plans as execution companions to `docs/features/<feature-id>-<title-slug>/`, not as a replacement for feature specs.
