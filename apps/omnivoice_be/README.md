# OmniVoice Backend

Local FastAPI backend for desktop Voice Lab when you want a separate OmniVoice-only Python environment.

This backend keeps the same desktop-facing job API shape as the existing backend path:

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

Default local URL:

- `http://127.0.0.1:8010`

Platform-specific startup steps live in `how-to-run.md`.
