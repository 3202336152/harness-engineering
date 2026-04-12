# Architecture Patterns

> Deep reference for harness-engineering.

## Overview

This document explains how to encode architecture rules so AI coding agents can
follow them consistently and CI can enforce them mechanically.

## Recommended Layering

```text
Generic profile: Types -> Config -> Repo -> Service -> Runtime -> UI
Java profiles: Interfaces -> Application -> Domain; Infrastructure -> Domain
```

- Generic projects can keep the original `types/config/repo/service/runtime/ui` layering.
- Java backend profiles default to `interfaces/application/domain/infrastructure` and use `.harness/architecture.json` as the mechanical source of truth.
- The profile is selected by `init-harness.sh` and can be overridden with `--profile`.

## Boundary Rules

- Dependencies should follow the flow declared in `.harness/architecture.json`.
- If two layers need the same contract, move it into the lowest stable shared layer.
- Cross-domain calls should go through provider interfaces or the configured anti-corruption boundary rather than direct imports.
- CI should fail fast when a new import violates the chosen boundaries.

## Practical Enforcement

- Store a project-level config in `.harness/architecture.json`.
- Store spec requirements in `.harness/spec-policy.json`.
- Keep the canonical project architecture document in `docs/project/项目架构.md`.
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
