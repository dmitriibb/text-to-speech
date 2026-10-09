import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  const backend = SynthesisTarget.backend(
    modelId: 'VoxCPM2',
    backendId: 'voxcpm2',
  );
  const local = SynthesisTarget.local('existing-piper-id');

  test(
    'same-model actors retain separate settings and references across reload',
    () {
      const defaults = ModelSynthesisSettings(
        speed: 1.1,
        extensionValues: {'style': 'calm'},
      );
      var anna = const DialogSpeakerSettings(
        speakerName: 'Анна',
        actorId: 'actor-1',
      ).selectTarget(backend, defaults);
      final sergey =
          const DialogSpeakerSettings(speakerName: 'Сергей', actorId: 'actor-2')
              .selectTarget(backend, defaults)
              .withReference(_reference('b', 'Да, слышу.'));
      anna = anna
          .withSynthesisSettings(
            anna.synthesisSettings.copyWith(
              speed: 1.5,
              volume: 1.05,
              generationLanguage: 'ru',
              extensionValues: {'style': 'warm', 'seed': 42},
            ),
          )
          .withReference(_reference('a', 'Алло? Ты меня слышишь?'));

      expect(sergey.speed, 1.1);
      expect(sergey.synthesisSettings.extensionValues['style'], 'calm');
      expect(defaults.speed, 1.1);
      expect(defaults.extensionValues['style'], 'calm');
      anna = anna.selectTarget(local, const ModelSynthesisSettings(speed: 0.8));
      expect(anna.reference, isNull);
      anna = anna.selectTarget(backend, const ModelSynthesisSettings());
      expect(anna.speed, 1.5);
      expect(anna.volumeGain, 1.05);

      final profiles = [anna, sergey].map((actor) => actor.toJson()).toList();
      final decoded = jsonDecode(jsonEncode(profiles)) as List;
      final restored = decoded
          .map(
            (value) => DialogSpeakerSettings.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          )
          .toList();
      expect(restored[0].actorId, 'actor-1');
      expect(restored[0].speed, 1.5);
      expect(restored[0].reference!.transcript, 'Алло? Ты меня слышишь?');
      expect(restored[1].reference!.sha256, 'b' * 64);
      expect(restored[1].speed, 1.1);
      expect(restored[0].selectTarget(local, defaults).speed, 0.8);
      expect(restored[0].copyWith(speakerName: 'Аня').actorId, 'actor-1');
    },
  );

  test('queued actor settings detach and freeze nested model extensions', () {
    final values = <String, Object?>{
      'style': 'calm',
      'weights': <Object?>[1, 2],
    };
    final defaults = ModelSynthesisSettings(extensionValues: {'voice': values});
    final actor = const DialogSpeakerSettings(
      speakerName: 'Анна',
    ).selectTarget(backend, defaults);
    values['style'] = 'changed';
    (values['weights'] as List).add(3);
    final saved = actor.synthesisSettings.extensionValues['voice'] as Map;
    expect(saved['style'], 'calm');
    expect(saved['weights'], [1, 2]);
    expect(() => saved['style'] = 'mutated', throwsUnsupportedError);
    expect(() => (saved['weights'] as List).add(4), throwsUnsupportedError);
    expect(() => actor.modelSettingsByTarget.clear(), throwsUnsupportedError);
    expect(
      () =>
          ModelSynthesisSettings(extensionValues: {'bad': Object()}).snapshot(),
      throwsArgumentError,
    );
    expect(
      () => const ModelSynthesisSettings(
        extensionValues: {'bad': double.nan},
      ).snapshot(),
      throwsArgumentError,
    );
  });

  test('legacy volume migrates once to gain and local model ID survives', () {
    final actor = DialogSpeakerSettings.fromJson({
      'speakerName': 'Анна',
      'modelId': 'existing-piper-id',
      'volume': 7,
      'speed': 1.2,
      'speakerId': 2,
      'generationLanguage': 'ru',
    });
    expect(actor.effectiveTarget!.settingsKey, 'existing-piper-id');
    expect(actor.volumeGain, 1);
    expect(actor.speed, 1.2);
    expect(actor.speakerId, 2);
    final reloaded = DialogSpeakerSettings.fromJson(actor.toJson());
    expect(reloaded.volumeGain, 1);
    expect(reloaded.toJson().containsKey('volume'), isFalse);
    final quiet = DialogSpeakerSettings.fromJson({
      'speakerName': 'Сергей',
      'modelId': 'existing-piper-id',
      'volume': 1,
    });
    expect(quiet.volumeGain, modelVolumeMin);
  });

  test('backend readiness does not depend on fabricated local model files', () {
    expect(local.settingsKey, 'existing-piper-id');
    expect(backend.settingsKey, isNot(local.settingsKey));
    for (final readiness in BackendReadiness.values) {
      final status = BackendTargetStatus(
        target: backend,
        endpoint: Uri.parse('http://localhost:8011'),
        readiness: readiness,
      );
      expect(
        status.canGenerate,
        readiness == BackendReadiness.loadable ||
            readiness == BackendReadiness.loaded,
      );
    }
    expect(SynthesisTarget.fromJson(backend.toJson()).backendId, 'voxcpm2');
    expect(
      () => SynthesisTarget.fromJson({'kind': 'backend', 'modelId': 'x'}),
      throwsFormatException,
    );
  });

  test(
    'reference metadata preserves Cyrillic and rejects external or escaping paths',
    () {
      final reference = _reference('a', 'Ещё: в пятницу.');
      expect(
        DialogReferenceAsset.fromJson(reference.toJson()).transcript,
        'Ещё: в пятницу.',
      );
      for (final path in [
        '',
        '../voice.wav',
        '/voice.wav',
        'C:/voice.wav',
        r'references\voice.wav',
        'references/../voice.wav',
        'references//voice.wav',
      ]) {
        expect(
          () => DialogReferenceAsset(
            relativePath: path,
            sha256: 'a' * 64,
            transcript: '',
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => DialogReferenceAsset(
          relativePath: 'references/voice.wav',
          sha256: 'bad',
          transcript: '',
        ),
        throwsArgumentError,
      );
      expect(
        () => DialogSpeakerSettings.fromJson({'version': 999}),
        throwsFormatException,
      );
    },
  );
}

DialogReferenceAsset _reference(String hash, String transcript) =>
    DialogReferenceAsset(
      relativePath: 'references/$hash.wav',
      sha256: hash * 64,
      transcript: transcript,
    );
