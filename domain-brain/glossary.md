# Glossary

## ModelCatalog

The repo-owned machine-readable list of approved voice models and their metadata.

## VoiceModel

A single approved model entry parsed from the catalog and used by apps to install and load a voice.

## InstalledModel

A `VoiceModel` paired with its detected local installation state and optional model directory path.

## Model Status

The readiness state for a model on disk: `notInstalled`, `downloading`, `incomplete`, or `ready`.

## GeneratedAudio

A local `.wav` artifact produced after successful synthesis and then used for playback, export, or sharing.

## Local Synthesis

Speech generation that runs entirely on the device through `sherpa-onnx` with no cloud dependency.

## Development Model

A model approved for local validation and development use, but not yet approved for redistribution in shipped apps.

## Distribution Approval

The licensing decision that determines whether a model may be bundled or shipped to end users.

## App-Private Model Storage

The Android storage location resolved via `path_provider` where model archives are extracted for normal app use.

## Validation Harness

The Phase 0 Python benchmark flow that downloads a model, runs synthesis, and writes `.wav` files plus a JSON report under `artifacts/phase0/`.