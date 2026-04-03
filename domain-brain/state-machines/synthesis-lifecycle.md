# Synthesis Lifecycle

## States

- `idle`
- `generating`
- `done`
- `error`

## Transitions

- `idle -> generating`
  - when valid input and a ready model are present and generation starts
- `generating -> done`
  - when synthesis succeeds and a `.wav` file is written successfully
- `generating -> error`
  - when model loading, synthesis, or `.wav` writing fails
- `done -> generating`
  - when the user starts a new generation run
- `error -> generating`
  - when the user retries after fixing the blocking issue

## Notes

- `done` implies a local generated `.wav` exists.
- Starting a new generation may replace the previously generated audio path.