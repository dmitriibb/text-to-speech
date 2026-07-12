# Generic model settings

## Goal

Provide one reusable model selector and settings modal for every synthesis mode, persist settings per model, add the selector to Live TTS, and replace the Voice Lab navigation destination with backend model configuration.

## Status

Completed on 2026-07-12.

## Delivered

- Shared `ModelSelector` dropdown and gear-button settings modal.
- Shared per-model settings model with volume, speed, speaker, language, and extension values.
- Per-model persistence on desktop and Android.
- Home, Live TTS, and Dialog integration on both platforms.
- Volume propagation through normal and live synthesis.
- Desktop Backend models screen with persistent OpenVoice and OmniVoice enablement, URLs, and health checks.
- Obsolete Voice Lab screen removed.
- Domain brain, routing index, and tests updated.

## Verification

- `flutter test` passed in `packages/tts_core`.
- `flutter test` passed in `packages/shared_ui`.
- `flutter test` passed in `apps/desktop_app`.
- `flutter test` passed in `apps/android_app`.
- `flutter analyze packages/tts_core packages/shared_ui apps/desktop_app apps/android_app` passes with no findings.
