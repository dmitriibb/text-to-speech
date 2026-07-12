# Dialog Volume And Concurrency

## Goal

Add per-speaker Dialog volume controls and make desktop Dialog generation submit up to a configurable number of concurrent synthesis jobs.

## Current Status

Completed. Added per-speaker Dialog volume controls, applied volume during WAV generation, added desktop Dialog generation concurrency via `apps/desktop_app/settings.json`, and updated tests and domain notes.

## Scope

- Add per-speaker volume settings with default `7`, minimum `1`, and maximum `10`.
- Render volume controls in each one-line speaker settings row.
- Apply speaker volume to generated Dialog audio.
- Add desktop `settings.json` with Dialog generation concurrency defaulting to `4`.
- Use the desktop setting to run up to that many background synthesis workers.
- Update domain notes and tests.
