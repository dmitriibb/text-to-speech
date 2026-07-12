# Invariants

- `packages/model_catalog/approved_models.json` is the source of truth for app-visible model metadata.
- `sherpa-onnx` is the only shared app-runtime family for Basic functionality in this repository.
- Desktop-only Voice Lab backend integrations may use a separate local runtime family as long as they stay behind the desktop backend boundary and do not replace the shared Basic runtime.
- Desktop model backends use the common asynchronous job API; model-specific request values are carried in the `settings` JSON object rather than changing the endpoint lifecycle.
- A backend that requests automatic acceleration must fall back to CPU when its supported PyTorch GPU runtime is unavailable or accelerated model initialization fails.
- A model is `ready` only when all required files exist: model file, `tokens.txt`, and `data_dir` when declared.
- Shared model installation logic must remain portable across desktop and Android; it must not depend on shell archive extraction.
- Android normal model installation uses app-private storage and must not rely on the workspace `models/` directory.
- Desktop may search the workspace `models/` directory only as a development convenience.
- Synthesis requires both a selected `ready` model and non-empty input text.
- Synthesized output is written to a local `.wav` file before playback, export, or sharing.
- After a model is installed, local synthesis must work without network access.
- Speed input is bounded to the app-supported range of `0.5x` to `2.0x`.
- Per-model output volume is bounded to `0.5x` to `1.5x` and defaults to `1.0x`.
- Model synthesis settings are keyed by model ID and shared across Home, Live TTS, and Dialog rather than owned by an individual screen.
- Models with Unknown redistribution status may be used for local validation and development, but must not be treated as ship-ready bundled assets.
- Repair or reinstall must never silently leave a broken model marked as `ready`.
