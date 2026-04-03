# ModelCatalog

## Definition

The repo-owned catalog of approved voice models and their runtime, install, default, and licensing metadata.

## Canonical Fields

- `catalog_version: int`
- `updated_on: string`
- `default_model_id: string?`
- `models: VoiceModel[]`

## Ownership

- Source of truth: `packages/model_catalog/approved_models.json`
- Runtime parser: `packages/tts_core/lib/src/models/voice_model.dart`

## Notes

- Apps bundle a copy of the catalog as an asset.
- The catalog decides which models the UI may offer for install.
- Licensing status in the catalog is descriptive project metadata, not a legal substitute for the missing upstream evidence.