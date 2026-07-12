# VoxCPM2 Backend

Standalone FastAPI backend for `openbmb/VoxCPM2`. It uses the same desktop-facing job endpoints as the other model backends:

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

`POST /jobs` is multipart so an optional reference WAV can be uploaded. The `settings` form field contains a JSON object with model-specific settings. Supported VoxCPM2 keys include `style`, `prompt_text`, `use_reference_as_prompt`, `cfg_value`, `inference_timesteps`, `seed`, `normalize`, `denoise`, and retry controls.

Default URL: `http://127.0.0.1:8011`.

See `how-to-run.md` for environment and device setup.

