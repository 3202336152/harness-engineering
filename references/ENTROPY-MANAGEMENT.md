# Entropy Management

> Deep reference for harness-engineering.

## Problem

Agent-generated repositories drift unless teams regularly clean up stale docs,
dead code, duplicated logic, and naming inconsistencies.

## Guardrails

- Prefer shared utilities.
- Keep entry docs short and current.
- Track architectural decisions in versioned documents.
- Audit stale docs regularly.

## Suggested Cadence

### Daily

- lint and test checks

### Weekly

- documentation freshness scan
- dependency cleanup review
- dead code review

### Monthly

- architecture consistency review
- maturity reassessment
