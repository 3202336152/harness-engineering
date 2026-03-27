# Metrics

> Deep reference for harness-engineering.

## What to Measure

- time to first working PR
- CI first-pass rate
- rollback frequency
- review time per PR
- documentation freshness violations
- architecture boundary violations

## Why It Matters

The harness is working when agents produce correct changes quickly and humans
spend most of their attention reviewing intent, not reconstructing context.

## Suggested Targets

- first PR in under 2 hours
- CI first-pass rate above 85%
- review time under 10 minutes per PR
- zero known architecture boundary violations in main
