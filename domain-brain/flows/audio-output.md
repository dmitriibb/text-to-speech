# Audio Output Flow

## Goal

Let the user hear or keep the generated audio after synthesis succeeds.

## Steps

1. App keeps the last generated `.wav` path in state.
2. User expands a completed synthesis task and uses shared playback controls.
3. The app plays exactly one generated audio at a time and exposes progress plus seeking.
4. Desktop can export a copy through the task-row save action and Android can share the `.wav` through the system share sheet.
5. When the user dismisses a generated-audio task, the app removes the task metadata and deletes that generated local `.wav`.

## Invariants

- Output actions operate on an existing generated local `.wav`.
- Task-row playback and output actions target the selected task's `.wav`, not just the most recent global output path.
- Only one generated audio may be active at a time across the app.
- Playback must expose play/stop plus a seekable progress position for the active audio.
- Playback and export/share are platform-specific service responsibilities behind a shared UI contract.
- Desktop task-row save must open a real save target and copy the generated `.wav` there.
- Output failures do not invalidate the already generated audio file.
- Dismissing a generated-audio task deletes its temporary generated file.
- App shutdown stops playback and cancels active background work.

## Failure Modes

- desktop audio playback failure
- Android audio playback failure
- desktop export failure
- Android share failure
- task-row output action targets the wrong generated file
- generated audio file remains on disk after its task is dismissed
