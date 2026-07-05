# App Navigation Flow

## Goal

Keep the main generation flow focused on text, voice settings, and playback while routing model management and secondary screens through explicit navigation menus.

## Steps

1. User opens either app and lands on the Home screen.
2. Home shows the standard text generation flow with text input, voice settings, task list, and playback actions.
3. User opens the platform navigation menu.
4. User may select `Live TTS` to open a dedicated screen with live chunk controls and a large internally scrollable editor.
5. User may select `Dialog` to paste a speaker-prefixed transcript, assign a ready local model and optional voice per speaker, generate each line, and play the dialog as a sequence.
6. User selects `Models` to view the approved catalog and start install or repair work on a dedicated screen.
7. On Android, the user may also select `Settings` or `About`; on desktop, the user may also select `Voice Lab`.
8. App switches screens without disturbing current selected model, text input, generated audio, background task state, dialog transcript state, or desktop Voice Lab state, except that leaving the Live TTS or Dialog playback screens stops their active playback sessions.
9. User returns to Home and continues the standard local generation flow.

## Invariants

- Home remains the primary action surface for generation.
- Live TTS uses a dedicated navigation destination instead of an inline Home control surface.
- Dialog mode uses a dedicated navigation destination and keeps parsed speaker lines separate from the Home text input.
- Model catalog browsing and install actions live on the dedicated Models screen instead of Home.
- Android navigation exposes Home, Live TTS, Dialog, Models, Settings, and About.
- Desktop navigation exposes Home, Live TTS, Dialog, Models, and Voice Lab.
- Navigation between destinations must not reset selected model, text input, generated audio state, running tasks, parsed dialog lines, or the current Voice Lab configuration and OpenVoice job progress.

## Failure Modes

- navigation menu missing or mislabeled
- Models route fails to open
- Dialog route fails to open or cannot read clipboard text
- About or Voice Lab route fails to open
- navigation rebuild unexpectedly resets shared app state
