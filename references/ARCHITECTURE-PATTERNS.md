# Architecture Patterns

> Deep reference for harness-engineering.

## Overview

This document explains how to encode architecture rules so AI coding agents can
follow them consistently and CI can enforce them mechanically.

## Recommended Layering

```text
Types -> Config -> Repo -> Service -> Runtime -> UI
```

- `types/` contains shared contracts and zero behavior.
- `config/` loads configuration and depends only on `types/`.
- `repo/` handles data access.
- `service/` holds business logic.
- `runtime/` wires applications together.
- `ui/` presents behavior to users.

## Boundary Rules

- Dependencies should flow from left to right only.
- If two layers need the same contract, move it downward into `types/`.
- Cross-domain calls should go through provider interfaces rather than direct
  imports.
- CI should fail fast when a new import violates the chosen boundaries.

## Practical Enforcement

- Store a project-level config in `.harness/architecture.json`.
- Store spec requirements in `.harness/spec-policy.json`.
- Keep the canonical project architecture document in `docs/project/ARCHITECTURE.md`.
- Use `scripts/lint-architecture.sh` as the portable starting point.
- If the team has stronger native tooling, mirror the same rules in ESLint,
  Ruff, or language-specific analyzers.

## Good Output

Every violation should contain:

- the offending file
- the line number
- the bad import path
- a plain-language explanation
- a concrete fix suggestion
