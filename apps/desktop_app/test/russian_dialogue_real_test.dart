import 'dart:convert';
import 'dart:io';

import 'package:desktop_app/services/dialog_backend_adapter.dart';
import 'package:desktop_app/services/open_voice_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

/// Opt-in real CPU/backend acceptance harness. Outputs stay in ignored artifacts.
void main() {
  test(
    'real three-actor application adapter -> persisted project -> shared master',
    () async {
      final repo = Directory('../..').absolute.path;
      final output = Directory(
        '$repo/artifacts/russian-dialogue/app-smoke-${DateTime.now().millisecondsSinceEpoch}',
      );
      await output.create(recursive: true);
      final service = OpenVoiceBackendService();
      addTearDown(service.dispose);
      final adapter = DialogBackendAdapter(service);
      final fixture = jsonDecode(
        await File(
          '$repo/packages/quality_suite/russian_phone_dialogue.json',
        ).readAsString(),
      );
      final script = (fixture['scripts'] as List).firstWhere(
        (script) => script['id'] == 'three_actor',
      );
      final report = jsonDecode(
        await File(
          '$repo/artifacts/russian-dialogue/three-2026-10-09-01/report.json',
        ).readAsString(),
      );
      final workspace = DialogWorkspace(
        directoryProvider: () async => output,
        generate: (request) => adapter.generate(
          request,
          Platform.environment['TTS_REAL_BACKEND']!,
        ),
      );
      addTearDown(workspace.dispose);
      final actors = <String, DialogSpeakerSettings>{};
      for (final actor in (fixture['actors'] as List)) {
        final id = actor['id'];
        final refInfo = (report['actors'] as List).firstWhere(
          (entry) => entry['id'] == id,
        );
        final reference = await workspace.importReference(
          File(
            '$repo/artifacts/russian-dialogue/three-2026-10-09-01/${refInfo['audio']['file']}',
          ),
          refInfo['reference_transcript'],
        );
        actors[actor['name']] =
            DialogSpeakerSettings(speakerName: actor['name'], actorId: id)
                .selectTarget(
                  const SynthesisTarget.backend(
                    modelId: 'openbmb/VoxCPM2',
                    backendId: 'voxcpm2',
                  ),
                  const ModelSynthesisSettings(
                    extensionValues: {
                      'model_revision': voxCpm2Revision,
                      'cfg_value': 2.0,
                      'inference_timesteps': 10,
                      'seed': 42,
                      'retry_badcase': false,
                    },
                  ),
                )
                .withReference(reference);
      }
      final names = {
        for (final actor in fixture['actors'] as List)
          actor['id']: actor['name'],
      };
      workspace.importText(
        (script['turns'] as List)
            .map((turn) => '${names[turn['actor_id']]}: ${turn['text']}')
            .join('\n'),
        (name) => actors[name]!,
      );
      await workspace.generateMissing();
      expect(workspace.error, isNull);
      expect(
        workspace.lines.every((line) => line.status == DialogLineStatus.ready),
        isTrue,
      );
      final originalPaths = workspace.lines
          .map((line) => line.outputPath)
          .toList();
      await workspace.generateMissing(onlyTurnId: workspace.lines.last.id);
      expect(workspace.error, isNull);
      expect(workspace.lines.first.outputPath, originalPaths.first);
      await workspace.save();
      await workspace.load();
      await workspace.render();
      expect(workspace.error, isNull);
      expect(workspace.masterIsCurrent, isTrue);
      final master = PcmWave.decode(
        await File(workspace.masterPath!).readAsBytes(),
      );
      expect(master.sampleRate, 48000);
      await File('${output.path}/technical-acceptance.json').writeAsString(
        jsonEncode({
          'status': 'awaiting_user_listening',
          'turns': workspace.lines.length,
          'sampleRate': master.sampleRate,
          'durationSeconds': master.samples.length / master.sampleRate,
          'modelRevision': voxCpm2Revision,
          'master': workspace.masterPath,
          'checks': [
            'actual HTTP inference',
            'three actors',
            'retry preserves other clips',
            'save/reload',
            'shared render',
          ],
        }),
      );
      // Visible in logs for finding the user-listening artifact.
      // ignore: avoid_print
      print('Real dialogue artifacts: ${output.path}');
    },
    skip: Platform.environment['TTS_REAL_BACKEND'] == null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
