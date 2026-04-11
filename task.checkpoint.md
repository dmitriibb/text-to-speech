# Task Checkpoints

## Checkpoint 1
- Changed `packages/tts_core/lib/src/services/tts_service.dart` so Pocket TTS regular generation no longer calls the runtime without reference audio, which was producing empty WAV files
- Added Pocket default-reference metadata in `packages/tts_core/lib/src/models/voice_model.dart` and in the catalog assets at `packages/model_catalog/approved_models.json`, `apps/desktop_app/assets/approved_models.json`, and `apps/android_app/assets/approved_models.json`
- Added automatic fallback to the bundled `test_wavs/bria.wav` reference clip for normal Pocket TTS speech generation when voice cloning is off
- Updated `packages/tts_core/lib/src/services/model_file_validator.dart` so Pocket installs now require the bundled default reference asset to be present before the model is treated as ready
- Removed the old silent-success path by making `packages/tts_core/lib/src/services/tts_service.dart` fail when synthesis returns zero samples instead of saving fake audio
- Updated `packages/tts_core/test/tts_core_test.dart` to cover the new Pocket readiness rule and default-reference requirement
- Updated `domain-brain/flows/local-synthesis.md`, `domain-brain/flows/model-catalog-and-approval.md`, `domain-brain/flows/voice-cloning.md`, `domain-brain/entities/voice-model.md`, and `tasks/task-9-voice-cloning.md` to document the new Pocket behavior

## Checkpoint 2
- Revised the Pocket fallback fix so model task payloads now preserve `pocketDefaultReferenceAudio` and `defaultSpeakerId` across background synthesis boundaries
- Centralized task payload encoding and decoding in `packages/tts_core/lib/src/services/voice_model_task_payload.dart` so shared and desktop executors reconstruct identical `VoiceModel` data
- Updated `packages/tts_core/lib/src/services/isolate_task_executor.dart`, `packages/tts_core/lib/src/services/task_manager.dart`, and `apps/desktop_app/lib/services/desktop_task_executor.dart` to use the shared codec
- Added a `tts_core` test that round-trips Pocket task payload metadata, preventing future regressions where isolate synthesis loses the bundled reference clip

## Checkpoint 3
- Changed generated-audio task-row playback from play/stop to play/pause in `shared_ui`, including destructive-action confirmation before removing generated WAV files
- Updated desktop and Android app state so replaying the same generated task audio resumes from the paused position instead of resetting progress
- Added explicit `pause()` handling to the Android and desktop audio services while keeping full stop for reset, removal, generation start, and shutdown paths
- Updated the audio-output domain docs and playback lifecycle state machine to document pause/resume semantics and confirmation-before-delete behavior
- Added `packages/shared_ui/test/task_list_panel_test.dart` to cover the pause button and the pause-before-remove confirmation flow

## Checkpoint 4
- Refactored `apps/android_app/lib/services/audio_service.dart` so Android no longer blocks pause, seek, or cancel-triggered pause behind the long-lived `just_audio` playback future
- Added `apps/android_app/lib/services/audio_player_backend.dart` to isolate the `just_audio` adapter behind a testable backend interface
- Revised Android seek semantics so moving the progress slider while paused keeps the player paused instead of flipping it back to stopped
- Added `apps/android_app/test/audio_service_test.dart` to cover non-blocking play, immediate pause, and paused seek behavior
- Updated the audio-output domain docs to explicitly require responsive playback controls during active audio playback

## Checkpoint 5
- Narrowed the shared speech-speed range to `0.5x` through `2.0x` in `tts_core` and applied the same clamp in desktop, Android, and background synthesis paths
- Moved the shared voice, speaker, and speed controls into `packages/shared_ui/lib/src/widgets/voice_settings_controls.dart` so both apps use the same basic settings UI
- Added Android speaker selection state and passed the selected Kokoro speaker ID into synthesis tasks instead of always using the model default
- Updated the local-synthesis domain docs and flow index to document cross-platform multi-speaker controls and the new supported speed range
- Added `apps/android_app/test/settings_panel_test.dart` plus a `tts_core` speed-range test, and re-ran tests and analyzers across `tts_core`, `shared_ui`, `desktop_app`, and `android_app`

## Checkpoint 6
- Confirmed Android synthesis writes generated WAV files under the app support directory in `generated_audio/`, while the task list was previously memory-only and lost them on restart
- Added Android startup recovery in `apps/android_app/lib/state/app_state.dart` so existing non-empty generated WAV files are scanned, turned back into completed synthesis tasks, and shown in the UI after relaunch
- Extended `packages/tts_core/lib/src/services/task_manager.dart` with restore support for completed tasks while ignoring duplicates and invalid active-task restores
- Updated `packages/tts_core/test/tts_core_test.dart` and `domain-brain/flows/audio-output.md`, then verified the change with `flutter test` in `packages/tts_core` and `flutter analyze` in `apps/android_app`

## Checkpoint 7
- Added lightweight shared JSON persistence for generated audio in `packages/tts_core`, with one records file for completed speech metadata and one placeholder stats file for future per-model metrics
- Extended generated-audio task metadata to persist and restore model identity plus exact generation timing instead of relying on in-memory state only
- Wired Android and desktop app state to load/store that metadata, remove it when generated audio is dismissed, and keep generated WAV files under a persistent `generated_audio` directory
- Added Android legacy fallback migration for pre-existing unindexed WAV files so older orphaned audio can still reappear in the task list and be managed
- Updated the shared task UI to show explicit generation time and model name for completed audio, then verified the change with `flutter test` in `packages/tts_core` and `packages/shared_ui`, plus `flutter analyze` in both apps

## Checkpoint 8
- Added bounded per-model generated-audio statistics to the shared JSON store, keyed by model name and persisted in `generated_audio_stats.json`
- Extended completed synthesis task metadata with input character counts so stats updates can compute generation time and output duration per 100 characters
- Wired Android and desktop completion persistence to update model statistics exactly once per generated output while keeping the lightweight file-based storage approach
- Implemented the requested cap at `1,000,000` aggregated characters while preserving the current weighted averages for generation and output duration metrics
- Added `tts_core` tests for per-model stats persistence and cap behavior, then re-ran `flutter test` in `packages/tts_core` and `flutter analyze` in both apps

## Checkpoint 9
- Added shared basic-UI generation estimates under the text input so both apps now show expected generation time and expected audio length when stats exist
- Normalized stored output-duration statistics to speech speed `1.0` and applied the current selected speed only when projecting expected audio length in the UI
- Extended persisted generated-audio metadata with speech speed so future stats updates remain speed-aware after restart-safe persistence
- Added shared UI tests for hidden/visible estimate lines and duration formatting, plus updated `tts_core` tests for speed-normalized output statistics
- Updated `flow-index.yaml`, `domain-brain/flows/local-synthesis.md`, and `domain-brain/flows/audio-output.md`, then re-ran `flutter test` in `packages/tts_core` and `packages/shared_ui` plus `flutter analyze` in both apps

## Checkpoint 10
- Updated desktop Voice Lab import UI to accept a single WAV-or-MP3 sample input and explain that MP3 files are converted automatically
- Changed `apps/desktop_app/lib/services/voice_library_service.dart` so imported reference clips are format-detected by file content and always stored in the voice library as `.wav`
- Added desktop MP3-to-WAV normalization through `ffmpeg`, with concrete import failures when the sample format is unsupported or conversion cannot complete
- Added desktop tests for MP3-capable Voice Lab dialog behavior and for voice-library import normalization, then re-ran the focused desktop tests and `flutter analyze`
- Updated `domain-brain/flows/voice-cloning.md`, `domain-brain/edge-cases.md`, and `tasks/task-9-voice-cloning.md` to document the new import behavior

## Checkpoint 11
- Moved model catalog browsing and install or repair actions into the shared `ModelManagementPanel` in `packages/shared_ui`
- Added dedicated Models screens in both apps and removed inline install-action lists from the Home screens while keeping compact readiness summaries
- Added Android navigation drawer access to Home, Models, and About, and desktop navigation drawer access to Home, Models, and Voice Lab
- Updated `flow-index.yaml` plus the app-navigation, model-catalog, and model-installation domain docs to reflect the new screen structure
- Verified the change with `flutter analyze` in `packages/shared_ui`, `apps/android_app`, and `apps/desktop_app`, plus `flutter test` in all three packages

## Checkpoint 12
- Removed the old model-readiness summary card from both Home screens so the main flow focuses on text input, settings, tasks, and generation
- Expanded `VoiceModel` catalog metadata with size, supported languages, and short descriptions and synced the updated catalog into both app assets
- Reworked the shared `ModelManagementPanel` into expandable rows that show only model name, size, and status when collapsed, then reveal install or delete actions plus detailed metadata when opened
- Added Android and desktop delete-model actions that remove downloaded files without removing the catalog entry from the Models screen
- Updated the model domain docs and verified the change with `flutter analyze` in `packages/tts_core`, `packages/shared_ui`, `apps/android_app`, and `apps/desktop_app`, plus `flutter test` in all four packages

## Checkpoint 13
- Added multilingual Kokoro catalog support for `kokoro-multi-lang-v1_0`, including extra lexicons, Chinese normalization rule FST assets, and a required `dict/` runtime directory
- Added shared runtime support for the `kitten` model family so `kitten-mini-en-v0_1-fp16` can be loaded through `sherpa-onnx`
- Synced the new model catalog entries into `packages/model_catalog/approved_models.json`, `apps/desktop_app/assets/approved_models.json`, and `apps/android_app/assets/approved_models.json`
- Updated model validation and task payload encoding so background work preserves multilingual runtime metadata and install checks catch missing helper assets
- Added durable repo notes in `models.list.md` and expanded licensing and domain-brain docs with the Kokoro packaging distinction and future-model guidance
