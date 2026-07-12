# Clear Generated Speech History

## Goal

Add a confirmed Clear all action above the task list that removes every task and its generated speech audio from local disk.

## Current Status

Complete.

## Delivered

- Added the shared task-list control and confirmation dialog.
- Wired the same cleanup behavior into desktop and Android app state.
- Cancels active managed work, clears persisted generated-audio records, deletes generated WAV files, and removes late-result output files.
- Added coverage for confirmation, persisted cleanup, and late task results.

## Verification

- `flutter test` in `packages/tts_core`
- `flutter test` in `packages/shared_ui`
- `flutter analyze` in `apps/android_app`

## Note

Desktop analysis still reports pre-existing diagnostics in Voice Lab/OpenVoice files outside this task.
