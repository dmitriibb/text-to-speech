# How to Run the OpenVoice Backend

Short setup guide for Windows, Ubuntu, and macOS.

This backend is currently intended for local manual startup while the desktop app connects to `http://127.0.0.1:8008`.

## 1. Install Python

Use Python `3.10`.

Make sure Python and `pip` are available in `PATH`, then verify:

```bash
python --version
pip --version
```

## 2. Install platform prerequisites

### Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y \
  python3.10 python3.10-venv python3-pip \
  ffmpeg build-essential
```

### Windows

- Install Python `3.10`
- Make sure `python` and `pip` work from PowerShell

Optional but recommended:

- install `ffmpeg` if you want it available for other local audio checks

### macOS

```bash
brew install python@3.10 ffmpeg
```

If `python` still points to a different version, use the explicit Homebrew path or `python3.10`.

## 3. Create a virtual environment

From this directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

```bash
python3.10 -m venv .venv
source .venv/bin/activate
```

## 4. Install Python dependencies

```powershell
python -m pip install --upgrade pip
pip install -r requirements.txt
.\.venv\Scripts\python -m pip install --no-deps git+https://github.com/myshell-ai/OpenVoice.git
```

```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
python -m pip install --no-deps git+https://github.com/myshell-ai/OpenVoice.git
```

The separate `--no-deps` install for `OpenVoice` is intentional.
It avoids the optional `faster-whisper` and `av` dependency chain, which this MVP does not use.

The current English-only MVP does not require the large `unidic` dictionary download step.

## 5. Start the backend

```powershell
python -m src.main
```

```bash
python -m src.main
```

Internally this still starts the FastAPI app through `uvicorn`, which is the ASGI web server used to expose the backend over HTTP.

If you prefer the explicit server command, the equivalent is:

```powershell
python -m uvicorn src.main:app --app-dir . --host 127.0.0.1 --port 8008
```

```bash
python -m uvicorn src.main:app --app-dir . --host 127.0.0.1 --port 8008
```

After startup, the desktop app should be able to reach:

- `GET http://127.0.0.1:8008/health`

## 6. First-run behavior

On first startup or first real job, the backend may download:

- OpenVoice model assets into `models/`
- tokenizer and text-processing assets used by MeloTTS

Because of that, the first successful request can take noticeably longer than later ones.

## Runtime data

The backend writes local runtime state under:

- `models/`
- `storage/`

These directories are local-only generated state and should not be committed to git.

## Troubleshooting

- Wrong Python version: use Python `3.10` explicitly when creating the virtual environment.
- `ModuleNotFoundError` after install: confirm the virtual environment is activated before running `python -m src.main`.
- OpenVoice install pulls extra media dependencies: make sure you used the separate `--no-deps` install command above.
- Desktop app cannot connect: confirm the backend is listening on `127.0.0.1:8008` and check `GET /health` in a browser or terminal.
