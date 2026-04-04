import 'package:desktop_app/state/app_state.dart';
import 'package:desktop_app/widgets/model_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('keeps install actions visible when one model is already ready', (
    tester,
  ) async {
    final state = _FakeAppState(
      readyModelsValue: [
        InstalledModel(
          voice: _voiceModel(
            id: 'vits-piper-en_US-lessac-medium',
            displayName: 'Piper English Lessac Medium',
          ),
          status: ModelStatus.ready,
          modelDir: '/tmp/vits-piper-en_US-lessac-medium',
        ),
      ],
      installableModelsValue: [
        InstalledModel(
          voice: _voiceModel(
            id: 'pocket-tts-en',
            displayName: 'Pocket TTS English (Voice Cloning)',
            family: 'pocket',
            modelFile: 'lm_flow.int8.onnx',
          ),
          status: ModelStatus.notInstalled,
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ModelStatusBanner())),
      ),
    );

    expect(find.text('1 model ready'), findsOneWidget);
    expect(
      find.text('Install Pocket TTS English (Voice Cloning)'),
      findsOneWidget,
    );
  });
}

class _FakeAppState extends AppState {
  _FakeAppState({
    required this.readyModelsValue,
    required this.installableModelsValue,
  });

  final List<InstalledModel> readyModelsValue;
  final List<InstalledModel> installableModelsValue;

  @override
  bool get isDownloading => false;

  @override
  List<InstalledModel> get readyModels => readyModelsValue;

  @override
  List<InstalledModel> get installableModels => installableModelsValue;

  @override
  Future<void> refreshModels() async {}

  @override
  Future<void> downloadModel(VoiceModel voice) async {}
}

VoiceModel _voiceModel({
  required String id,
  required String displayName,
  String family = 'vits',
  String modelFile = 'model.onnx',
}) {
  return VoiceModel(
    id: id,
    displayName: displayName,
    family: family,
    runtime: 'sherpa-onnx',
    approvedForDistribution: false,
    archiveUrl: 'https://example.com/$id.tar.bz2',
    archiveFormat: 'tar.bz2',
    installDirName: id,
    modelFile: modelFile,
    tokensFile: family == 'pocket' ? '' : 'tokens.txt',
    lexiconFile: '',
    voicesFile: '',
    dataDir: '',
    provider: 'cpu',
    numThreads: 1,
    defaultSpeed: 1.0,
    defaultSpeakerId: 0,
    maxNumSentences: 1,
  );
}
