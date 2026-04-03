# How to Run the Desktop App

This guide covers building and running the desktop app on Ubuntu, Windows, and macOS, including how to get voice models.

## 1. Install Flutter

Install the Flutter SDK (stable channel) for your platform.

Official install guide: https://docs.flutter.dev/get-started/install

### Ubuntu

```bash
# Option A: snap (quick, but may cause LLVM linker issues — see Troubleshooting)
sudo snap install flutter --classic

# Option B: git clone (recommended)
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Enable the Linux desktop target:

```bash
flutter config --enable-linux-desktop
flutter doctor
```

### Windows

Download the Flutter SDK from https://docs.flutter.dev/get-started/install/windows/desktop and add it to your PATH.

Enable the Windows desktop target:

```powershell
flutter config --enable-windows-desktop
flutter doctor
```

Visual Studio with the "Desktop development with C++" workload is required. Follow the `flutter doctor` prompts.

### macOS

```bash
# Option A: download from https://docs.flutter.dev/get-started/install/macos/desktop
# Option B: git clone
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Enable the macOS desktop target:

```bash
flutter config --enable-macos-desktop
flutter doctor
```

Xcode and CocoaPods are required. Follow the `flutter doctor` prompts.

## 2. Install System Dependencies

### Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-plugins-good \
  lld \
  ffmpeg \
  zenity
```

What each group provides:

| Packages | Purpose |
|---|---|
| clang, cmake, ninja-build, pkg-config | C/C++ build toolchain for Flutter Linux |
| libgtk-3-dev, liblzma-dev | GTK3 for Flutter desktop windows |
| libgstreamer\* | GStreamer (optional, for future audio plugins) |
| lld | LLVM linker (needed if using Flutter snap) |
| ffmpeg | Audio playback via `ffplay` |
| zenity | Native GTK file-save dialog |

### Windows

- Visual Studio 2022 with "Desktop development with C++" workload
- No additional system packages needed; audio and file dialogs use built-in Windows APIs

### macOS

- Xcode (from App Store)
- CocoaPods: `sudo gem install cocoapods`
- No additional system packages needed; audio uses built-in macOS APIs

## 3. Clone and Build

```bash
git clone <repo-url> text-to-speech
cd text-to-speech/apps/desktop_app
flutter pub get
```

### Run in development mode

```bash
# Ubuntu
flutter run -d linux

# Windows
flutter run -d windows

# macOS
flutter run -d macos
```

### Build a release binary

```bash
# Ubuntu
flutter build linux

# Windows
flutter build windows

# macOS
flutter build macos
```

Build output locations:

| Platform | Path |
|---|---|
| Linux | `build/linux/x64/release/bundle/desktop_app` |
| Windows | `build\windows\x64\runner\Release\desktop_app.exe` |
| macOS | `build/macos/Build/Products/Release/desktop_app.app` |

## 4. Download Voice Models

The app needs at least one voice model to generate speech. Models are downloaded once and used offline.

### Option A: Download from within the app

When no model is detected, the app shows a banner with download buttons for each available voice. Click the button and wait for the download and extraction to complete.

### Option B: Download manually

Models are hosted on the sherpa-onnx GitHub releases page.

#### Available models

| Model | Display Name | Archive URL | Size |
|---|---|---|---|
| `vits-piper-en_US-lessac-medium` | Piper English Lessac Medium | [Download](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2) | ~75 MB |
| `vits-ljs` | VITS LJSpeech | [Download](https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-ljs.tar.bz2) | ~75 MB |

Full model list from the sherpa-onnx project: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html

#### Manual download steps (Linux/macOS)

```bash
# Download and extract to the app's model directory
mkdir -p ~/.local/share/text-to-speech/models
cd ~/.local/share/text-to-speech/models

# Piper Lessac Medium (recommended starting voice)
wget https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2
tar xjf vits-piper-en_US-lessac-medium.tar.bz2
rm vits-piper-en_US-lessac-medium.tar.bz2
```

#### Manual download steps (Windows PowerShell)

```powershell
# Download and extract to the app's model directory
$modelsDir = "$env:APPDATA\text-to-speech\models"
New-Item -ItemType Directory -Force -Path $modelsDir
Set-Location $modelsDir

# Download
Invoke-WebRequest -Uri "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2" -OutFile "vits-piper-en_US-lessac-medium.tar.bz2"

# Extract (requires tar, available on Windows 10+)
tar xjf vits-piper-en_US-lessac-medium.tar.bz2
Remove-Item vits-piper-en_US-lessac-medium.tar.bz2
```

### Option C: Use the Phase 0 workspace models (development)

If you already ran the Phase 0 validation, the model at `models/vits-piper-en_US-lessac-medium/` in the repo root is auto-detected when running from the project directory.

### Custom model path

Set the `TTS_MODELS_PATH` environment variable to point to any directory containing extracted model folders:

```bash
TTS_MODELS_PATH=/path/to/my/models flutter run -d linux
```

## 5. Model Directory Structure

After extraction, each model directory should look like this:

```
vits-piper-en_US-lessac-medium/
  en_US-lessac-medium.onnx    # ONNX model file
  tokens.txt                   # Token vocabulary
  espeak-ng-data/              # Phonemizer data directory
  MODEL_CARD                   # Model metadata (optional)
```

The app checks for the `.onnx` model file, `tokens.txt`, and `espeak-ng-data/` directory to confirm a model is ready.

## 6. Model Search Paths

The app looks for models in these locations, in order:

| Priority | Path | Notes |
|---|---|---|
| 1 | `TTS_MODELS_PATH` env var | Custom override |
| 2 | `~/.local/share/text-to-speech/models/` (Linux) | Platform standard |
| 2 | `%APPDATA%\text-to-speech\models\` (Windows) | Platform standard |
| 3 | Workspace `models/` directory | Auto-detected for development |

## Troubleshooting

### Flutter snap LLVM linker error on Ubuntu

If you see `Failed to find any of [ld.lld, ld]` when building, install the LLVM linker:

```bash
sudo apt-get install -y lld
```

Or switch from the snap install to a git-based Flutter install (recommended).

### No audio playback on Linux

The app uses `ffplay` (from ffmpeg) or `aplay` (from alsa-utils) for audio playback. Install one of them:

```bash
sudo apt-get install -y ffmpeg
# or
sudo apt-get install -y alsa-utils
```

### Save dialog does not appear on Linux

The save dialog uses `zenity`. Install it if missing:

```bash
sudo apt-get install -y zenity
```

### macOS: platform not yet validated

The app is designed for Linux and Windows. macOS may work via Flutter's desktop support, but it has not been tested. The `sherpa_onnx` Flutter package does include macOS binaries.
