import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'dart:typed_data';

enum OpenVoiceBackendConnectionState {
  disconnected,
  checking,
  connected,
  error,
}

enum OpenVoiceJobStatus { queued, running, succeeded, failed }

enum ExternalBackendVoiceMode { clone, design, auto }

typedef OpenVoiceDelay = Future<void> Function(Duration duration);

class OpenVoiceBackendException implements Exception {
  OpenVoiceBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenVoiceHealth {
  const OpenVoiceHealth({
    required this.backend,
    required this.version,
    required this.engine,
    required this.engineDisplayName,
    required this.engineReady,
    required this.modelsLoaded,
    required this.features,
    required this.supportedJobModes,
    required this.voicesEndpoint,
    this.currentModelId,
    this.currentModelRevision,
  });

  final String backend;
  final String version;
  final String engine;
  final String? engineDisplayName;
  final bool engineReady;
  final bool modelsLoaded;
  final List<String> features;
  final List<ExternalBackendVoiceMode> supportedJobModes;
  final String? voicesEndpoint;
  final String? currentModelId;
  final String? currentModelRevision;

  factory OpenVoiceHealth.fromJson(Map<String, Object?> json) {
    final supportedJobModesJson =
        (json['supported_job_modes'] as List?)?.cast<Object?>() ??
        const <Object?>[];
    return OpenVoiceHealth(
      backend: json['backend'] as String? ?? 'open_voice_be',
      version: json['version'] as String? ?? 'unknown',
      engine: json['engine'] as String? ?? 'unknown',
      engineDisplayName: json['engine_display_name'] as String?,
      engineReady: json['engine_ready'] as bool? ?? false,
      modelsLoaded: json['models_loaded'] as bool? ?? false,
      features: (json['features'] as List?)?.cast<String>() ?? const <String>[],
      supportedJobModes: supportedJobModesJson
          .map((value) => _voiceModeFromString(value as String? ?? 'clone'))
          .toList(growable: false),
      voicesEndpoint: json['voices_endpoint'] as String?,
      currentModelId: json['current_model_id'] as String?,
      currentModelRevision: json['current_model_revision'] as String?,
    );
  }
}

class ExternalBackendVoice {
  const ExternalBackendVoice({
    required this.id,
    required this.displayName,
    required this.description,
    required this.mode,
    required this.requiresReferenceAudio,
    required this.supportsInstructionEditing,
    required this.presetInstruction,
  });

  final String id;
  final String displayName;
  final String description;
  final ExternalBackendVoiceMode mode;
  final bool requiresReferenceAudio;
  final bool supportsInstructionEditing;
  final String? presetInstruction;

  bool get supportsReferenceAudio => requiresReferenceAudio;
  bool get supportsInstruction =>
      mode == ExternalBackendVoiceMode.design || supportsInstructionEditing;

  factory ExternalBackendVoice.fromJson(Map<String, Object?> json) {
    return ExternalBackendVoice(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mode: _voiceModeFromString(json['mode'] as String? ?? 'clone'),
      requiresReferenceAudio:
          json['requires_reference_audio'] as bool? ?? false,
      supportsInstructionEditing:
          json['supports_instruction_editing'] as bool? ?? false,
      presetInstruction: json['preset_instruction'] as String?,
    );
  }
}

class OpenVoiceJobSubmission {
  const OpenVoiceJobSubmission({required this.jobId});

  final String jobId;

  factory OpenVoiceJobSubmission.fromJson(Map<String, Object?> json) {
    return OpenVoiceJobSubmission(jobId: json['job_id'] as String? ?? '');
  }
}

class OpenVoiceJob {
  const OpenVoiceJob({
    required this.jobId,
    required this.status,
    required this.error,
    required this.audioReady,
  });

  final String jobId;
  final OpenVoiceJobStatus status;
  final String? error;
  final bool audioReady;

  bool get isTerminal =>
      status == OpenVoiceJobStatus.succeeded ||
      status == OpenVoiceJobStatus.failed;

  factory OpenVoiceJob.fromJson(Map<String, Object?> json) {
    final result = Map<String, Object?>.from(
      json['result'] as Map? ?? const <String, Object?>{},
    );
    return OpenVoiceJob(
      jobId: json['job_id'] as String? ?? '',
      status: _jobStatusFromString(json['status'] as String? ?? 'failed'),
      error: json['error'] as String?,
      audioReady: result['audio_ready'] as bool? ?? false,
    );
  }

  static OpenVoiceJobStatus _jobStatusFromString(String value) {
    switch (value) {
      case 'queued':
        return OpenVoiceJobStatus.queued;
      case 'running':
        return OpenVoiceJobStatus.running;
      case 'succeeded':
        return OpenVoiceJobStatus.succeeded;
      case 'failed':
      default:
        return OpenVoiceJobStatus.failed;
    }
  }
}

class OpenVoiceBackendService {
  OpenVoiceBackendService({http.Client? client, OpenVoiceDelay? delay})
    : _client = client ?? http.Client(),
      _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  static const defaultBaseUrl = 'http://127.0.0.1:8008';
  static const initialPollingSeconds = 1;
  static const pollingIncrementSeconds = 1;
  static const maxPollingSeconds = 10;

  final http.Client _client;
  final OpenVoiceDelay _delay;

  Uri parseBaseUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw OpenVoiceBackendException('Backend URL is required.');
    }
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw OpenVoiceBackendException(
        'Enter a full backend URL such as http://127.0.0.1:8008.',
      );
    }
    return uri.replace(
      path: uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path,
    );
  }

  Future<OpenVoiceHealth> fetchHealth(Uri baseUri) async {
    final response = await _client
        .get(_endpoint(baseUri, '/health'))
        .timeout(const Duration(seconds: 15));
    final json = _decodeJson(response);
    return OpenVoiceHealth.fromJson(json);
  }

  Future<List<ExternalBackendVoice>> fetchVoices(Uri baseUri) async {
    final response = await _client.get(_endpoint(baseUri, '/voices'));
    if (response.statusCode == 404) {
      return const <ExternalBackendVoice>[];
    }
    final decoded = _decodeJsonList(response);
    return decoded
        .map(ExternalBackendVoice.fromJson)
        .where((voice) => voice.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<OpenVoiceJobSubmission> submitJob({
    required Uri baseUri,
    required String text,
    String? voiceId,
    String? referenceAudioPath,
    Uint8List? referenceAudioBytes,
    String? referenceText,
    String? instruct,
    String language = 'en',
    double speed = 1.0,
    double? duration,
    int? numStep,
    Map<String, Object?> settings = const <String, Object?>{},
  }) async {
    final request = http.MultipartRequest('POST', _endpoint(baseUri, '/jobs'));
    request.fields['text'] = text;
    if (voiceId != null && voiceId.trim().isNotEmpty) {
      request.fields['voice_id'] = voiceId.trim();
    }
    request.fields['language'] = language;
    request.fields['speed'] = speed.toString();
    request.fields['settings'] = jsonEncode(settings);
    if (referenceText != null && referenceText.trim().isNotEmpty) {
      request.fields['reference_text'] = referenceText.trim();
    }
    if (instruct != null && instruct.trim().isNotEmpty) {
      request.fields['instruct'] = instruct.trim();
    }
    if (duration != null) {
      request.fields['duration'] = duration.toString();
    }
    if (numStep != null) {
      request.fields['num_step'] = numStep.toString();
    }
    if (referenceAudioBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'reference_audio',
          referenceAudioBytes,
          filename: 'reference.wav',
        ),
      );
    } else if (referenceAudioPath != null &&
        referenceAudioPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'reference_audio',
          referenceAudioPath,
          filename: p.basename(referenceAudioPath),
        ),
      );
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(
      streamed,
    ).timeout(const Duration(seconds: 30));
    final json = _decodeJson(response, acceptedStatusCodes: const {202});
    return OpenVoiceJobSubmission.fromJson(json);
  }

  Future<OpenVoiceJob> fetchJob(Uri baseUri, String jobId) async {
    final response = await _client
        .get(_endpoint(baseUri, '/jobs/$jobId'))
        .timeout(const Duration(seconds: 15));
    final json = _decodeJson(response);
    return OpenVoiceJob.fromJson(json);
  }

  Future<OpenVoiceJob> waitForJobCompletion({
    required Uri baseUri,
    required String jobId,
    bool Function()? isCancelled,
    Duration deadline = const Duration(minutes: 30),
  }) async {
    final watch = Stopwatch()..start();
    void check() {
      if (isCancelled?.call() ?? false) {
        throw OpenVoiceBackendException(
          'Polling cancelled; server computation may finish.',
        );
      }
      if (watch.elapsed >= deadline) {
        throw OpenVoiceBackendException(
          'Backend job timed out. Check server logs and retry.',
        );
      }
    }

    check();
    var attempt = 0;
    var current = await fetchJob(baseUri, jobId);
    while (!current.isTerminal) {
      final waitSeconds =
          (initialPollingSeconds + (attempt * pollingIncrementSeconds)).clamp(
            1,
            maxPollingSeconds,
          );
      if (isCancelled == null) {
        await _delay(Duration(seconds: waitSeconds));
      } else {
        for (var tick = 0; tick < waitSeconds * 5; tick++) {
          check();
          await _delay(const Duration(milliseconds: 200));
        }
      }
      check();
      current = await fetchJob(baseUri, jobId);
      attempt += 1;
    }
    check();
    return current;
  }

  Future<File> downloadJobResult({
    required Uri baseUri,
    required String jobId,
    required String outputPath,
    bool Function()? isCancelled,
  }) async {
    final response = await _client
        .send(http.Request('GET', _endpoint(baseUri, '/jobs/$jobId/result')))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw OpenVoiceBackendException(
        'Result download failed with HTTP ${response.statusCode}.',
      );
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    final partial = File('$outputPath.part');
    final sink = await partial.open(mode: FileMode.write);
    var bytes = 0;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        if (isCancelled?.call() ?? false) {
          throw OpenVoiceBackendException('Download cancelled.');
        }
        bytes += chunk.length;
        if (bytes > 128 * 1024 * 1024) {
          throw OpenVoiceBackendException('Result exceeds 128 MiB.');
        }
        await sink.writeFrom(chunk);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    await sink.close();
    await partial.rename(outputPath);
    return outputFile;
  }

  void dispose() {
    _client.close();
  }

  Future<void> deleteJob(Uri baseUri, String jobId) async {
    final response = await _client
        .delete(_endpoint(baseUri, '/jobs/$jobId'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw OpenVoiceBackendException(_decodeError(response));
    }
  }

  Uri _endpoint(Uri baseUri, String path) {
    final normalizedBase = baseUri.path.endsWith('/') && baseUri.path.length > 1
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$normalizedBase$path');
  }

  List<Map<String, Object?>> _decodeJsonList(http.Response response) {
    if (response.statusCode != 200) {
      throw OpenVoiceBackendException(_decodeError(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw OpenVoiceBackendException('Unexpected backend response format.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item as Map<Object?, Object?>))
        .toList(growable: false);
  }

  Map<String, Object?> _decodeJson(
    http.Response response, {
    Set<int> acceptedStatusCodes = const {200},
  }) {
    if (!acceptedStatusCodes.contains(response.statusCode)) {
      throw OpenVoiceBackendException(_decodeError(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw OpenVoiceBackendException('Unexpected backend response format.');
    }
    return Map<String, Object?>.from(decoded as Map<Object?, Object?>);
  }

  String _decodeError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}

    final body = response.body.trim();
    if (body.isNotEmpty) {
      return body;
    }
    return 'Backend request failed with HTTP ${response.statusCode}.';
  }
}

ExternalBackendVoiceMode _voiceModeFromString(String value) {
  switch (value) {
    case 'design':
      return ExternalBackendVoiceMode.design;
    case 'auto':
      return ExternalBackendVoiceMode.auto;
    case 'clone':
    default:
      return ExternalBackendVoiceMode.clone;
  }
}
