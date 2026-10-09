advanced-planning

# AMD acceleration for Russian dialogue generation

Parent: [macro plan](plan.macro.md), stage M6. Progress: [checklist](plan.amd-acceleration.steps.md).

## Objective and boundary

Prove that the selected large Russian TTS engine generates the dialogue on this machine's Radeon RX 9070 XT, with stable audio and useful measured acceleration. Preserve the completed CPU/remote/clean-export workflow while evaluating GPU paths.

This is desktop Extended functionality. Flutter remains the frontend and the Python backend owns PyTorch device selection. Shared sherpa-onnx GPU builds, mobile GPU support, CUDA translation layers, custom kernel ports, and optimizing every model are outside this plan.

The entire workflow should run locally if this route passes. “Runs on AMD” means model inference uses that GPU; file I/O, UI, WAV assembly, and Audacity effects can run on the CPU.

## Research snapshot: 2026-10-09

- Observed locally: Windows 11 Pro `10.0.26200`, RX 9070 XT plus Radeon 780M, Windows driver `32.0.31041.1004`, about 28.8 GiB usable system RAM. RX 9070 XT's nominal 16 GB is from [AMD specifications](https://www.amd.com/en/products/graphics/desktops/radeon/9000-series/amd-radeon-rx-9070xt.html); probe real free VRAM later.
- AMD's [current unified compatibility page](https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html) and [versioned guide](https://rocm.docs.amd.com/en/docs-10.1.0/install/rocm.html) were served as ROCm 10.1.0. They cover Linux and Windows. Validate the exact GPU/OS/framework selection before installation.
- The earlier [Windows matrix](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/windows/windows_compatibility.html) explicitly lists RX 9070 XT and Python 3.12/PyTorch 2.9/ROCm 7.2.1; its banner says that documentation line ends at 7.2.1. It is historical support evidence, not the latest recommended stack.
- The earlier [WSL matrix](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/wsl/wsl_compatibility.html) also explicitly lists RX 9070 XT. Use a complete supported driver/Ubuntu/Python/PyTorch combination rather than copy its version numbers into a newer environment.
- [PyTorch HIP semantics](https://docs.pytorch.org/docs/main/notes/hip.html) explains that ROCm uses `torch.cuda` APIs. A `cuda:0` device string can describe an AMD GPU; inspect `torch.version.hip` and the device name to identify it.

Inference: native Windows ROCm is now a realistic first trial for this hardware. The repo's current “Windows: CPU fallback” guide is incomplete. None of these sources certifies VoxCPM2, its optional denoiser/text normalization/optimization, or another TTS pipeline on this exact stack. No driver/software changes or GPU synthesis were performed during planning.

## Route selection and decisions

1. Try official native Windows ROCm/PyTorch in a separate environment first; it has the simplest connection to the current desktop app.
2. If required packages/operators are unavailable or unstable, move only the backend to supported WSL2 Ubuntu. The Flutter UI still runs on Windows and calls the same HTTP API.
3. Use native supported Linux or an existing second machine only when Windows/WSL fail; that is a fallback, not an assumed requirement to reinstall the user's OS or buy hardware.

Select one model at a time, batch/concurrency one, eager inference, and no optional NVIDIA-specific FlashInfer/FlashAttention/Triton optimization until a real baseline passes. FP16/BF16 support must be demonstrated by this pipeline; upstream defaults alone do not establish support or better quality. Keep a slower FP32/CPU diagnostic path where available.

The selected model environment must remain isolated from other backends. Installing its requirements must not silently replace the ROCm wheel with CPU/CUDA Torch. An HTTP health response or loadable HIP DLL is insufficient evidence of working accelerated inference.

## Ordered implementation steps

### G1 — Inventory the real machine and select an official stack

Read GPU IDs, OS build/edition, driver package version, free disk/RAM/VRAM, available Python versions, existing Torch environments, and WSL distributions without changing the system. Select the discrete RX 9070 XT explicitly rather than accidentally use the 780M.

Use the current AMD selectors for the exact card, Windows/WSL version, and framework. Record driver, Python, ROCm core components, Torch, audio libraries, TTS package, model revision, and all install sources. Prefer a tested supported combination over mixing the newest version of every component. Account for model download plus caches and environment space; verify disk demand rather than promise an exact estimate.

Verification: the chosen stack has authoritative compatibility references and a saved inventory. If a driver change/restart is necessary, record the concrete requirement before performing it during implementation; planning has not authorized arbitrary OS replacement.

### G2 — Create an isolated environment and prove PyTorch GPU execution

Install the official AMD runtime/Torch packages for the selected route, then compatible model dependencies with constraints/lock data. Recheck Torch after installation. Avoid the generic NVIDIA CUDA wheel index and the old hard-coded `rocm6.4` command in the repo guide.

Save a small probe report with `torch.__version__`, `torch.version.hip`, `torch.cuda.is_available()`, all device names, selected device index, GPU memory properties, and relevant dtype support. Run and synchronize a nontrivial GPU tensor operation; verify its result and memory allocation. Record import/operator failures with exact versions.

Verification: PyTorch demonstrably computes on RX 9070 XT with a HIP build; no claim of TTS compatibility yet.

### G3 — Prove the selected Russian TTS pipeline on AMD

Run the D2 smoke script and fixed actor references on the GPU. For VoxCPM2, begin with `VOXCPM_DEVICE=auto` or a verified `cuda:N` index, `VOXCPM_OPTIMIZE=false`, and `VOXCPM_LOAD_DENOISER=false`. Examine returned `device_backend` plus real tensor/device/profiler evidence; a successful request may otherwise conceal initialization CPU fallback.

Test model loading, reference encoding, generation, decoder, sample rate, and WAV writing. Validate actual installed upstream signatures/settings instead of assuming mock tests prove them. Compare output words/identity against the CPU samples; investigate unsupported operators, NaN samples, and dtype errors before enabling extras.

If native Windows fails because of a concrete dependency/operator problem, try the officially supported WSL stack with the same model API and actor assets. Upload reference bytes, not Windows file paths. Test Windows-to-WSL health, submit, polling, and result download using a reachable URL. Record the failed route and working route; avoid endless wheel/version switching.

Verification: real Russian line WAVs for both actors, actual AMD execution evidence, valid audio, and a recorded complete working version tuple. If every supported route fails, leave the item unchecked with the concrete blocker.

### G4 — Expose actual device state and graceful fallback

Extend backend health/result metadata where needed with requested and effective device/backend, selected GPU name, loaded state, runtime versions, and fallback reason. Surface this in the desktop Backend models settings so CPU fallback is visible. Reuse VoxCPM2's existing automatic fallback without overstating coverage: it currently retries GPU initialization on CPU, not every inference-time error.

Allow Auto/CPU and validated GPU choice at the backend boundary. Changing device must drain/cancel queued requests and reload predictably; it must not mutate a live shared model underneath an in-flight job. Clear/report failed load state and protect the app from endless retries. An inference OOM should fail the affected turn with an actionable error; retry/fallback must not silently duplicate successful output.

Keep the local sherpa provider selection separate: it configures a different runtime and cannot prove Python backend acceleration. Do not add “ROCm” to that dropdown as a substitute for this backend work.

Verification: normal AMD jobs identify the GPU; unavailable acceleration and initialization failure visibly select CPU; task state/retry/cancellation and healthy local synthesis remain correct.

### G5 — Measure and tune one stable configuration

Benchmark the same Russian fixture and fixed actor profiles on CPU and GPU. Separate cold model load/download from warm inference; run at least three warm repeats for short and longer turns. Record medians, generated audio seconds, real-time factor (generation seconds / audio seconds), peak VRAM/system memory, failure count, and quality comments.

Keep one loaded model and concurrency one first. Verify memory returns to a stable level across a two-person and short three-person job sequence; actors should reuse one model rather than load a copy per voice. Test a longer approximately 10-minute output workload in sequential turns.

Only then compare supported precision, diffusion steps, prompt caching, or optimization one change at a time. Reject changes that introduce pronunciation/identity failures or exceed safe available VRAM. Do not promise NVIDIA benchmark speed or a particular speedup. No mandatory real-time requirement is implied by this offline export goal.

Verification: a useful, stable AMD configuration has measured CPU/GPU results and passes the same audio quality gate. If GPU computes correctly but is slower, document it plainly and keep tuning unfinished as appropriate.

### G6 — Finish setup documentation and end-to-end GPU acceptance

Replace the outdated Windows-only-CPU wording in `apps/voxcpm2_be/how-to-run.md` when that engine is selected. Write the tested official install commands and environment lock/constraints, including native Windows or WSL connection/reference-upload details. For a different selected engine, update its corresponding backend guide.

Generate and export the accepted Russian conversation through the desktop app on RX 9070 XT, then reproduce the accepted Audacity effect from the clean master. Save GPU evidence, setup versions, benchmark report, and limitations; confirm an independent restart of the backend still works.

Update relevant voice-cloning/device/fallback domain-brain notes, backend API documentation, and `flow-index.yaml` for changed files. Archive completed task records immediately. Mark macro M6 complete only after actual model-level GPU proof and a reproducible working route, not merely official hardware support.

Verification: the user can repeat the local GPU workflow using the guide; CPU fallback remains available; no mobile Python/GPU parity is claimed for this Extended feature.
