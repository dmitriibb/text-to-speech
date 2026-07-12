# OmniVoice Backend

Local FastAPI backend for desktop Voice Lab when you want a separate OmniVoice-only Python environment.

This backend keeps the same desktop-facing job API shape as the existing backend path:

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

Default local URL:

- `http://127.0.0.1:8010`

`POST /jobs` follows the common desktop backend contract and accepts a `settings` form field containing a JSON object. OmniVoice settings may include `voice_id`, `reference_text`, `instruct`, `duration`, and `num_step`; the legacy flat fields remain accepted for compatibility.

Platform-specific startup steps live in `how-to-run.md`.
