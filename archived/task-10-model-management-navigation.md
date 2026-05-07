# Model Management Navigation

## Goal

Move model management into a dedicated screen in both apps, make it reachable from navigation on Android, and add desktop navigation for switching between the main generation flow, model management, and Voice Lab.

## Current Status

Complete.

## Scope

1. Create a dedicated Models screen for browsing approved models and starting install or repair work.
2. Remove install-action lists from the main Home screens while keeping enough status context for the user to understand readiness.
3. Add Android navigation menu access to Home, Models, and About.
4. Add desktop navigation menu access to Home, Models, and Voice Lab.
5. Keep model install UI shared between desktop and Android where possible.

## Notes

- This is Basic functionality for model catalog browsing and installation, so the model-management UI should live in shared packages.
- Navigation affordances may differ by platform, but moving between screens must not reset shared app state.

## Outcome

1. Added a shared model-management panel in `packages/shared_ui`.
2. Added dedicated Models screens in both apps.
3. Added Android drawer navigation for Home, Models, and About.
4. Added desktop drawer navigation for Home, Models, and Voice Lab.
5. Updated docs and tests to match the new flow.
