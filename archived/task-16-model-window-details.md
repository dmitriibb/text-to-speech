# Model Window Details

## Goal

Refine the dedicated Models screen so the main screen loses the old model summary card, model rows stay compact by default, and expanded rows show practical install details including delete support.

## Current Status

Complete.

## Scope

1. Remove the model readiness summary card from the main Home screen.
2. Show compact model rows with only name, size, and status.
3. Expand a row on tap to show install or delete actions plus richer model metadata.
4. Add delete-model support that removes downloaded files without removing the catalog entry.
5. Store model size, supported languages, and short descriptions in the shared catalog.

## Notes

- Keep the expanded model details shared between Android and desktop.
- Current catalog entries are all English-only, so each remains a separate model entry.

## Outcome

1. Removed the old model summary card from the Home screen.
2. Changed the Models screen to compact expandable rows with `name / size / status`.
3. Added expanded model details for family, engine, languages, description, size, and installed path.
4. Added delete support that removes local model files while keeping the catalog entry visible.
5. Stored size, languages, and description metadata in the shared model catalog.
