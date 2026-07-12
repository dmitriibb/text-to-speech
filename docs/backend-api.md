# Desktop Model Backend API

Desktop-only models that require an external runtime use the same asynchronous HTTP contract, even when each model runs in a separate Python environment or on a different machine.

## Endpoints

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

`POST /jobs` uses `multipart/form-data` so it can contain optional reference audio. Common fields are:

- `text`: required non-empty synthesis text
- `language`: language hint; a backend may ignore it when its model detects language automatically
- `speed`: common app speed value in the `0.5` to `2.0` range; a backend may report that its model does not support direct speed control
- `reference_audio`: optional uploaded audio file
- `settings`: a JSON object containing arbitrary model-specific settings

Backends must accept an empty `{}` settings object and apply documented model defaults. Settings must be persisted in the job record so a completed generation remains auditable. New model-specific controls belong inside `settings`; they must not change the common endpoint lifecycle.

The initial response is HTTP `202` with `job_id`, `status`, `status_url`, and `result_url`. The app polls the status URL until `succeeded` or `failed`, then downloads WAV output from the result URL.

## Runtime isolation

Each backend model currently has its own server directory and Python environment. This isolates incompatible Python, PyTorch, audio, CUDA, and ROCm dependencies. Keeping the HTTP contract identical allows compatible engines to be hosted by one combined backend later without changing the desktop generation flow.

