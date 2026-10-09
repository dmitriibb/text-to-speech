# Model Settings Flow

## Goal

Keep synthesis settings capability-driven, reusable across modes, and stable when users switch models or screens.

## Steps

1. Every synthesis surface shows the shared `ModelSelector`: an installed-model dropdown plus a settings gear.
2. The gear opens a shared modal for the selected model.
3. Local models expose volume (`0.5` to `1.5`, default `1.0`) and speed (`0.5` to `2.0`, normally default `1.0`). Desktop VoxCPM2 uses fixed speed `1.0` and inferred language; unsupported selectors are replaced by explanatory text.
4. The modal adds speaker and generation-language selectors only when the selected catalog model declares those capabilities.
5. Model-family integrations may inject additional controls and persist JSON-safe extension values without changing the consuming screen.
6. Home/Live defaults are keyed by stable model ID, persisted in app-private user settings, and restored when that model is selected again.
7. Home, Live TTS, and Dialog use the same selector and modal component.
8. Dialog copies defaults into an independent actor profile. Its modal applies a
   single settings snapshot (speed, gain, speaker, language and JSON-safe
   extensions) to that actor only. Model switches restore that actor's previous
   settings for the chosen target, without modifying Home/Live defaults.
9. Version-2 actor serialization includes stable actor ID, revision, selected
   local/backend target, settings history and reference metadata. This is a
   shared contract persisted by DialogWorkspace and the Save/Reload controls on both apps.

## Invariants

- Home/Live settings belong to a model; Dialog overrides belong to an actor and target.
- Switching models restores that model's last saved settings.
- Unsupported controls are not shown.
- Applying settings while Live TTS is active stops the current live session so buffered audio cannot use stale settings.
- Normal and Live synthesis apply the selected model's volume, speed, speaker, and language.
- Shared settings UI and value validation live in `packages/shared_ui` and `packages/tts_core`.
- Actor settings detach and freeze nested model extensions, preventing mutable
  defaults from changing another actor or a queued request.
- Dialog gain is the generic `0.5`–`1.5` gain, applied once during synthesis.
  Legacy volume `1`–`10` migrates as `volume / 7`, clamped to that range; `7`
  remains `1.0`. The old integer scale is only a compatibility API and is not
  multiplied into an actor's effective gain.

## Failure Modes

- persisted values are invalid or outside supported bounds
- persisted speaker or language no longer exists after a catalog update
- settings storage is missing or unreadable
- a model-specific extension stores a value that is not JSON-safe

