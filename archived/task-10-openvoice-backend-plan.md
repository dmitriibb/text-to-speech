# OpenVoice Backend Plan

## Goal

Write and save a detailed architecture plan for adding an OpenVoice backend and desktop UI integration.

## Current Status

Complete.

## Notes

- The preferred architecture is a third app under `apps/open_voice_be`.
- The desktop app should call a local HTTP API, not Docker-specific commands.
- Local Python on Windows is the first implementation step.
- Docker is the second step after the backend API and local inference path are working.

## Outcome

1. Added `openvoice.backend.plan.md` at the repo root.
2. Captured the backend rationale, desktop UI behavior, API shape, rollout phases, and Docker strategy.
