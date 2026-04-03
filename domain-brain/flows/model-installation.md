# Model Installation Flow

## Goal

Turn a catalog entry into a locally usable `ready` model on the current platform.

## Steps

1. App loads the catalog and selects a `VoiceModel`.
2. App resolves the platform-specific model storage root.
3. App downloads the model archive from the catalog URL.
4. App extracts the archive through the shared pure-Dart extractor.
5. App validates the extracted directory against the required file set.
6. App exposes the model as `ready` only if validation succeeds.

## Invariants

- Android installs to app-private storage.
- Desktop may additionally detect workspace models for development.
- Extraction and validation must run before a model is treated as usable.
- Repair must follow the same validation path as first install.

## Failure Modes

- download failure
- interrupted or partial extraction
- wrong extracted directory name
- required model files missing after extraction
- platform-specific storage path issue