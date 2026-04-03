# VoiceModel

## Definition

A single approved model entry that describes how a voice should be downloaded, installed, validated, and loaded.

## Canonical Fields

- `id: string`
- `displayName: string`
- `family: string`
- `runtime: string`
- `archiveUrl: string`
- `archiveFormat: string`
- `installDirName: string`
- `modelFile: string`
- `tokensFile: string`
- `dataDir: string`
- `provider: string`
- `numThreads: int`
- `defaultSpeed: double`
- `defaultSpeakerId: int`
- `maxNumSentences: int`
- `approvedForDistribution: bool`

## Ownership

- Source of truth: `packages/model_catalog/approved_models.json`
- Runtime type: `packages/tts_core/lib/src/models/voice_model.dart`

## Notes

- `installDirName` defines the expected extracted directory name.
- `modelFile`, `tokensFile`, and optional `dataDir` define the readiness check.
- A `VoiceModel` may be usable for local development even when redistribution is still blocked.