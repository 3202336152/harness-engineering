# Architecture

> {{PROJECT_NAME}} architecture notes.

## System Overview

Describe the major moving parts of the system.

## Layered Model

Recommended dependency flow:

```text
Types -> Config -> Repo -> Service -> Runtime -> UI
```

## Dependency Rules

- Dependencies flow one way.
- Boundary violations should be caught in CI.
- Cross-domain communication should go through explicit interfaces.
