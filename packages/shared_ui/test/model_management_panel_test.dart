import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('keeps install actions visible when one model is already ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelManagementPanel(
            models: [
              InstalledModel(
                voice: _voiceModel(
                  id: 'vits-piper-en_US-lessac-medium',
                  displayName: 'Piper English Lessac Medium',
                ),
                status: ModelStatus.ready,
                modelDir: '/tmp/vits-piper-en_US-lessac-medium',
              ),
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
            selectedModelId: 'vits-piper-en_US-lessac-medium',
            isDownloading: false,
            currentInstallProgress: null,
            canManageModels: true,
            storageDescription: 'Models are stored in app storage.',
            onRefresh: () async {},
            onInstall: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Available models'), findsOneWidget);
    expect(find.text('Piper English Lessac Medium'), findsOneWidget);
    expect(find.text('Pocket TTS English (Voice Cloning)'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
  });
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
