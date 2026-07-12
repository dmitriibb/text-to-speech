# Supertonic 3 German Support

## Goal

Implement support for `supertonic-3-de` and add it to the approved model catalog.

## Current Status

Completed. Added shared Supertonic runtime metadata, validation, task payload, and synthesis support; added `supertonic-3-de` to the canonical catalog and app assets; updated licensing/domain notes and tests.

Correction: runtime validation later showed the current sherpa-onnx Supertonic asset rejects `lang=de` and only accepts `en`, `ko`, `es`, `pt`, and `fr`. `supertonic-3-de` was removed from the catalog in task 21; generic Supertonic runtime support remains.

## Scope

- Add a `supertonic` model family/runtime path in `packages/tts_core`.
- Confirm the current `sherpa_onnx` Dart package exposes the Supertonic config fields used by sherpa-onnx:
  - `duration_predictor`
  - `text_encoder`
  - `vector_estimator`
  - `vocoder`
  - `tts_json`
  - `unicode_indexer`
  - `voice_style`
- Extend `VoiceModel` catalog metadata so Supertonic runtime files can be declared and validated.
- Add `supertonic-3-de` catalog metadata using the sherpa-onnx package:
  - archive: `sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2`
  - language: German
  - speakers: 10
  - sample rate: 24000
- Add German language generation support by passing `lang=de` through the Supertonic generation config.
- Preserve existing dialog model assignment, speaker selection, volume, generation, and playback behavior.
- Sync desktop and Android app asset copies.
- Update `docs/licensing.md`, domain-brain notes, and model catalog tests.

## Notes

This should not require a separate Python/backend service if the Flutter `sherpa_onnx` bindings expose Supertonic. It is still a new runtime-family implementation inside the shared Dart runtime because the current app does not configure Supertonic models yet.

## Verification

- `flutter test` in `packages/tts_core`
- `flutter analyze` in `packages/tts_core`
- `flutter test` in `packages/shared_ui`
- Desktop and Android widget tests
- Manual German synthesis smoke test with at least two Supertonic speaker IDs
