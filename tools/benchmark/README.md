# benchmark

Phase 0 local validation harness for `sherpa-onnx`.

Primary script:

- `run_phase0_validation.py`

The harness:

- reads the approved model catalog
- reads the benchmark text corpus
- runs offline synthesis
- writes `.wav` files
- records elapsed time, audio duration, and real-time factor

