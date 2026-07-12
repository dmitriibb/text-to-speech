# VoxCPM2 Support

## Goal

Implement support for `openbmb/VoxCPM2`, add the model, and document how to run it.

## Current Status

Not started.

## Scope

- Decide the integration shape:
  - Preferred: desktop extended backend service because VoxCPM2 is a Python/PyTorch model and is much heavier than the shared sherpa-onnx runtime.
  - Optional: remote HTTP backend running on another GPU machine.
- Add a desktop backend client/service abstraction for VoxCPM2 generation.
- Add model metadata for `openbmb/VoxCPM2` with clear runtime requirements:
  - Python >= 3.10
  - PyTorch >= 2.5
  - CUDA >= 12.0
  - about 8 GB VRAM
  - Apache-2.0 license
  - German supported
- Add UI wiring that keeps the normal Dialog flow usable while routing VoxCPM2 generation through the backend.
- Add generated WAV files back into the same generated-audio store/task flow.
- Add documentation for local and remote operation:
  - installing `voxcpm`
  - downloading `openbmb/VoxCPM2`
  - running the backend service
  - configuring the desktop app to point at a remote GPU machine
  - firewall/network notes for LAN usage
- Update domain-brain notes, architecture notes if a new backend boundary is introduced, and tests.

## Remote GPU Note

The user's second machine with a 16 GB GPU is a good fit for this. LM Studio itself is unlikely to be enough because VoxCPM2 is not a normal text-completion model; it needs a TTS-specific pipeline that returns audio. The practical route is to run a small VoxCPM2 HTTP service on that GPU machine and let the desktop app call it.

## Verification

- Backend unit tests for request validation and output file handling
- Desktop app tests for backend configuration and task state
- Manual German generation through the remote backend
- Documentation smoke test from a clean environment
