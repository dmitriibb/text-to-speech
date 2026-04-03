# Android VITS LJSpeech Fix

## Goal

Fix the Android failure path for the `vits-ljs` / `VITS LJSpeech` model.

## Current Status

- Not started
- On Android, the app offers repair for the LJSpeech model, but repair does not resolve the problem
- The Piper Lessac model works, so the issue is likely model-specific or install-path-specific

## Blockers / Unknowns

- Need a reliable reproduction path on the emulator or device
- Need logs that show whether the failure is download, extraction, validation, or runtime loading
- Need to confirm the expected file layout for `vits-ljs` on Android after extraction

## Next Steps

- Reproduce the issue on the emulator with a clean model install
- Capture logs around download, extraction, validation, and model load
- Fix the root cause and verify that repair actually restores the model to a ready state