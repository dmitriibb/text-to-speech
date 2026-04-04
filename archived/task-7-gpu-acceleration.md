# GPU Acceleration Toggle (Extended – Desktop Only)

## Goal

Let the desktop user choose between CPU and GPU inference so that synthesis on machines with a supported GPU is significantly faster, especially for larger models like Kokoro.

## Current Status

Not started.

## Context

- `VoiceModel.provider` already flows into `OfflineTtsModelConfig.provider`. All catalog entries set `"cpu"` today.
- sherpa_onnx supports provider strings: `"cpu"`, `"cuda"`, `"rocm"`, `"coreml"`, `"directml"`.
- The desktop target platforms are Linux (primary) and Windows (secondary).
  - Linux AMD → ROCm (`"rocm"`)
  - Linux NVIDIA → CUDA (`"cuda"`)
  - Windows AMD → DirectML (`"directml"`)
  - Windows NVIDIA → CUDA (`"cuda"`)
- GPU provider availability depends on the sherpa_onnx native library build. The default Dart/Flutter package may ship CPU-only. A GPU-enabled build or a separate native library may be required.

## Scope

### In Scope

1. **GPU detection utility** — detect which GPU providers are available at runtime. Approach options:
   - Try creating a model with a given provider and see if it fails (practical but slow).
   - Check for CUDA/ROCm shared libraries on the system (`libcudart.so`, `libamdhip64.so`).
   - Ship a small probe that calls ONNX Runtime's `GetAvailableProviders()`.
2. **Provider selection UI** — add a dropdown or toggle in the desktop `SettingsPanel`: CPU / CUDA / ROCm (only showing available options). Default: CPU.
3. **Runtime provider switching** — when the user changes provider, reload the current model with the new provider. This means re-submitting a model preload task.
4. **Persist preference** — save the selected provider to local storage so it survives app restarts.
5. **Error handling** — if GPU init fails (driver mismatch, out of VRAM), fall back to CPU and show a clear message.

### Out of Scope

- Building custom sherpa_onnx native libraries (document what's needed, but don't set up CI for it).
- Mobile GPU (not planned).
- Benchmarking CPU vs GPU (useful but separate effort).

## Implementation Steps

1. Research: confirm which sherpa_onnx Flutter/Dart builds include GPU providers. Check if the pub.dev package ships GPU-enabled binaries or if a custom build is needed.
2. Create `GpuDetector` utility in `apps/desktop_app/lib/services/` that probes for available providers.
3. Add provider state to `AppState`: `availableProviders` list, `selectedProvider` string.
4. Extend `SettingsPanel` with a provider dropdown (only shown on desktop, only listing detected providers).
5. On provider change: update `AppState.selectedProvider`, trigger model reload with new provider.
6. Pass `selectedProvider` through to `TaskManager.submitSynthesis()` and `submitModelPreload()` (override the catalog's default provider).
7. Add local persistence (shared_preferences or a simple JSON file) for the provider choice.
8. Add error handling: catch provider init failures, reset to CPU, show error banner.

## Blockers

- Unknown: does the standard `sherpa_onnx` pub.dev package include GPU provider support, or is a custom native build required?
- Depends on task 6 being useful (GPU acceleration matters most for larger models like Kokoro).

## Next Steps

Start with step 1 (research sherpa_onnx GPU provider availability).
