# InstalledModel

## Definition

A `VoiceModel` plus its detected local installation state and resolved on-disk directory.

## Canonical Fields

- `voice: VoiceModel`
- `status: ModelStatus`
- `modelDir: string?`

## Ownership

- Runtime type: `packages/tts_core/lib/src/models/voice_model.dart`
- Produced by platform model services in desktop and Android apps

## Notes

- `modelDir` is present only when a local installation path is known.
- The same `VoiceModel` can be `ready` on one platform and `notInstalled` on another because storage roots differ.
- `InstalledModel` is the app-facing bridge between catalog metadata and local disk state.