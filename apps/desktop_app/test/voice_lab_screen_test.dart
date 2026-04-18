import 'package:desktop_app/models/cloned_voice.dart';
import 'package:desktop_app/screens/voice_lab_screen.dart';
import 'package:desktop_app/services/open_voice_backend_service.dart';
import 'package:desktop_app/state/app_state.dart';
import 'package:desktop_app/state/voice_lab_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('enables import after choosing an audio file', (tester) async {
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Choose Audio File'));
    await tester.pump();

    importButton = tester.widget(find.widgetWithText(FilledButton, 'Import'));
    expect(importButton.onPressed, isNotNull);
    expect(find.text('narrator'), findsOneWidget);
  });

  testWidgets('auto-fills the voice name for MP3 imports too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceSampleImportDialog(
            openVoiceSampleFile: () async => '/tmp/podcast-host.mp3',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Choose Audio File'));
    await tester.pump();

    final importButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import'),
    );
    expect(importButton.onPressed, isNotNull);
    expect(find.text('podcast-host'), findsOneWidget);
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

    expect(find.text('Voice Library'), findsOneWidget);
    expect(find.text('OpenVoice'), findsOneWidget);
    expect(find.text('Generate With Cloned Voice'), findsOneWidget);
    expect(find.text('Generate Speech'), findsOneWidget);
    expect(find.text('Shared Text Input'), findsNothing);
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

    final pocketToggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Voice cloning Pocket TTS'),
    );
    final openVoiceToggle = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Voice cloning OpenVoice'),
    );

    expect(pocketToggle.onChanged, isNull);
    expect(openVoiceToggle.onChanged, isNotNull);
  });

  testWidgets('Pocket section is hidden while Pocket toggle is off', (
    tester,
  ) async {
    final state = _FakeVoiceLabState()
      ..isPocketVoiceCloningEnabledValue = false
      ..isOpenVoiceEnabledValue = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceLabPanel(stateOverride: state)),
      ),
    );
    await tester.pump();

    expect(find.text('Import Voice Sample'), findsNothing);
    expect(find.text('Voice Library'), findsNothing);
    expect(find.text('OpenVoice'), findsOneWidget);
    expect(find.text('Generate Speech'), findsOneWidget);
  });

  testWidgets('OpenVoice section is hidden while OpenVoice toggle is off', (
    tester,
  ) async {
    final state = _FakeVoiceLabState()
      ..isPocketVoiceCloningEnabledValue = true
      ..isOpenVoiceEnabledValue = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceLabPanel(stateOverride: state)),
      ),
    );
    await tester.pump();

    expect(find.text('Import Voice Sample'), findsOneWidget);
    expect(find.text('Voice Library'), findsOneWidget);
    expect(find.text('Generate Speech'), findsNothing);
  });

  testWidgets('OpenVoice section advertises WAV and MP3 reference audio', (
    tester,
  ) async {
    final state = _FakeVoiceLabState()
      ..isPocketVoiceCloningEnabledValue = false
      ..isOpenVoiceEnabledValue = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VoiceLabPanel(stateOverride: state)),
      ),
    );
    await tester.pump();

    expect(find.text('Select Reference Audio'), findsOneWidget);
    expect(
      find.textContaining('accepts a WAV or MP3 reference sample'),
      findsOneWidget,
    );
    expect(
      find.text('No OpenVoice reference audio selected yet.'),
      findsOneWidget,
    );
  });

  testWidgets('VoiceLabPanel uses app-scoped VoiceLabState when provided', (
    tester,
  ) async {
    final state = _FakeVoiceLabState()
      ..isPocketVoiceCloningEnabledValue = false
      ..isOpenVoiceEnabledValue = true;

    await tester.pumpWidget(
      ChangeNotifierProvider<VoiceLabState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: VoiceLabPanel())),
      ),
    );
    await tester.pump();

    expect(find.text('Generate Speech'), findsOneWidget);
    expect(find.text('Voice cloning OpenVoice'), findsOneWidget);
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
  bool isPocketVoiceCloningEnabledValue = true;
  bool isOpenVoiceEnabledValue = true;
  final String sharedInputTextValue;
  final List<ClonedVoice> voicesValue;
  String openVoiceBackendUrlValue = OpenVoiceBackendService.defaultBaseUrl;
  OpenVoiceBackendConnectionState openVoiceConnectionStateValue =
      OpenVoiceBackendConnectionState.disconnected;
  String? openVoiceBackendMessageValue;
  String? openVoiceSamplePathValue;
  bool isOpenVoiceGenerationSubmittingValue = false;

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
  bool get isPocketVoiceCloningEnabled => isPocketVoiceCloningEnabledValue;

  @override
  bool get isOpenVoiceEnabled => isOpenVoiceEnabledValue;

  @override
  bool get hasSharedInputText => sharedInputTextValue.trim().isNotEmpty;

  @override
  String get openVoiceBackendUrl => openVoiceBackendUrlValue;

  @override
  OpenVoiceBackendConnectionState get openVoiceConnectionState =>
      openVoiceConnectionStateValue;

  @override
  String? get openVoiceBackendMessage => openVoiceBackendMessageValue;

  @override
  String? get openVoiceSamplePath => openVoiceSamplePathValue;

  @override
  bool get isOpenVoiceGenerationSubmitting =>
      isOpenVoiceGenerationSubmittingValue;

  @override
  bool get canGenerateWithOpenVoice => true;

  @override
  Future<void> setVoiceCloningEnabled(bool enabled) async {
    isPocketVoiceCloningEnabledValue = enabled;
    notifyListeners();
  }

  @override
  Future<void> setOpenVoiceEnabled(bool enabled) async {
    isOpenVoiceEnabledValue = enabled;
    notifyListeners();
  }

  @override
  Future<void> setOpenVoiceBackendUrl(String backendUrl) async {
    openVoiceBackendUrlValue = backendUrl;
  }

  @override
  void setOpenVoiceSamplePath(String? samplePath) {
    openVoiceSamplePathValue = samplePath;
  }

  @override
  Future<void> checkOpenVoiceConnection() async {}

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

  @override
  Future<void> generateWithOpenVoice() async {}
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
