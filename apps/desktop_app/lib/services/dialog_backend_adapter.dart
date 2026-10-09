import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tts_core/tts_core.dart';

import 'open_voice_backend_service.dart';

const voxCpm2Revision = '32279effe8c19989596f05d353d1447f51d9e915';

/// Explicit desktop metadata, never offered to the ONNX installer or Android.
final voxCpm2DialogModel = InstalledModel(
  voice: VoiceModel.fromJson({
    'id': 'openbmb/VoxCPM2',
    'display_name': 'VoxCPM2 (backend)',
    'family': 'voxcpm2',
    'runtime': 'voxcpm2',
    'approved_for_distribution': false,
    'supported_languages': ['ru', 'en', 'zh'],
    'default_speed': 1.0,
    'description': 'Desktop reference voice; language inferred from text.',
  }),
  // No fabricated modelDir or ready ONNX installation status.
  status: ModelStatus.notInstalled,
);

class DialogBackendAdapter {
  DialogBackendAdapter(this.service);
  final OpenVoiceBackendService service;

  Future<BackendTargetStatus> readiness(
    String url, {
    String? expectedRevision,
  }) async {
    final endpoint = service.parseBaseUri(url);
    const target = SynthesisTarget.backend(
      modelId: 'openbmb/VoxCPM2',
      backendId: 'voxcpm2',
    );
    try {
      final health = await service.fetchHealth(endpoint);
      final matches =
          health.engine == 'voxcpm2' &&
          health.currentModelId == target.modelId &&
          (expectedRevision == null ||
              health.currentModelRevision == expectedRevision);
      return BackendTargetStatus(
        target: target,
        endpoint: endpoint,
        readiness: !matches || !health.engineReady
            ? BackendReadiness.reachable
            : health.modelsLoaded
            ? BackendReadiness.loaded
            : BackendReadiness.loadable,
        message: !matches
            ? 'Endpoint is not serving openbmb/VoxCPM2.'
            : health.modelsLoaded
            ? 'Model loaded.'
            : 'Server reachable; first turn loads the model.',
      );
    } catch (error) {
      return BackendTargetStatus(
        target: target,
        endpoint: endpoint,
        readiness: BackendReadiness.unavailable,
        message: 'Cannot reach VoxCPM2: $error',
      );
    }
  }

  Future<void> generate(DialogGenerationRequest request, String url) async {
    request.cancellation.check();
    final actor = request.actor;
    if (actor.effectiveTarget?.backendId != 'voxcpm2') {
      throw StateError('Unsupported backend target.');
    }
    if (actor.speed != 1) throw StateError('VoxCPM2 supports speed 1.0 only.');
    final reference = actor.reference;
    if (reference == null) {
      throw StateError(
        'Choose a clean reference WAV and its exact transcript for ${actor.speakerName}.',
      );
    }
    if (reference.transcript.trim().isEmpty) {
      throw StateError('Reference transcript is required.');
    }
    final bytes = await DialogReferenceStore(
      projectDirectory: request.projectDirectory,
    ).readVerifiedBytes(reference);
    await _validateReference(bytes);
    request.cancellation.check();
    final status = await readiness(
      url,
      expectedRevision:
          actor.synthesisSettings.extensionValues['model_revision'] as String?,
    );
    if (!status.canGenerate) {
      throw StateError(status.message ?? 'Backend model is not loadable.');
    }
    request.cancellation.check();
    final submitted = await service.submitJob(
      baseUri: status.endpoint,
      text: request.line.effectiveText,
      language: 'ru',
      speed: 1,
      referenceAudioBytes: bytes,
      settings: {
        ...actor.synthesisSettings.extensionValues,
        'use_reference_as_prompt': true,
        'prompt_text': reference.transcript,
        'normalize': false,
        'denoise': false,
      }..remove('referenceAsset'),
    );
    try {
      request.cancellation.check();
      final result = await service.waitForJobCompletion(
        baseUri: status.endpoint,
        jobId: submitted.jobId,
        isCancelled: () => request.cancellation.cancelled,
      );
      request.cancellation.check();
      if (result.status != OpenVoiceJobStatus.succeeded || !result.audioReady) {
        throw StateError(result.error ?? 'Backend returned no audio.');
      }
      await service.downloadJobResult(
        baseUri: status.endpoint,
        jobId: submitted.jobId,
        outputPath: '${request.outputPath}.download',
        isCancelled: () => request.cancellation.cancelled,
      );
      request.cancellation.check();
      final outputPath = request.outputPath;
      final gain = actor.volumeGain;
      await _applyActorGain(outputPath, gain);
      request.cancellation.check();
    } finally {
      final temporary = File('${request.outputPath}.download');
      if (await temporary.exists()) await temporary.delete();
      // Server artifacts are temporary. DELETE waits for safe inference cleanup.
      try {
        await service.deleteJob(status.endpoint, submitted.jobId);
      } catch (_) {}
    }
  }
}

Future<void> _validateReference(Uint8List bytes) => Isolate.run(() {
  final wave = PcmWave.decode(bytes);
  final duration = wave.samples.length / wave.sampleRate;
  if (duration < 1 || duration > 30) {
    throw StateError('Use a reference between 1 and 30 seconds (app limit).');
  }
});
Future<void> _applyActorGain(String outputPath, double gain) => Isolate.run(() {
  final source = File('$outputPath.download');
  if (source.lengthSync() > 128 * 1024 * 1024) {
    throw StateError('Downloaded WAV exceeds 128 MiB.');
  }
  final wave = PcmWave.decode(source.readAsBytesSync());
  final output = File(outputPath).openSync(mode: FileMode.write);
  try {
    output.writeFromSync(PcmWave.header(wave.samples.length, wave.sampleRate));
    for (var start = 0; start < wave.samples.length; start += 4096) {
      final n = (wave.samples.length - start).clamp(0, 4096);
      final chunk = ByteData(n * 2);
      for (var i = 0; i < n; i++) {
        chunk.setInt16(
          i * 2,
          (wave.samples[start + i] * gain * 32767).round().clamp(-32768, 32767),
          Endian.little,
        );
      }
      output.writeFromSync(chunk.buffer.asUint8List());
    }
  } finally {
    output.closeSync();
  }
});
