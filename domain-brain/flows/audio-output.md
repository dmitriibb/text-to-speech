# Audio Output Flow

## Goal

Let the user hear or keep the generated audio after synthesis succeeds.

## Steps

1. App keeps the last generated `.wav` path in state.
2. User chooses a platform output action.
3. Desktop plays audio through system tools and can export a copy.
4. Android plays audio in-app and can share the `.wav` through the system share sheet.

## Invariants

- Output actions operate on an existing generated local `.wav`.
- Playback and export/share are platform-specific service responsibilities.
- Output failures do not invalidate the already generated audio file.

## Failure Modes

- Linux playback dependency missing
- Android audio playback failure
- desktop export failure
- Android share failure