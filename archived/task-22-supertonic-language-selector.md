# Supertonic Language Selector

## Goal

Return the Supertonic model as a multilingual model and add generation-language selection for models that require an explicit language code.

## Current Status

Completed. Restored Supertonic as a multilingual model, added selectable generation-language metadata, surfaced language labels/dropdowns in shared UI, and passed the selected language through normal, live, and Dialog synthesis.

## Scope

- Add catalog metadata for selectable generation languages.
- Restore Supertonic as a multilingual model supporting `en`, `ko`, `es`, `pt`, and `fr`.
- Show language information in voice/model selectors.
- Add a language dropdown when a selected model has multiple generation languages.
- Pass the selected language code into sherpa generation config for normal, live, and Dialog synthesis.
- Update docs, domain-brain notes, and tests.

## Verification

- `python -m unittest tests.test_model_catalog`
- `flutter test` in `packages/tts_core`
- `flutter analyze` in `packages/tts_core`
- `flutter test` in `packages/shared_ui`
- `flutter analyze` in `packages/shared_ui`
- `flutter test` in `apps/desktop_app`
- `flutter test` in `apps/android_app`
- `flutter analyze` in `apps/android_app`
