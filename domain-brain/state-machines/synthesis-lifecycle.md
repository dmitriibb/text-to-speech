# Synthesis Lifecycle

## States

- `idle`
- `queued`
- `generating`
- `done`
- `error`
- `cancelled`

## Transitions

- `idle -> queued`
  - when valid input and a ready model are present and the app submits a background synthesis task
- `queued -> generating`
  - when the background task runner starts the synthesis job
- `generating -> done`
  - when synthesis succeeds and a `.wav` file is written successfully
- `generating -> error`
  - when model loading, synthesis, or `.wav` writing fails
- `queued -> cancelled`
  - when the user cancels the task before it starts running
- `generating -> cancelled`
  - when the user cancels a running task and the result is discarded
- `done -> queued`
  - when the user starts a new generation run
- `error -> queued`
  - when the user retries after fixing the blocking issue

## Notes

- `done` implies a local generated `.wav` exists.
- Android may keep multiple synthesis tasks queued, but generated-audio UI currently promotes the most recently completed output.
- Task execution happens outside the main UI isolate so the app can stay responsive while work is in progress.