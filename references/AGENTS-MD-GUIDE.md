# AGENTS.md Guide

> Deep reference for harness-engineering.

## Purpose

`AGENTS.md` is the short index an agent reads first. It is not the place to
dump every rule in the project.

## Recommended Structure

1. Project name and one-sentence description
2. Quick commands
3. Architecture overview
4. Key constraints
5. Documentation navigation

## Principles

- Prefer fewer than 100 lines.
- Link out to deeper documents rather than duplicating them.
- Keep commands copy-pastable.
- Make constraints concrete enough to be testable.

## Good Example

- “Review `docs/design-docs/core-beliefs.md` before changing core infra.”
- “Run `npm test` and update docs before merging.”

## Bad Example

- Long prose history of the project
- Architectural theory with no file references
- Repeated copies of information already present in `docs/`
