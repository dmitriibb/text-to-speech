# VoxCPM2 Backend

Standalone FastAPI backend for `openbmb/VoxCPM2`. It uses the same desktop-facing job endpoints as the other model backends:

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

`POST /jobs` is multipart so an optional reference WAV can be uploaded. The `settings` form field contains a JSON object with model-specific settings. Supported VoxCPM2 keys include `style`, `prompt_text`, `use_reference_as_prompt`, `cfg_value`, `inference_timesteps`, `seed`, `normalize`, `denoise`, and retry controls.

Default URL: `http://127.0.0.1:8011`.

See `how-to-run.md` for environment and device setup.

Inference runs sequentially per loaded engine. With pinned `voxcpm==2.0.3`,
`seed` is implemented through a scoped Torch CPU/CUDA/ROCm RNG, since that
version has no native `generate(seed=...)` parameter. References remain necessary
for actor identity. Text normalization defaults off; enable it explicitly only
after checking that it preserves the intended pronunciation for your language.
The pinned model has no speaking-speed argument. Until tested speed processing
exists, the API accepts only `speed=1.0` and rejects other values explicitly.
`language` remains a hint in the job record; pronunciation is inferred from text.

The Russian evaluation fixture/runner is documented in
[`packages/quality_suite/README.md`](../../packages/quality_suite/README.md).

