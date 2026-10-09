# Voice Cloning

- Voice cloning is an Extended desktop-only model capability.
- The former Voice Lab navigation destination is replaced by `Backend models`; that screen only enables external backend runtimes and configures server URLs and health checks.
- Model-specific cloning and voice-design controls belong in the shared model settings modal through its extension builder, not in Home, Live TTS, or Dialog implementations.
- Model-setting extensions persist JSON-safe values such as reference-audio paths, preset IDs, style instructions, and tuning values under the selected model ID.
- Pocket TTS normal synthesis uses its bundled default reference clip when no cloning reference is configured.
- External OpenVoice, OmniVoice, and VoxCPM2 runtimes remain desktop-only and stay behind their backend service boundary.
- Backend configuration state is app-scoped so navigation does not reset enabled state, URLs, or connection progress.
- Enabled backends check health immediately and continue periodic health checks.
- Each backend-requiring model currently uses a separate Python environment to avoid dependency conflicts; compatible runtimes may be consolidated later.
- The backend API uses `GET /health`, `POST /jobs`, and job polling. `POST /jobs` carries arbitrary model-specific values in a JSON `settings` form field; optional capability endpoints such as OmniVoice `GET /voices` may supplement the common lifecycle.
- VoxCPM2 device selection prefers a supported PyTorch GPU runtime (including ROCm on supported AMD/Linux installations) and falls back to CPU when acceleration is unavailable or model initialization fails.
- Backend-generated WAV output is stored as generated audio and uses the same playback/export flow as local synthesis.
- Downloaded backend models and generated backend job artifacts are local runtime state and must stay out of git history.
- VoxCPM2 inference is serialized per loaded engine, including seed handling.
  The pinned `voxcpm==2.0.3` does not accept a `seed` generation argument; the
  adapter scopes and restores Torch CPU/CUDA/ROCm random state instead. A seed
  assists repeatability but does not establish an actor's identity.
- VoxCPM2 text normalization defaults off to preserve original Russian text;
  callers may opt in explicitly after verifying normalization for their language.
- VoxCPM2 accepts only `speed=1.0` until actual speaking-speed processing is
  implemented; other values are rejected before creating a job. `language` is
  recorded as a hint while the model infers pronunciation from the text.

## Current integration boundary

- The generic shared modal and extension-value storage are implemented.
- Dialog actors now own independent extension snapshots and per-target reference
  metadata (project-relative WAV path, SHA-256, exact transcript). Shared
  `DialogReferenceStore` copies bounded WAV-container inputs into project-managed
  storage, reuses content hashes, and verifies stored bytes before upload.
  Missing/changed references fail explicitly. It checks RIFF/WAVE identity;
  backend-specific PCM/rate/duration validation is still adapter work.
- Desktop VoxCPM2 actor settings inject a native WAV picker and exact transcript,
  delivery style, CFG and inference steps. Imports are project-managed and hashed;
  upload uses verified bytes. References are bounded to 1–30 seconds by the app.
  These controls remain Extended and are not injected into Android.
- The default checkpoint is pinned to 32279effe8c19989596f05d353d1447f51d9e915.
  Health and job submission check the actor's expected revision. Backend jobs
  are serialized with bounded request/poll deadlines; cancelled/deleted results
  are cleaned after safe inference completion, or expire after seven days.
- Speaker and language capabilities are derived directly from the shared model catalog.
- Backend enablement and URL configuration are exposed on `Backend models`.
- Other model-family cloning/style builders and Home/Live VoxCPM2 routing remain outside the Russian Dialog implementation.
