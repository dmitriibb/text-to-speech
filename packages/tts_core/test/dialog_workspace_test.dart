import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

import 'conversation_renderer_test.dart' show waveBytes;

DialogSpeakerSettings defaults(String name) =>
    DialogSpeakerSettings(
      speakerName: name,
      actorId: 'actor-$name',
    ).selectTarget(
      const SynthesisTarget.local('model'),
      const ModelSynthesisSettings(),
    );

void main() {
  late Directory directory;
  late DialogWorkspace workspace;
  final requests = <DialogGenerationRequest>[];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dialog-workspace-test-');
    requests.clear();
    workspace = DialogWorkspace(
      directoryProvider: () async => directory,
      generate: (request) async {
        requests.add(request);
        await File(
          request.outputPath,
        ).writeAsBytes(waveBytes(16000, 1600, (_) => .2));
      },
    );
  });
  tearDown(() async {
    workspace.dispose();
    await directory.delete(recursive: true);
  });
  test(
    'three actors reload, preserve Russian/overrides and timing, and regenerate only changed actor',
    () async {
      workspace.importText(
        'Анна: Алло: ты слышишь?\nСергей: Да, всё хорошо.\nИрина: Встреча в 18:30.',
        defaults,
      );
      await workspace.generateMissing();
      expect(workspace.error, isNull);
      expect(requests.length, 3);
      await workspace.render();
      expect(workspace.masterIsCurrent, isTrue);
      workspace.edit(workspace.lines[1].copyWith(pauseAfterMs: 725));
      expect(workspace.masterIsCurrent, isFalse);
      await workspace.generateMissing();
      expect(requests.length, 3);
      await workspace.save();
      await workspace.load();
      expect(workspace.lines[1].pauseAfterMs, 725);
      expect(
        workspace.lines.every((line) => line.status == DialogLineStatus.ready),
        isTrue,
      );
      expect(workspace.lines[0].text, 'Алло: ты слышишь?');
      workspace.setActor(
        workspace.actors['Сергей']!.withSynthesisSettings(
          const ModelSynthesisSettings(volume: .8),
        ),
      );
      final annaPath = workspace.lines.first.outputPath;
      await workspace.generateMissing();
      expect(requests.length, 4);
      expect(requests.last.actor.speakerName, 'Сергей');
      expect(workspace.lines.first.outputPath, annaPath);
      await workspace.generateMissing(onlyTurnId: workspace.lines.last.id);
      expect(requests.length, 5);
      expect(workspace.lines.first.outputPath, annaPath);
    },
  );
  test(
    'edit/remove/actor changes during generation discard late results',
    () async {
      workspace.dispose();
      final entered = Completer<void>(), release = Completer<void>();
      workspace = DialogWorkspace(
        directoryProvider: () async => directory,
        generate: (request) async {
          requests.add(request);
          entered.complete();
          await release.future;
          await File(
            request.outputPath,
          ).writeAsBytes(waveBytes(16000, 1600, (_) => .2));
        },
      );
      workspace.importText('Анна: Алло?\nСергей: Да.', defaults);
      final generation = workspace.generateMissing();
      await entered.future;
      workspace.edit(workspace.lines.first.copyWith(text: 'Привет!'));
      workspace.remove(workspace.lines.last.id);
      release.complete();
      await generation;
      expect(workspace.lines.single.outputPath, isNull);
      expect(await File(requests.single.outputPath).exists(), isFalse);
    },
  );
  test(
    'cancel stops dispatch, cleans late output and unique identities survive reimport',
    () async {
      workspace.dispose();
      final entered = Completer<void>(), release = Completer<void>();
      workspace = DialogWorkspace(
        directoryProvider: () async => directory,
        generate: (request) async {
          requests.add(request);
          entered.complete();
          await release.future;
          await File(
            request.outputPath,
          ).writeAsBytes(waveBytes(16000, 1600, (_) => .2));
        },
      );
      workspace.importText('Анна: Алло?\nСергей: Да.', defaults);
      final oldId = workspace.lines.first.id;
      final generation = workspace.generateMissing();
      await entered.future;
      workspace.cancel();
      release.complete();
      await generation;
      expect(requests.length, 1);
      expect(workspace.lines.every((line) => !line.hasPlayableAudio), isTrue);
      expect(await File(requests.single.outputPath).exists(), isFalse);
      workspace.importText('Анна: Алло?', defaults);
      expect(workspace.lines.first.id, isNot(oldId));
    },
  );
  test(
    'missing/changed clips block render; corrupt project preserves old master',
    () async {
      workspace.importText('Анна: Алло?\nСергей: Да.', defaults);
      await workspace.generateMissing();
      await workspace.render();
      final previous = workspace.masterPath!;
      await File(workspace.lines.last.outputPath!).writeAsBytes([1, 2, 3]);
      await workspace.render();
      expect(workspace.error, contains('Clip changed'));
      expect(workspace.masterPath, previous);
      await workspace.load();
      expect(workspace.lines.last.hasPlayableAudio, isFalse);
      expect(workspace.masterIsCurrent, isFalse);
      await workspace.render();
      expect(workspace.error, contains('Generate or retry'));
      await File('${directory.path}/project.json').writeAsString('{broken');
      await workspace.load();
      expect(workspace.error, contains('retained'));
      expect(await File(previous).exists(), isTrue);
    },
  );
  test(
    'timing edits during inference survive attachment and never change fingerprint',
    () async {
      workspace.dispose();
      final entered = Completer<void>(), release = Completer<void>();
      workspace = DialogWorkspace(
        directoryProvider: () async => directory,
        generate: (request) async {
          entered.complete();
          await release.future;
          await File(
            request.outputPath,
          ).writeAsBytes(waveBytes(16000, 1600, (_) => .2));
        },
      );
      workspace.importText('Анна: Алло?', defaults);
      final generation = workspace.generateMissing();
      await entered.future;
      workspace.edit(workspace.lines.first.copyWith(pauseAfterMs: 900));
      release.complete();
      await generation;
      expect(workspace.lines.first.pauseAfterMs, 900);
      expect(workspace.lines.first.hasPlayableAudio, isTrue);
    },
  );
}
