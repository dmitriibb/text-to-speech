# Benchmark Validation Flow

## Goal

Validate the chosen runtime and model path outside the apps through a repeatable benchmark harness.

## Steps

1. Download an approved model.
2. Extract it into the repo `models/` area.
3. Run the Phase 0 Python validation harness.
4. Generate `.wav` files plus a JSON report under `artifacts/phase0/`.

## Invariants

- The harness validates the same runtime direction used by the apps.
- Validation artifacts are written under `artifacts/phase0/`.
- The harness is a validation tool, not the final app runtime layer.

## Failure Modes

- missing Python dependencies
- missing or broken model files
- synthesis failure during benchmark execution