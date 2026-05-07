import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('shows compact rows and expands to reveal model details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 800,
              child: ModelManagementPanel(
                models: [
                  InstalledModel(
                    voice: _voiceModel(
                      id: 'vits-piper-en_US-lessac-medium',
                      displayName: 'Piper English Lessac Medium',
                      sizeMb: 64,
                      description: 'Small and fast English voice.',
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
                      sizeMb: 203,
                      description: 'Voice cloning model.',
                    ),
                    status: ModelStatus.notInstalled,
                  ),
                ],
                isDownloading: false,
                currentInstallProgress: null,
                canManageModels: true,
                onRefresh: () async {},
                onInstall: (_) async {},
                onDelete: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('64 MB'), findsOneWidget);
    expect(find.text('203 MB'), findsOneWidget);
    expect(find.text('Delete downloaded files'), findsNothing);
    expect(find.text('Install model'), findsNothing);

    await tester.tap(find.text('Piper English Lessac Medium'));
    await tester.pumpAndSettle();

    expect(find.text('Delete downloaded files'), findsOneWidget);
    expect(find.text('Installed at'), findsOneWidget);
    expect(find.text('/tmp/vits-piper-en_US-lessac-medium'), findsOneWidget);
    expect(find.text('Model family'), findsOneWidget);
    expect(find.text('VITS'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('Sherpa ONNX'), findsOneWidget);

    await tester.tap(find.text('Pocket TTS English (Voice Cloning)'));
    await tester.pumpAndSettle();

    expect(find.text('Install model'), findsOneWidget);
    expect(find.text('Supported languages'), findsWidgets);
    expect(find.text('English'), findsWidgets);
  });
}

VoiceModel _voiceModel({
  required String id,
  required String displayName,
  String family = 'vits',
  String modelFile = 'model.onnx',
  double sizeMb = 0,
  String description = '',
}) {
  return VoiceModel(
    id: id,
    displayName: displayName,
    family: family,
    runtime: 'sherpa-onnx',
    sizeMb: sizeMb,
    supportedLanguages: const ['English'],
    description: description,
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
