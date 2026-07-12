# Qwen3 TTS Support

## Goal

Implement support for Qwen3-TTS German generation.

## Current Status

Not started.

## Scope

- Decide which Qwen3-TTS model variant to support first:
  - `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice`
  - `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice`
  - `Qwen/Qwen3-TTS-12Hz-0.6B-Base`
  - `Qwen/Qwen3-TTS-12Hz-1.7B-Base`
- Decide the integration shape:
  - desktop extended backend service, or
  - remote HTTP backend running on another GPU machine.
- Add backend configuration for model path, host, port, timeout, and default German voice/style.
- Add support for German text generation and, if selected, preset voice/style selection.
- Route generated audio into the same generated-audio store/task flow.
- Document setup, model download, runtime requirements, and remote GPU deployment.
- Add licensing notes. Current upstream license is Apache-2.0, but each selected checkpoint should be verified before adding it to the catalog.
- Update domain-brain notes and tests.

## Remote GPU Note

The user's 16 GB GPU machine may be useful here, especially for the 1.7B variants. LM Studio may help only if there is a compatible Qwen3-TTS GGUF/runtime that exposes the audio-token pipeline; otherwise use a dedicated Qwen3-TTS backend service.

## Verification

- Backend service unit tests
- Desktop app tests for backend configuration and task flow
- Manual German generation with the selected Qwen3-TTS variant
- Documentation smoke test from a clean environment
