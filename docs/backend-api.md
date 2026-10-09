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

VoxCPM2 with `voxcpm==2.0.3` accepts only `speed=1.0`; other speeds receive
HTTP 400 before dispatch because no speed control is implemented. Its language
field is metadata/hint and does not force generation language. Normalization
defaults off. Seed handling uses scoped Torch RNG rather than an unsupported
native generation argument, and inference is serialized per engine instance.

## Runtime isolation

Each backend model currently has its own server directory and Python environment. This isolates incompatible Python, PyTorch, audio, CUDA, and ROCm dependencies. Keeping the HTTP contract identical allows compatible engines to be hosted by one combined backend later without changing the desktop generation flow.


### VoxCPM2 Dialog lifecycle

Health now includes `current_model_revision`. `VOXCPM_MODEL_REVISION` defaults to
`32279effe8c19989596f05d353d1447f51d9e915`; the engine resolves that snapshot before
calling the pinned runtime. An actor can send `settings.model_revision`; mismatches
return 409. VoxCPM2 accepts speed 1.0 only and infers language from text.

`DELETE /jobs/{job_id}` returns 204 (404 for unknown jobs). Queued jobs do not run;
running kernels may finish, but their reference/result/record are then deleted
and cannot reappear. Jobs execute sequentially per server/engine. The desktop
adapter uses 15-second health/poll, 30-second submission, 60-second download waits,
a 30-minute polling deadline, and cancellation checks between waits/chunks.
Reference upload is bounded to 64 MiB and output downloads to 128 MiB. Abandoned
server records/references/results expire after seven days at startup; durable
app-owned copies do not depend on those records.
