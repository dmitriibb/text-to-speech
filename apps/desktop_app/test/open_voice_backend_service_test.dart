import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_app/services/open_voice_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parses health response', () async {
    final client = MockClient((request) async {
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
    });

    final service = OpenVoiceBackendService(client: client);
    final baseUri = service.parseBaseUri('http://127.0.0.1:8008');

    final health = await service.fetchHealth(baseUri);

    expect(health.backend, 'open_voice_be');
    expect(health.engineReady, isFalse);
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
    );

    expect(job.status, OpenVoiceJobStatus.succeeded);
    expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
  });

  test('submits speed with the OpenVoice job request', () async {
    final client = _RecordingClient();
    final service = OpenVoiceBackendService(client: client);
    final tempDir = await Directory.systemTemp.createTemp('openvoice-service-');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final referenceFile = File(p.join(tempDir.path, 'reference.wav'));
    await referenceFile.writeAsBytes(_wavHeaderBytes());

    final submission = await service.submitJob(
      baseUri: service.parseBaseUri('http://127.0.0.1:8008'),
      text: 'hello',
      referenceAudioPath: referenceFile.path,
      speed: 1.5,
    );

    expect(submission.jobId, 'job-123');
    expect(client.lastRequest, isA<http.MultipartRequest>());
    final request = client.lastRequest! as http.MultipartRequest;
    expect(request.fields['text'], 'hello');
    expect(request.fields['language'], 'en');
    expect(request.fields['speed'], '1.5');
  });
}

class _RecordingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(jsonEncode({'job_id': 'job-123'})),
      ),
      202,
      headers: {'content-type': 'application/json'},
    );
  }

  http.BaseRequest? lastRequest;
}

Uint8List _wavHeaderBytes() => Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  0x24,
  0x00,
  0x00,
  0x00,
  0x57,
  0x41,
  0x56,
  0x45,
]);
