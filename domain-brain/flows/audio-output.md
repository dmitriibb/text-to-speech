# Audio Output Flow

## Goal

Let the user hear or keep the generated audio after synthesis succeeds.

## Steps

1. App keeps the last generated `.wav` path in state.
2. Completed synthesis output writes both the `.wav` file and a lightweight generated-audio metadata record on local disk.
3. A separate local stats JSON file stores a per-model map keyed by model name with bounded aggregate generation metrics.
4. Desktop OpenVoice generation also writes its completed `.wav` into the same generated-audio flow so Home can list, play, export, and dismiss it just like local synthesis output.
5. On startup, apps that persist generated `.wav` files across sessions rehydrate existing files back into the task list so they can still be managed.
6. User expands a completed synthesis task and sees the audio name, generation time, and model used alongside shared playback controls.
7. The app plays exactly one generated audio at a time and exposes progress plus seeking.
8. Live mode plays one generated chunk at a time in order, promotes the next ready chunk immediately when playback finishes, and may keep later chunks generating in the background.
9. Live mode exposes play or pause for the current chunk and a separate stop action that halts playback, cancels further generation, and clears temporary chunk buffers.
10. Live-mode chunk `.wav` files are temporary playback buffers only; they are not restored into the persistent generated-audio task list.
11. The shared player pauses and resumes the currently loaded generated audio without resetting progress.
12. Before cancelling a task or removing generated audio from the task list, the app pauses active playback and asks for confirmation.
13. Desktop can export a copy through the task-row save action and Android can share the `.wav` through the system share sheet.
14. When the user confirms dismissing a generated-audio task, the app removes the task metadata and deletes that generated local `.wav`.

## Invariants

- Output actions operate on an existing generated local `.wav`.
- Generated audio metadata is persisted in local JSON, not only in memory, so completed audio can be restored with its name, timing, and model details.
- Desktop OpenVoice output must use the same generated-audio storage and task list as other completed speech so navigation away from Voice Lab does not orphan finished files.
- Generated audio metadata and stats storage must stay lightweight and local; no database is required for the current scope.
- Generated-audio stats aggregate per model name and update only when a speech generation completes successfully.
- Per-model stats track total input characters, total generation seconds, total output seconds, and derived per-100-character averages.
- Stored output-duration stats are normalized to speech speed `1.0`; UI output-length estimates adjust that baseline by the currently selected speech speed.
- Per-model stats cap aggregated character count at `1,000,000` while preserving the current averaged rates so the file stays bounded.
- Live mode still honors the single-active-audio rule; starting the next chunk replaces the previous chunk playback rather than overlapping it.
- Live-mode chunk buffer files are temporary and must be deleted when the live session stops or completes.
- If generated audio survives app restart on disk, the task list must restore an entry for it on startup so the user can delete it later.
- Task-row playback and output actions target the selected task's `.wav`, not just the most recent global output path.
- Only one generated audio may be active at a time across the app.
- Playback must expose play/pause plus a seekable progress position for the active audio.
- Resuming the same loaded audio must continue from the paused progress position unless playback had already reached the end.
- Interactive playback controls must remain responsive while audio is actively playing.
- Desktop Windows playback must control the currently loaded audio in-process so repeated play or seek actions replace or retarget that clip instead of layering overlapping playback.
- Playback and export/share are platform-specific service responsibilities behind a shared UI contract.
- Destructive task-row actions pause active playback before showing confirmation.
- Desktop task-row save must open a real save target and copy the generated `.wav` there.
- Output failures do not invalidate the already generated audio file.
- Dismissing a generated-audio task deletes its temporary generated file.
- App shutdown stops playback and cancels active background work.

## Failure Modes

- desktop audio playback failure
- Android audio playback failure
- Android playback controls queue until the clip finishes
- desktop export failure
- Android share failure
- generated-audio metadata JSON missing, stale, or corrupt
- destructive task action deletes audio without confirmation
- task-row output action targets the wrong generated file
- generated audio file remains on disk after its task is dismissed
- live-mode chunk buffers survive after the live session stops
