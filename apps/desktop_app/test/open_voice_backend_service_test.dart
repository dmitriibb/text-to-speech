import 'dart:convert';

import 'package:desktop_app/services/open_voice_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('parses health and capabilities responses', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/health') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'backend': 'open_voice_be',
            'version': '0.1.0-mvp',
            'engine_ready': false,
            'models_loaded': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'supports_preview': true,
          'polling_strategy': {
            'initial_seconds': 1,
            'increment_seconds': 1,
            'max_seconds': 10,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = OpenVoiceBackendService(client: client);
    final baseUri = service.parseBaseUri('http://127.0.0.1:8008');

    final health = await service.fetchHealth(baseUri);
    final capabilities = await service.fetchCapabilities(baseUri);

    expect(health.backend, 'open_voice_be');
    expect(health.engineReady, isFalse);
    expect(capabilities.supportsPreview, isTrue);
    expect(capabilities.maxPollingSeconds, 10);
  });

  test('polls job status with increasing intervals until completion', () async {
    final delays = <Duration>[];
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      final status = switch (requestCount) {
        1 => 'queued',
        2 => 'running',
        _ => 'succeeded',
      };

      return http.Response(
        jsonEncode({
          'job_id': 'job-1',
          'status': status,
          'result': {'audio_ready': status == 'succeeded'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = OpenVoiceBackendService(
      client: client,
      delay: (duration) async {
        delays.add(duration);
      },
    );

    final job = await service.waitForJobCompletion(
      baseUri: service.parseBaseUri('http://127.0.0.1:8008'),
      jobId: 'job-1',
      capabilities: const OpenVoiceCapabilities(
        supportsPreview: true,
        initialPollingSeconds: 1,
        incrementSeconds: 1,
        maxPollingSeconds: 10,
      ),
    );

    expect(job.status, OpenVoiceJobStatus.succeeded);
    expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
  });
}