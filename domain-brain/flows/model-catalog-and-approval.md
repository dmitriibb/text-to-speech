# Model Catalog and Approval Flow

## Goal

Keep one clear source of truth for which models the apps may offer, how those models are installed, and what approval status applies to them.

## Steps

1. The repo stores approved model metadata in `packages/model_catalog/approved_models.json`.
2. `tts_core` parses that JSON into `ModelCatalog` and `VoiceModel` runtime types.
3. Desktop and Android bundle the catalog as an asset.
4. Apps scan local storage and combine catalog metadata with local status to produce `InstalledModel` entries.
5. Licensing status in the catalog and `docs/licensing.md` determines whether a model is development-only or potentially ship-ready later.
6. App UI keeps non-ready catalog entries visible on the dedicated Models screen so users can install or repair additional approved models even after one model is already ready.
7. The Models screen uses catalog metadata such as size, supported languages, runtime family, and short descriptions to explain what each entry is before installation.
8. Multilingual or family-specific runtime assets such as extra lexicons, rule FST or FAR files, dictionaries, or bundled speaker files must also be declared in the catalog instead of being inferred in app code.

## Invariants

- The catalog is the only source of truth for app-visible models.
- Apps must not invent install metadata outside the catalog.
- Apps must not invent user-facing size, language, or description metadata outside the catalog.
- Apps must not hide installable catalog entries just because another model is already ready.
- Family-specific runtime assets such as Pocket TTS's bundled default reference clip must be declared in the catalog and validated after install.
- Multilingual runtime assets such as Kokoro Chinese lexicons, rule FSTs, or dictionaries must be declared in the catalog and passed through shared runtime metadata.
- Unknown redistribution status blocks shipping decisions, even when local validation is allowed.

## Failure Modes

- stale app asset copy of the catalog
- missing or wrong install metadata in the catalog
- UI hides installable catalog entries after the first successful install
- licensing metadata says local validation is allowed but shipment status is still unresolved
- model family support exists in the catalog but the shared runtime or UI still assumes only older families such as `vits` or `kokoro`
