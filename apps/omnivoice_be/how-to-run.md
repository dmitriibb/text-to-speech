# How to Run the OmniVoice Backend

Use Python `3.10`.

Run these commands from `apps/omnivoice_be`:

```bash
~/.pyenv/versions/3.10.13/bin/python -m venv .venv
./.venv/bin/python -m pip install --upgrade pip setuptools wheel
./.venv/bin/python -m pip install -r requirements.txt
./.venv/bin/python -m src.main
```

Important:

- Start the backend with `./.venv/bin/python -m src.main`.
- Do not rely on plain `python -m src.main`, because that may use the wrong Python and fail with `ModuleNotFoundError: No module named 'fastapi'`.

Backend URL:

- `http://127.0.0.1:8010`

Health check:

- `http://127.0.0.1:8010/health`

Notes:

- First real request may download several GB of OmniVoice assets into the local Hugging Face cache.
- This backend is intentionally separate from `apps/open_voice_be` to avoid dependency conflicts with `MeloTTS` and `OpenVoice`.
