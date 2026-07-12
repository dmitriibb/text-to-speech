# Supertonic German Correction

## Goal

Remove the unusable `supertonic-3-de` catalog entry after runtime validation showed the current sherpa-onnx Supertonic asset rejects German with `Invalid language: de`.

## Current Status

Completed. Removed `supertonic-3-de` from the catalog and synced app assets after runtime validation showed the current sherpa-onnx Supertonic asset does not support German.

## Scope

- Keep generic Supertonic runtime support in `tts_core`.
- Remove `supertonic-3-de` from the approved model catalog and synced app assets.
- Update catalog tests so Supertonic is not listed as a German dialog model.
- Update licensing and domain-brain notes to document the current language limitation.
- Leave tasks for VoxCPM2 and Qwen3-TTS untouched.
