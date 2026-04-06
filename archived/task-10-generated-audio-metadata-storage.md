# Task 10: Generated audio metadata storage

## Goal

Persist generated-audio metadata in lightweight JSON files so the app can restore audio name, generation timing, and model information across restarts, and prepare a separate stats file for future per-model generation metrics.

## Status

- Completed.
- Generated audio now persists lightweight JSON metadata plus the `.wav` file, with no database added.
- A separate stats JSON file is created for future per-model generation metrics.

## Next Steps

- Future task: implement per-model statistics aggregation and reporting using the prepared stats JSON file.
