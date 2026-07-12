# Model Settings Flow

## Goal

Keep synthesis settings capability-driven, reusable across modes, and stable when users switch models or screens.

## Steps

1. Every synthesis surface shows the shared `ModelSelector`: an installed-model dropdown plus a settings gear.
2. The gear opens a shared modal for the selected model.
3. Every model exposes volume (`0.5` to `1.5`, default `1.0`) and speed (`0.5` to `2.0`, normally default `1.0`).
4. The modal adds speaker and generation-language selectors only when the selected catalog model declares those capabilities.
5. Model-family integrations may inject additional controls and persist JSON-safe extension values without changing the consuming screen.
6. Settings are keyed by stable model ID, persisted in app-private user settings, and restored when that model is selected again.
7. Home, Live TTS, and Dialog use the same selector and modal component.

## Invariants

- Settings belong to a model, not to a screen.
- Switching models restores that model's last saved settings.
- Unsupported controls are not shown.
- Applying settings while Live TTS is active stops the current live session so buffered audio cannot use stale settings.
- Normal and Live synthesis apply the selected model's volume, speed, speaker, and language.
- Shared settings UI and value validation live in `packages/shared_ui` and `packages/tts_core`.

## Failure Modes

- persisted values are invalid or outside supported bounds
- persisted speaker or language no longer exists after a catalog update
- settings storage is missing or unreadable
- a model-specific extension stores a value that is not JSON-safe

