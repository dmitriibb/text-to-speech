# Model Readiness

## States

- `notInstalled`
- `downloading`
- `incomplete`
- `ready`

## Transitions

- `notInstalled -> downloading`
  - when the user starts a model install
- `downloading -> ready`
  - when download, extraction, and validation all succeed
- `downloading -> incomplete`
  - when installation leaves a partial or invalid model directory
- `downloading -> notInstalled`
  - when installation fails before any usable model directory remains
- `incomplete -> downloading`
  - when the user retries repair or reinstall
- `incomplete -> ready`
  - when repair succeeds and validation passes
- `ready -> incomplete`
  - when required files are missing or corrupted on a later scan
- `ready -> notInstalled`
  - when the model directory is deleted

## Notes

- `ready` is a validation result, not just proof that a directory exists.
- Desktop and Android use different storage roots but the same readiness rules.