# Models Fix Note

Date: 2026-04-11
Repo: `c:\projects\text-to-speech`

## Why this note exists

This Windows checkout failed to build with a large cascade of Dart type errors such as:

- `Type 'VoiceModel' not found`
- `Type 'InstalledModel' not found`
- `Type 'LongRunningTask' not found`
- `Type 'ClonedVoice' not found`

The problem was not Visual Studio or the Windows Flutter toolchain. The repo content itself was incomplete on this checkout.

## Root cause

The repo had this rule in `.gitignore`:

```gitignore
models/
```

That pattern ignores any directory named `models` anywhere in the repository, not just the root `models/` folder meant for downloaded runtime assets.

Because of that, source directories like these were silently excluded from git:

- `packages/tts_core/lib/src/models/`
- `apps/desktop_app/lib/models/`

That explains why the code referenced shared model classes and desktop voice-cloning models that were missing from the Windows clone.

## .gitignore change made

Changed:

```gitignore
models/
```

to:

```gitignore
/models/
```

Meaning:

- `/models/` now ignores only the repo-root runtime models directory
- source directories named `models` inside `packages/...` or `apps/...` are no longer ignored

## Files added in this Windows fix

These files were created because they were referenced throughout the repo but missing from git in this checkout:

### Shared `tts_core` model files

- `packages/tts_core/lib/src/models/voice_model.dart`
- `packages/tts_core/lib/src/models/model_install_progress.dart`
- `packages/tts_core/lib/src/models/long_running_task.dart`

### Desktop-only model file

- `apps/desktop_app/lib/models/cloned_voice.dart`

## What these files contain

### `packages/tts_core/lib/src/models/voice_model.dart`

Restored shared data types used by both desktop and Android:

- `ModelCatalog`
- `ModelStatus`
- `InstalledModel`
- `Speaker`
- `VoiceModel`

This file is used by:

- model catalog parsing
- installed model status
- shared UI model panels
- speaker selection
- TTS runtime payload building

### `packages/tts_core/lib/src/models/model_install_progress.dart`

Restored install-progress types:

- `ModelInstallStage`
- `ModelInstallProgress`

This file is used by:

- desktop model installation flow
- Android model installation flow
- shared model-management UI
- install task status reporting

### `packages/tts_core/lib/src/models/long_running_task.dart`

Restored shared task lifecycle types:

- `LongRunningTaskType`
- `LongRunningTaskStatus`
- `LongRunningTask`
- `TaskRequest`
- `TaskResult`
- `TaskResultStatus`

This file is used by:

- isolate/background task execution
- task list UI
- generated audio persistence
- synthesis and model preload/install task management

### `apps/desktop_app/lib/models/cloned_voice.dart`

Restored the desktop-only voice cloning model:

- `ClonedVoice`

This file is used by:

- `apps/desktop_app/lib/screens/voice_lab_screen.dart`
- `apps/desktop_app/lib/state/voice_lab_state.dart`
- `apps/desktop_app/lib/services/voice_library_service.dart`

## Extra repo metadata updated

These files were also updated to record the fix:

- `flow-index.yaml`
  - added `apps/desktop_app/lib/models/cloned_voice.dart` under the `voice_cloning` flow
- `tasks/task-9-voice-cloning.md`
  - added a note explaining the `.gitignore` issue and the missing source files

## What to verify on Ubuntu

When you return to Ubuntu, check whether these files already exist locally but were never committed because of the old `.gitignore` rule:

```text
packages/tts_core/lib/src/models/voice_model.dart
packages/tts_core/lib/src/models/model_install_progress.dart
packages/tts_core/lib/src/models/long_running_task.dart
apps/desktop_app/lib/models/cloned_voice.dart
```

Also check the `.gitignore` rule there. If Ubuntu still has:

```gitignore
models/
```

then that checkout can still silently ignore these source files.

## Suggested Ubuntu verification steps

From the repo root on Ubuntu:

```bash
git status --short --untracked-files=all
git check-ignore -v packages/tts_core/lib/src/models/voice_model.dart
git check-ignore -v packages/tts_core/lib/src/models/model_install_progress.dart
git check-ignore -v packages/tts_core/lib/src/models/long_running_task.dart
git check-ignore -v apps/desktop_app/lib/models/cloned_voice.dart
```

Expected result after the fix:

- these source files should **not** be ignored
- `git check-ignore -v` should return nothing for them

To compare Ubuntu contents with what was restored here, inspect:

```bash
sed -n '1,240p' packages/tts_core/lib/src/models/voice_model.dart
sed -n '1,220p' packages/tts_core/lib/src/models/model_install_progress.dart
sed -n '1,260p' packages/tts_core/lib/src/models/long_running_task.dart
sed -n '1,220p' apps/desktop_app/lib/models/cloned_voice.dart
```

## Important conclusion

The original Windows build failure was caused by missing tracked source files, not by Windows support being broken.

The critical fix was:

1. narrow `.gitignore` from `models/` to `/models/`
2. restore the missing shared model source files
3. restore the desktop `ClonedVoice` source file

