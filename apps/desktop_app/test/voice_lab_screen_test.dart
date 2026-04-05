import 'package:desktop_app/models/cloned_voice.dart';
import 'package:desktop_app/screens/voice_lab_screen.dart';
import 'package:desktop_app/state/app_state.dart';
import 'package:desktop_app/state/voice_lab_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('enables import after choosing a WAV file', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceSampleImportDialog(
            openVoiceSampleFile: () async => '/tmp/narrator.wav',
          ),
        ),
      ),
    );
    await tester.pump();

    FilledButton importButton = tester.widget(
      find.widgetWithText(FilledButton, 'Import'),
    );
    expect(importButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Choose WAV File'));
    await tester.pump();

    importButton = tester.widget(find.widgetWithText(FilledButton, 'Import'));
    expect(importButton.onPressed, isNotNull);
    expect(find.text('narrator'), findsOneWidget);
  });

  testWidgets('embedded voice lab panel uses shared basic text', (
    tester,
  ) async {
    final state = _FakeVoiceLabState(
      sharedInputTextValue: 'Shared text from the Basic panel',
      voicesValue: [
        ClonedVoice(
          id: 'voice-1',
          name: 'Narrator',
          referenceAudioPath: '/tmp/narrator.wav',
          createdAt: DateTime(2026, 4, 5),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceLabPanel(stateOverride: state)),
      ),
    );
    await tester.pump();

    expect(find.text('Shared Text Input'), findsOneWidget);
    expect(find.text('Shared text from the Basic panel'), findsOneWidget);
    expect(find.text('Generate With Cloned Voice'), findsOneWidget);
    expect(find.text('Enter text to speak with this voice...'), findsNothing);
  });

  testWidgets('voice cloning toggle is disabled without Pocket TTS', (
    tester,
  ) async {
    final state = _FakeVoiceLabState(hasPocketModelValue: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceLabPanel(stateOverride: state)),
      ),
    );
    await tester.pump();

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.onChanged, isNull);
  });

  test('enabling voice cloning auto-selects Pocket TTS', () async {
    final pocketModel = InstalledModel(
      voice: _pocketVoiceModel,
      status: ModelStatus.ready,
      modelDir: '/tmp/pocket',
    );
    final kokoroModel = InstalledModel(
      voice: _kokoroVoiceModel,
      status: ModelStatus.ready,
      modelDir: '/tmp/kokoro',
    );
    final state = _FakeDesktopAppState(
      installedModelsValue: [kokoroModel, pocketModel],
      selectedModelValue: kokoroModel,
    );

    await state.setVoiceCloningEnabled(true);

    expect(state.isVoiceCloningEnabled, isTrue);
    expect(state.selectedModelValue?.voice.id, _pocketVoiceModel.id);
    expect(state.lastSelectedModel?.voice.id, _pocketVoiceModel.id);
  });
}

class _FakeVoiceLabState extends VoiceLabState {
  _FakeVoiceLabState({
    this.hasPocketModelValue = true,
    this.sharedInputTextValue = '',
    this.voicesValue = const [],
  }) : super(appState: _FakeDesktopAppState(installedModelsValue: const []));

  final bool hasPocketModelValue;
  bool isVoiceCloningEnabledValue = true;
  final String sharedInputTextValue;
  final List<ClonedVoice> voicesValue;

  @override
  Future<void> initialize() async {}

  @override
  List<ClonedVoice> get voices => voicesValue;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get hasPocketModel => hasPocketModelValue;

  @override
  bool get isVoiceCloningEnabled => isVoiceCloningEnabledValue;

  @override
  bool get hasSharedInputText => sharedInputTextValue.trim().isNotEmpty;

  @override
  String get sharedInputText => sharedInputTextValue.trim();

  @override
  String? get selectedModelName => 'Kokoro English (11 speakers)';

  @override
  bool get isPocketModelSelected => false;

  @override
  Future<void> setVoiceCloningEnabled(bool enabled) async {
    isVoiceCloningEnabledValue = enabled;
    notifyListeners();
  }

  @override
  Future<void> addVoice({
    required String name,
    required String audioPath,
  }) async {}

  @override
  Future<void> previewVoice(ClonedVoice voice) async {}

  @override
  Future<void> stopPreview() async {}

  @override
  Future<void> removeVoice(String voiceId) async {}

  @override
  Future<void> generateWithClonedVoice({required ClonedVoice voice}) async {}
}

class _FakeDesktopAppState extends AppState {
  _FakeDesktopAppState({
    required this.installedModelsValue,
    this.selectedModelValue,
  });

  final List<InstalledModel> installedModelsValue;
  InstalledModel? selectedModelValue;
  InstalledModel? lastSelectedModel;

  @override
  List<InstalledModel> get installedModels => installedModelsValue;

  @override
  InstalledModel? get selectedModel => selectedModelValue;

  @override
  Future<void> selectModel(InstalledModel model) async {
    lastSelectedModel = model;
    selectedModelValue = model;
  }
}

const VoiceModel _pocketVoiceModel = VoiceModel(
  id: 'pocket-tts-en',
  displayName: 'Pocket TTS English (Voice Cloning)',
  family: 'pocket',
  runtime: 'sherpa-onnx',
  approvedForDistribution: false,
  archiveUrl: 'https://example.com/pocket.tar.bz2',
  archiveFormat: 'tar.bz2',
  installDirName: 'pocket-tts-en',
  modelFile: 'lm_flow.int8.onnx',
  tokensFile: '',
  lexiconFile: '',
  voicesFile: '',
  dataDir: '',
  provider: 'cpu',
  numThreads: 1,
  defaultSpeed: 1,
  defaultSpeakerId: 0,
  maxNumSentences: 1,
  pocketLmMain: 'lm_main.int8.onnx',
  pocketEncoder: 'encoder.onnx',
  pocketDecoder: 'decoder.int8.onnx',
  pocketTextConditioner: 'text_conditioner.onnx',
  pocketVocabJson: 'vocab.json',
  pocketTokenScoresJson: 'token_scores.json',
);

const VoiceModel _kokoroVoiceModel = VoiceModel(
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
  defaultSpeed: 1,
  defaultSpeakerId: 0,
  maxNumSentences: 1,
);
