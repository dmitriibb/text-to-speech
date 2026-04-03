# Android VITS LJSpeech Fix

## Goal

Fix the Android failure path for the `vits-ljs` / `VITS LJSpeech` model.

## Current Status

- Implementation complete; end-to-end Android confirmation still pending
- Root cause identified: the catalog and shared validator treated `vits-ljs` as an `espeak-ng-data` model, but upstream `vits-ljs` is a lexicon-based VITS model
- Shared model parsing, readiness validation, runtime loading, and the Phase 0 benchmark harness now support lexicon-based VITS models
- `vits-ljs` catalog metadata now expects `lexicon.txt` instead of `espeak-ng-data`
- Verified `flutter test` for `packages/tts_core` and `flutter analyze` for `packages/tts_core` and `apps/android_app`

## Blockers / Unknowns

- Still need a clean emulator or device pass to confirm install and repair both finish in `ready` state on Android
- If Android still fails after this fix, capture app logs around extraction and model load for a device-specific follow-up

## Next Steps

- On emulator or device, clear the `vits-ljs` install and verify both install and repair produce a `ready` model
- Generate speech once with `VITS LJSpeech` to confirm the lexicon-based load path works on Android runtime
- Capture logs only if Android still shows a device-specific failure after the metadata fix