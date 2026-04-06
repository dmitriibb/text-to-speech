# Task 10: Generated audio statistics

## Goal

Persist per-model generated-audio statistics in the lightweight stats JSON file and update them after each completed speech generation.

## Status

- Completed.
- Per-model stats are now persisted in JSON and updated after each completed speech generation.
- Stats stay bounded by the configured `1,000,000` character cap while preserving current average rates.

## Next Steps

- Future task: expose the stored per-model statistics in the UI or diagnostics output.
