# App Navigation Flow

## Goal

Keep the Android home screen focused on model, synthesis, and playback actions while routing descriptive product information to a secondary About screen.

## Steps

1. User opens the Android app and lands on the home screen.
2. Home shows model status, text input, synthesis controls, errors, and playback actions.
3. User opens the app-bar overflow menu and selects `About`.
4. App pushes the About screen without disturbing current synthesis or playback state.
5. User returns to the home screen and continues the local generation flow.

## Invariants

- Home remains the primary action surface for generation and model management.
- About is reachable from the standard app-bar overflow menu.
- Navigation to About must not reset selected model, text input, or generated audio state.

## Failure Modes

- overflow action missing or mislabeled
- About route fails to open
- navigation rebuild unexpectedly resets shared app state