# Model Catalog and Approval Flow

## Goal

Keep one clear source of truth for which models the apps may offer, how those models are installed, and what approval status applies to them.

## Steps

1. The repo stores approved model metadata in `packages/model_catalog/approved_models.json`.
2. `tts_core` parses that JSON into `ModelCatalog` and `VoiceModel` runtime types.
3. Desktop and Android bundle the catalog as an asset.
4. Apps scan local storage and combine catalog metadata with local status to produce `InstalledModel` entries.
5. Licensing status in the catalog and `docs/licensing.md` determines whether a model is development-only or potentially ship-ready later.
6. App UI keeps non-ready catalog entries visible so users can install or repair additional approved models even after one model is already ready.

## Invariants

- The catalog is the only source of truth for app-visible models.
- Apps must not invent install metadata outside the catalog.
- Apps must not hide installable catalog entries just because another model is already ready.
- Unknown redistribution status blocks shipping decisions, even when local validation is allowed.

## Failure Modes

- stale app asset copy of the catalog
- missing or wrong install metadata in the catalog
- UI hides installable catalog entries after the first successful install
- licensing metadata says local validation is allowed but shipment status is still unresolved
