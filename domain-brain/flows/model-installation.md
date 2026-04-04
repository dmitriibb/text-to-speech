# Model Installation Flow

## Goal

Turn a catalog entry into a locally usable `ready` model on the current platform.

## Steps

1. App loads the catalog and selects a `VoiceModel`.
2. App resolves the platform-specific model storage root.
3. App downloads the model archive from the catalog URL.
4. App extracts the archive through the shared pure-Dart extractor.
5. App normalizes the extracted directory back to the expected install root if the archive introduces an extra wrapper directory.
6. App validates the extracted directory against the required file set.
7. App exposes the model as `ready` only if validation succeeds.
8. App task UI reports the actual install phase (`Downloading`, `Extracting`, `Validating`) and preserves terminal error details for later inspection.
9. If the user cancels the install task, the app removes the partial archive and extracted model files created by that task.

## Invariants

- Android installs to app-private storage.
- Desktop installs to a single app-managed models directory and does not rely on repo-local model folders.
- Extraction and validation must run before a model is treated as usable.
- Validation must cover model-family-specific assets, including Pocket TTS files.
- Repair must follow the same validation path as first install.
- Validation must use the model-specific runtime assets from the catalog, such as `lexicon.txt` or `espeak-ng-data`.
- User-visible install task status must reflect the real install phase, not unrelated preload tasks.
- Terminal install tasks keep a stable elapsed duration and preserve failure details.
- Cancelling an install task removes the partial files created by that install attempt.

## Failure Modes

- download failure
- interrupted or partial extraction
- wrong extracted directory name
- extra nested wrapper directory after extraction
- required model files missing after extraction
- catalog metadata expects the wrong runtime asset for the model
- install UI shows stale elapsed time or the wrong task as completed while install is still active
- desktop scans repo-local models and diverges from the app-managed install state
- cancelled install leaves partial archive or extracted files on disk
- platform-specific storage path issue
