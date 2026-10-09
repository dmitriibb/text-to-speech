import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_app/services/dialog_backend_adapter.dart';
import 'package:desktop_app/services/open_voice_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tts_core/tts_core.dart';

Uint8List wav() {
  final bytes = Uint8List(44 + 16000 * 2);
  bytes.setRange(0, 44, PcmWave.header(16000, 16000));
  final data = ByteData.sublistView(bytes);
  for (var i = 44; i < bytes.length; i += 2) {
    data.setInt16(i, 8000, Endian.little);
  }
  return bytes;
}

void main() {
  test(
    'reference bytes/settings route through health/jobs/download, gain is applied once and server result cleaned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'backend-dialog-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final referenceFile = File('${directory.path}/ref.wav');
      await referenceFile.writeAsBytes(wav());
      final reference = await DialogReferenceStore(
        projectDirectory: directory,
      ).importWav(referenceFile, transcript: 'Алло, ты слышишь?');
      var posted = false, deleted = false;
      final service = OpenVoiceBackendService(
        client: MockClient((request) async {
          if (request.url.path == '/health') {
            return http.Response(
              jsonEncode({
                'engine': 'voxcpm2',
                'engine_ready': true,
                'models_loaded': false,
                'current_model_id': 'openbmb/VoxCPM2',
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            posted = true;
            final body = utf8.decode(request.bodyBytes, allowMalformed: true);
            expect(body, contains('prompt_text'));
            expect(body, contains('Алло, ты слышишь?'));
            expect(body, contains('reference.wav'));
            expect(body, contains('Привет, всё хорошо.'));
            return http.Response('{"job_id":"job-test"}', 202);
          }
          if (request.method == 'DELETE') {
            deleted = true;
            return http.Response('', 204);
          }
          if (request.url.path.endsWith('/result')) {
            return http.Response.bytes(wav(), 200);
          }
          return http.Response(
            '{"job_id":"job-test","status":"succeeded","result":{"audio_ready":true}}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final actor = const DialogSpeakerSettings(speakerName: 'Анна')
          .selectTarget(
            const SynthesisTarget.backend(
              modelId: 'openbmb/VoxCPM2',
              backendId: 'voxcpm2',
            ),
            const ModelSynthesisSettings(volume: .8),
          )
          .withReference(reference);
      final output = '${directory.path}/turn.wav';
      await DialogBackendAdapter(service).generate(
        DialogGenerationRequest(
          projectId: 'p',
          runId: 'run',
          line: const DialogLineItem(
            id: 'turn',
            speakerName: 'Анна',
            text: 'Привет, всё хорошо.',
          ),
          actor: actor,
          outputPath: output,
          projectDirectory: directory,
          cancellation: DialogCancellation(),
        ),
        'http://localhost:8011',
      );
      expect(posted && deleted, isTrue);
      final decoded = PcmWave.decode(await File(output).readAsBytes());
      expect(decoded.samples.first, closeTo(8000 / 32768 * .8, .0001));
      expect(await File('$output.download').exists(), isFalse);
    },
  );
  test('wrong model and unreachable endpoint cannot become ready', () async {
    final wrong = OpenVoiceBackendService(
      client: MockClient(
        (_) async => http.Response(
          '{"engine":"voxcpm2","engine_ready":true,"current_model_id":"another/model"}',
          200,
        ),
      ),
    );
    addTearDown(wrong.dispose);
    expect(
      (await DialogBackendAdapter(
        wrong,
      ).readiness('http://localhost')).readiness,
      BackendReadiness.reachable,
    );
    final down = OpenVoiceBackendService(
      client: MockClient((_) async => throw const SocketException('down')),
    );
    addTearDown(down.dispose);
    expect(
      (await DialogBackendAdapter(
        down,
      ).readiness('http://localhost')).canGenerate,
      isFalse,
    );
  });
  test('poll cancellation and deadline are bounded', () async {
    final service = OpenVoiceBackendService(
      client: MockClient(
        (_) async => http.Response('{"status":"running"}', 200),
      ),
      delay: (_) async {},
    );
    addTearDown(service.dispose);
    await expectLater(
      service.waitForJobCompletion(
        baseUri: Uri.parse('http://localhost'),
        jobId: 'j',
        isCancelled: () => true,
      ),
      throwsA(isA<OpenVoiceBackendException>()),
    );
    await expectLater(
      service.waitForJobCompletion(
        baseUri: Uri.parse('http://localhost'),
        jobId: 'j',
        deadline: Duration.zero,
      ),
      throwsA(isA<OpenVoiceBackendException>()),
    );
  });
}
