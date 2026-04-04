# AGENTS

This repository keeps task state in the repo so a new agent can resume work quickly.

## Startup Rules

- On startup, read this file first.
- Before planning or implementation for domain-facing changes, read `flow-index.yaml`.
- Load the relevant `domain-brain/` files for the affected flows, entities, invariants, edge cases, and state machines.
- Keep `flow-index.yaml` and `domain-brain/` synchronized with implementation changes.
- If a change alters user flows, model behavior, install rules, playback/export behavior, licensing status, or state transitions, update the matching `domain-brain/` files in the same change.

## Domain Brain

- Canonical location: `domain-brain/`
- Entry points:
	- `flow-index.yaml`
	- `domain-brain/README.md`
	- `domain-brain/glossary.md`
	- `domain-brain/invariants.md`
	- `domain-brain/edge-cases.md`
- Use `flow-index.yaml` to route changed files to the correct domain-brain documents.
- Prefer updating the smallest relevant domain-brain file instead of rewriting the whole directory.

## Task Flow

- Put active task files in `tasks/`.
- Move finished task files to `archived/`.
- Do not keep the same task file in both places.
- Prefer one Markdown file per task.
- Use short, durable task files that explain the goal, current status, blockers, and next steps.

## Working With Tasks

- When starting work, check `tasks/` first for an existing active task file.
- If the work already has an active task file, update that file instead of creating a duplicate.
- If the work is complete, move its task file from `tasks/` to `archived/`.
- Keep `task.notes.md` for stable repo-wide constraints and decisions.
- Keep `task.checkpoint.md` for compact milestone history.

## File Naming

- Use ordered Markdown file names such as `task-1-domain-brain.md` or `task-2-package-name-alignment.md`.
- Keep the numeric order aligned with the user’s stated priority.
- Keep names stable unless the task scope materially changes.

## Architecture Rules

- Canonical document: `docs/architecture-rules.md`
- Read it before implementing any feature that touches UI, services, or cross-platform behavior.
- Key concepts: **Basic functionality** (shared across desktop and mobile) vs **Extended functionality** (desktop only).
- All shared services go in `packages/tts_core/`. All shared UI goes in `packages/shared_ui/`.
- Platform-specific behavior must be abstracted behind interfaces in the shared packages.

## Basic Functionality Reporting

When working on a **Basic functionality** feature (one that must exist in both desktop and mobile apps), the agent must include a summary at the end of the work that clearly states:

1. **Identical on both platforms**: list what was implemented in shared packages and works the same way on desktop and mobile.
2. **Platform-specific differences**: list what required different implementations per platform, explain why, and confirm the user-facing behavior is equivalent.
3. **Not yet wired to one platform**: list anything implemented for one app but not yet integrated into the other, with a note on what remains.

This summary helps the user verify cross-platform parity.

## Documentation Pointers

- Architecture rules: `docs/architecture-rules.md`
- Architecture overview: `docs/architecture.md`
- Domain brain: `domain-brain/`
- Flow index: `flow-index.yaml`
- Desktop run instructions: `apps/desktop_app/how-to-run.md`
- Android run instructions: `apps/android_app/how-to-run.md`