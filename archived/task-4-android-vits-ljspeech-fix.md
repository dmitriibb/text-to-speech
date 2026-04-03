# Android VITS LJSpeech Fix

## Goal

Fix the Android failure path for the `vits-ljs` / `VITS LJSpeech` model.

## Current Status

- Completed
- Root cause was a catalog and validation mismatch: `vits-ljs` was treated as an `espeak-ng-data` model, but the upstream model is lexicon-based
- Shared model parsing, readiness validation, runtime loading, and the benchmark harness now support lexicon-based VITS models
- `vits-ljs` now installs and loads with `lexicon.txt` metadata instead of `espeak-ng-data`
- Confirmed in follow-up validation that both available models are working

## Blockers / Unknowns

- None for this task

## Next Steps

- Archived