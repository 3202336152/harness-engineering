# Security

> Deep reference for harness-engineering.

## Principle

Agents should operate with the least privilege necessary for the current task.

## Baseline Rules

- never commit secrets
- keep `.env` and credential files out of version control
- avoid production actions without explicit approval
- prefer reversible changes and clear audit trails

## Repository Guidance

- document sensitive data handling in `docs/SECURITY.md`
- use CODEOWNERS for critical areas where appropriate
- keep rollback instructions easy to find
