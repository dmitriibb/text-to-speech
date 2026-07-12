import 'package:android_app/state/app_state.dart';
import 'package:android_app/widgets/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('android settings panel shows speaker selector for Kokoro', (
    tester,
  ) async {
    final state = _FakeAppState(
      readyModelsValue: [
        InstalledModel(
          voice: _kokoroModel,
          status: ModelStatus.ready,
          modelDir: '/tmp/kokoro-en-v0_19',
        ),
      ],
      selectedModelValue: InstalledModel(
        voice: _kokoroModel,
        status: ModelStatus.ready,
        modelDir: '/tmp/kokoro-en-v0_19',
      ),
      selectedSpeakerIdValue: 1,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 420, child: SettingsPanel())),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI model'), findsWidgets);
    await tester.tap(find.byTooltip('Model settings'));
    await tester.pumpAndSettle();
    expect(find.text('Voice / speaker'), findsOneWidget);
    expect(find.text('AF Bella'), findsOneWidget);
    expect(find.text('0.5'), findsNWidgets(2));
    expect(find.text('2.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAppState extends AppState {
  _FakeAppState({
    required this.readyModelsValue,
    required this.selectedModelValue,
    required this.selectedSpeakerIdValue,
  });

  final List<InstalledModel> readyModelsValue;
  final InstalledModel? selectedModelValue;
  final int selectedSpeakerIdValue;

  @override
  List<InstalledModel> get readyModels => readyModelsValue;

  @override
  InstalledModel? get selectedModel => selectedModelValue;

  @override
  int get selectedSpeakerId => selectedSpeakerIdValue;

  @override
  ModelSynthesisSettings get modelSettings =>
      ModelSynthesisSettings(speakerId: selectedSpeakerIdValue);

  @override
  double get speed => speechSpeedDefault;

  @override
  bool get canSelectModel => true;

  @override
  bool get canAdjustSpeed => true;

  @override
  void setSpeakerId(int speakerId) {}

  @override
  void setSpeed(double speed) {}

  @override
  Future<void> selectModel(InstalledModel model) async {}
}

const VoiceModel _kokoroModel = VoiceModel(
  id: 'kokoro-en-v0_19',
  displayName: 'Kokoro English (11 speakers)',
  family: 'kokoro',
  runtime: 'sherpa-onnx',
  approvedForDistribution: false,
  archiveUrl: 'https://example.com/kokoro.tar.bz2',
  archiveFormat: 'tar.bz2',
  installDirName: 'kokoro-en-v0_19',
  modelFile: 'model.onnx',
  tokensFile: 'tokens.txt',
  lexiconFile: '',
  voicesFile: 'voices.bin',
  dataDir: 'espeak-ng-data',
  provider: 'cpu',
  numThreads: 2,
  defaultSpeed: 1.0,
  defaultSpeakerId: 0,
  maxNumSentences: 1,
  speakers: [
    Speaker(id: 0, name: 'AF (default)'),
    Speaker(id: 1, name: 'AF Bella'),
  ],
);
