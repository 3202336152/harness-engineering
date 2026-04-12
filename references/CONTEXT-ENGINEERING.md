# Context Engineering

> Deep reference for harness-engineering.

## Overview

Context engineering is the practice of deciding what an agent should load
automatically, what it should load on demand, and what can stay on disk until
needed.

## Three Tiers

### Tier 1: Automatic

- `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`
- the current task
- the files already being edited

### Tier 2: On Demand

- focused reference documents
- execution plans
- sub-agent summaries

### Tier 3: Searchable

- the full codebase
- historical plans
- generated artifacts and logs

## Rules of Thumb

- Move durable knowledge from chat tools into the repository.
- Prefer concise indexes plus targeted references.
- Keep machine-readable outputs available for tests and audits.
- Avoid repeating the same guidance in multiple places.
