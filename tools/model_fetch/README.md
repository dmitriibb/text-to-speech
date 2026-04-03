# model_fetch

Utilities for downloading approved Phase 0 models into the local workspace.

Primary script:

- `fetch_approved_model.py`

The script:

- reads `packages/model_catalog/approved_models.json`
- downloads the chosen archive
- caches the archive under `.cache/model-archives/`
- extracts the model into `models/`
- computes a local SHA-256 if upstream SHA-256 is Unknown

