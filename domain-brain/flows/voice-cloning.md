# Voice Cloning

- Voice cloning is an Extended desktop-only model capability.
- The former Voice Lab navigation destination is replaced by `Backend models`; that screen only enables external backend runtimes and configures server URLs and health checks.
- Model-specific cloning and voice-design controls belong in the shared model settings modal through its extension builder, not in Home, Live TTS, or Dialog implementations.
- Model-setting extensions persist JSON-safe values such as reference-audio paths, preset IDs, style instructions, and tuning values under the selected model ID.
- Pocket TTS normal synthesis uses its bundled default reference clip when no cloning reference is configured.
- External OpenVoice and OmniVoice runtimes remain desktop-only and stay behind their backend service boundary.
- Backend configuration state is app-scoped so navigation does not reset enabled state, URLs, or connection progress.
- Enabled backends check health immediately and continue periodic health checks.
- OpenVoice and OmniVoice may use separate Python environments to avoid dependency conflicts.
- The backend API continues to use `GET /health`, `POST /jobs`, and job polling; OmniVoice may additionally expose `GET /voices`.
- Backend-generated WAV output is stored as generated audio and uses the same playback/export flow as local synthesis.
- Downloaded backend models and generated backend job artifacts are local runtime state and must stay out of git history.

## Current integration boundary

- The generic shared modal and extension-value storage are implemented.
- Speaker and language capabilities are derived directly from the shared model catalog.
- Backend enablement and URL configuration are exposed on `Backend models`.
- Concrete cloning-file pickers and voice-style extension builders still need to be registered by each desktop model-family integration before those controls appear in the generic modal.
