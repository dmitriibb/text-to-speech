# OpenVoice Backend

Local FastAPI backend for the desktop app's OpenVoice integration.

Platform-specific startup steps live in `how-to-run.md`.

## Current MVP scope

- Manual local startup by the user
- Async speech jobs with job IDs
- Official OpenVoice V2 tone-color conversion on CPU
- Official MeloTTS English-v2 as the base speaker model on CPU
- Desktop-controlled speech speed forwarded through the job API
- Disk-backed job metadata in `storage/jobs/*.json`
- Reference audio stored in `storage/reference_audio/*.wav`
- Result audio stored in `storage/results/*.wav`
- Health endpoint for the desktop app

## Current limitations

- English only for the first MVP
- Manual local startup only
- First startup may take time because the backend downloads model assets into `models/`

## Run locally

```powershell
cd apps/open_voice_be
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
.\.venv\Scripts\python -m pip install --no-deps git+https://github.com/myshell-ai/OpenVoice.git
python -m src.main
```

The separate `--no-deps` install for OpenVoice is intentional on Windows.
It avoids the optional `faster-whisper` and `av` dependency chain, which is not needed for the current backend path because this MVP extracts speaker embeddings directly from the reference WAV instead of running OpenVoice VAD splitting.

The current English-only MVP does not require the large `unidic` dictionary download step.

`python -m src.main` is the preferred local entrypoint.
Internally it still starts the FastAPI app through `uvicorn`, which is the ASGI web server used to expose the backend over HTTP.

The first English speech request may also download extra tokenizer and BERT assets used by the MeloTTS text pipeline, so the first successful job can take noticeably longer than later jobs.

## Model layout

The backend downloads and keeps model assets under `models/`.
These files are local runtime state and should not be committed to git.

```text
models/
  checkpoints_v2/
    converter/
      checkpoint.pth
      config.json
    base_speakers/
      ses/
        en-default.pth
        en-us.pth
        en-br.pth
        en-au.pth
        en-india.pth
  melotts/
    english-v2/
      checkpoint.pth
      config.json
```

## Storage layout

```text
storage/
  jobs/
    <job-id>.json
  reference_audio/
    <job-id>.wav
  results/
    <job-id>.wav
  presets/
```

Everything under `storage/` is generated local runtime data and should not be committed to git.

## API

- `GET /health`
- `POST /jobs`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`

`POST /jobs` accepts multipart form fields:
- `text`
- `language`
- `speed` in the `0.5` to `2.0` range
- `reference_audio`
