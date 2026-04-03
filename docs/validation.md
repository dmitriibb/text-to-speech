# Validation Status

Updated: 2026-04-03

## Phase 0 runtime validation

### Completed in the current workspace

- Created a local Python virtual environment
- Installed CPU-only `sherpa-onnx`
- Downloaded `vits-piper-en_US-lessac-medium`
- Verified cache reuse on a second fetch
- Ran the `quick` benchmark set successfully

Latest quick benchmark report:

- Model: `vits-piper-en_US-lessac-medium`
- Report path: `artifacts/phase0/vits-piper-en_US-lessac-medium/20260403-122302/report.json`
- `short_plain`: elapsed `0.379s`, duration `3.065s`, RTF `0.124`
- `short_numbers`: elapsed `0.880s`, duration `7.750s`, RTF `0.114`
- `medium_paragraph`: elapsed `1.482s`, duration `12.581s`, RTF `0.118`

## Platform matrix

### Current Linux workspace host

- Status: Passed
- Evidence: local quick benchmark completed and generated `.wav` files

### Ubuntu

- Status: Unknown
- Needed to decide:
  - run the same Phase 0 commands on an actual Ubuntu reference machine
  - record the package install result and benchmark output

### Windows

- Status: Unknown
- Needed to decide:
  - create a Windows virtual environment
  - install `sherpa-onnx` on Windows
  - fetch the same model and run the benchmark harness

## Cache behavior

- First fetch: archive downloaded and extracted
- Second fetch: cached archive reused, extraction skipped

