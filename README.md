# text-to-speech

Local-first text-to-speech monorepo for:

- a desktop app on Ubuntu and Windows
- an Android app (planned)

The current repository state is **Phase 1: Desktop MVP**. The desktop app synthesizes English speech locally using `sherpa-onnx` with no cloud APIs.

## Getting started

See **[docs/how-to-run.md](docs/how-to-run.md)** for full setup instructions covering Ubuntu, Windows, and macOS, including Flutter installation, system dependencies, and model downloads.

Quick version (Ubuntu, after installing Flutter and system deps):

```bash
cd apps/desktop_app
flutter pub get
flutter run -d linux
```

## Repository layout

```text
apps/
  desktop_app/       Flutter desktop app (Phase 1 MVP)
  android_app/       (planned)

docs/
  how-to-run.md      Setup and run instructions
  architecture.md    Architecture overview
  licensing.md       Model licensing status

packages/
  model_catalog/     Approved model catalog (JSON)
  quality_suite/     (planned)
  shared_ui/         (planned)
  tts_core/          (planned)

tools/
  benchmark/         Phase 0 validation harness
  model_fetch/       Phase 0 model download script
  release/           (planned)
```

## Phase 0 quick start (validation harness)

The Phase 0 Python validation harness is still available. Flutter is **not** required for Phase 0.

### 1. Create a virtual environment

Linux/macOS:

```bash
python3 -m venv .venv
. .venv/bin/activate
```

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 2. Install CPU-only `sherpa-onnx`

Official source:

- https://k2-fsa.github.io/sherpa/onnx/python/install.html

Linux/macOS:

```bash
pip install --upgrade pip
pip install sherpa-onnx sherpa-onnx-bin --no-index -f https://k2-fsa.github.io/sherpa/onnx/cpu.html
```

Windows:

```powershell
pip install --upgrade pip
pip install sherpa-onnx sherpa-onnx-bin --no-index -f https://k2-fsa.github.io/sherpa/onnx/cpu.html
```

### 3. Download the Phase 0 model

```bash
python3 tools/model_fetch/fetch_approved_model.py --model-id vits-piper-en_US-lessac-medium
```

### 4. Run the validation harness

Quick benchmark:

```bash
python3 tools/benchmark/run_phase0_validation.py --model-id vits-piper-en_US-lessac-medium --benchmark-set quick
```

Full benchmark:

```bash
python3 tools/benchmark/run_phase0_validation.py --model-id vits-piper-en_US-lessac-medium --benchmark-set full
```

The harness writes `.wav` files and a JSON report to `artifacts/phase0/`.

### 5. Run the repo checks

```bash
python3 -m unittest discover -s tests -v
```

## Current model policy

- Runtime choice: `sherpa-onnx`
- Phase 0 default validation model: `vits-piper-en_US-lessac-medium`
- Distribution approval for bundled voices: **not finalized yet**

See [docs/licensing.md](/home/dmitrii/projects/text-to-speech/docs/licensing.md) for the current status and what is still Unknown.

