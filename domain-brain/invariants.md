# Invariants

- `packages/model_catalog/approved_models.json` is the source of truth for app-visible model metadata.
- `sherpa-onnx` is the only supported synthesis runtime family in this repository.
- A model is `ready` only when all required files exist: model file, `tokens.txt`, and `data_dir` when declared.
- Shared model installation logic must remain portable across desktop and Android; it must not depend on shell archive extraction.
- Android normal model installation uses app-private storage and must not rely on the workspace `models/` directory.
- Desktop may search the workspace `models/` directory only as a development convenience.
- Synthesis requires both a selected `ready` model and non-empty input text.
- Synthesized output is written to a local `.wav` file before playback, export, or sharing.
- After a model is installed, local synthesis must work without network access.
- Speed input is bounded to the app-supported range of `0.25x` to `3.0x`.
- Models with Unknown redistribution status may be used for local validation and development, but must not be treated as ship-ready bundled assets.
- Repair or reinstall must never silently leave a broken model marked as `ready`.