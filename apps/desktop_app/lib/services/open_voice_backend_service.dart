import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

enum OpenVoiceBackendConnectionState { disconnected, checking, connected, error }

enum OpenVoiceJobStatus { queued, running, succeeded, failed }

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
    required this.engineReady,
    required this.modelsLoaded,
  });

  final String backend;
  final String version;
  final bool engineReady;
  final bool modelsLoaded;

  factory OpenVoiceHealth.fromJson(Map<String, Object?> json) {
    return OpenVoiceHealth(
      backend: json['backend'] as String? ?? 'open_voice_be',
      version: json['version'] as String? ?? 'unknown',
      engineReady: json['engine_ready'] as bool? ?? false,
      modelsLoaded: json['models_loaded'] as bool? ?? false,
    );
  }
}

class OpenVoiceCapabilities {
  const OpenVoiceCapabilities({
    required this.supportsPreview,
    required this.initialPollingSeconds,
    required this.incrementSeconds,
    required this.maxPollingSeconds,
  });

  final bool supportsPreview;
  final int initialPollingSeconds;
  final int incrementSeconds;
  final int maxPollingSeconds;

  factory OpenVoiceCapabilities.fromJson(Map<String, Object?> json) {
    final polling = Map<String, Object?>.from(
      json['polling_strategy'] as Map? ?? const <String, Object?>{},
    );
    return OpenVoiceCapabilities(
      supportsPreview: json['supports_preview'] as bool? ?? false,
      initialPollingSeconds: polling['initial_seconds'] as int? ?? 1,
      incrementSeconds: polling['increment_seconds'] as int? ?? 1,
      maxPollingSeconds: polling['max_seconds'] as int? ?? 10,
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

  final http.Client _client;
  final OpenVoiceDelay _delay;

  Uri parseBaseUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw OpenVoiceBackendException('Backend URL is required.');
    }
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw OpenVoiceBackendException('Enter a full backend URL such as http://127.0.0.1:8008.');
    }
    return uri.replace(
      path: uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path,
    );
  }

  Future<OpenVoiceHealth> fetchHealth(Uri baseUri) async {
    final response = await _client.get(_endpoint(baseUri, '/health'));
    final json = _decodeJson(response);
    return OpenVoiceHealth.fromJson(json);
  }

  Future<OpenVoiceCapabilities> fetchCapabilities(Uri baseUri) async {
    final response = await _client.get(_endpoint(baseUri, '/capabilities'));
    final json = _decodeJson(response);
    return OpenVoiceCapabilities.fromJson(json);
  }

  Future<OpenVoiceJobSubmission> submitPreviewJob({
    required Uri baseUri,
    required String text,
    required String referenceAudioPath,
    String language = 'en',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _endpoint(baseUri, '/jobs/clone-preview'),
    );
    request.fields['text'] = text;
    request.fields['language'] = language;
    request.files.add(
      await http.MultipartFile.fromPath(
        'reference_audio',
        referenceAudioPath,
        filename: p.basename(referenceAudioPath),
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final json = _decodeJson(response, acceptedStatusCodes: const {202});
    return OpenVoiceJobSubmission.fromJson(json);
  }

  Future<OpenVoiceJob> fetchJob(Uri baseUri, String jobId) async {
    final response = await _client.get(_endpoint(baseUri, '/jobs/$jobId'));
    final json = _decodeJson(response);
    return OpenVoiceJob.fromJson(json);
  }

  Future<OpenVoiceJob> waitForJobCompletion({
    required Uri baseUri,
    required String jobId,
    required OpenVoiceCapabilities capabilities,
  }) async {
    var attempt = 0;
    var current = await fetchJob(baseUri, jobId);
    while (!current.isTerminal) {
        final waitSeconds = ((capabilities.initialPollingSeconds +
              (attempt * capabilities.incrementSeconds))
            .clamp(1, capabilities.maxPollingSeconds))
          as int;
      await _delay(Duration(seconds: waitSeconds));
      current = await fetchJob(baseUri, jobId);
      attempt += 1;
    }
    return current;
  }

  Future<File> downloadJobResult({
    required Uri baseUri,
    required String jobId,
    required String outputPath,
  }) async {
    final response = await _client.get(_endpoint(baseUri, '/jobs/$jobId/result'));
    if (response.statusCode != 200) {
      throw OpenVoiceBackendException(_decodeError(response));
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(response.bodyBytes, flush: true);
    return outputFile;
  }

  void dispose() {
    _client.close();
  }

  Uri _endpoint(Uri baseUri, String path) {
    final normalizedBase = baseUri.path.endsWith('/') && baseUri.path.length > 1
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$normalizedBase$path');
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