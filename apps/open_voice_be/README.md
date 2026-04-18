# OpenVoice Backend

Local FastAPI backend for the desktop app's OpenVoice integration.

## Current MVP scope

- Manual local startup by the user
- Async preview jobs with job IDs
- Official OpenVoice V2 tone-color conversion on CPU
- Official MeloTTS English-v2 as the base speaker model on CPU
- Disk-backed job metadata in `storage/jobs/*.json`
- Reference audio stored in `storage/reference_audio/*.wav`
- Result audio stored in `storage/results/*.wav`
- Health and capabilities endpoints for the desktop app

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
python -m unidic download
uvicorn src.main:app --app-dir . --host 127.0.0.1 --port 8008
```

The separate `--no-deps` install for OpenVoice is intentional on Windows.
It avoids the optional `faster-whisper` and `av` dependency chain, which is not needed for the current backend path because this MVP extracts speaker embeddings directly from the reference WAV instead of running OpenVoice VAD splitting.

The first English preview request may also download extra tokenizer and BERT assets used by the MeloTTS text pipeline, so the first successful job can take noticeably longer than later jobs.

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
- `GET /capabilities`
- `POST /jobs/clone-preview`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`
