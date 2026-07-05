import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('empty dialog mode shows paste from buffer button', (
    tester,
  ) async {
    var pastePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DialogModePanel(
            lines: const [],
            readyModels: const [],
            speakerSettings: const {},
            isGenerating: false,
            isSequencePlaying: false,
            activeLineId: null,
            errorMessage: null,
            onPasteFromClipboard: () async {
              pastePressed = true;
            },
            onGenerate: () async {},
            onPlayPauseSequence: () async {},
            onStopSequence: () async {},
            onPlayLine: (_) async {},
            onRemoveLine: (_) async {},
            onModelSelected: (_, _) {},
            onSpeakerSelected: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Paste from buffer'));

    expect(pastePressed, isTrue);
  });

  testWidgets('dialog mode renders speaker settings and line actions', (
    tester,
  ) async {
    final model = _installedModel(
      id: 'model-1',
      displayName: 'Dialog Voice',
      speakers: const [
        Speaker(id: 0, name: 'Voice A'),
        Speaker(id: 1, name: 'Voice B'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DialogModePanel(
              lines: const [
                DialogLineItem(
                  id: 'line-1',
                  speakerName: 'Mitarbeiterin',
                  text: 'Guten Tag.',
                  outputPath: '/tmp/line-1.wav',
                  status: DialogLineStatus.ready,
                ),
                DialogLineItem(
                  id: 'line-2',
                  speakerName: 'Omar',
                  text: 'Guten Tag.',
                  status: DialogLineStatus.idle,
                ),
              ],
              readyModels: [model],
              speakerSettings: const {
                'Mitarbeiterin': DialogSpeakerSettings(
                  speakerName: 'Mitarbeiterin',
                  modelId: 'model-1',
                  speakerId: 0,
                ),
                'Omar': DialogSpeakerSettings(
                  speakerName: 'Omar',
                  modelId: 'model-1',
                  speakerId: 1,
                ),
              },
              isGenerating: false,
              isSequencePlaying: false,
              activeLineId: null,
              errorMessage: null,
              onPasteFromClipboard: () async {},
              onGenerate: () async {},
              onPlayPauseSequence: () async {},
              onStopSequence: () async {},
              onPlayLine: (_) async {},
              onRemoveLine: (_) async {},
              onModelSelected: (_, _) {},
              onSpeakerSelected: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mitarbeiterin'), findsNWidgets(2));
    expect(find.text('Omar'), findsNWidgets(2));
    expect(find.text('Dialog Voice'), findsWidgets);
    expect(find.text('Voice A'), findsWidgets);
    expect(find.text('Voice B'), findsWidgets);
    expect(find.byTooltip('Play line'), findsNWidgets(2));
    expect(find.byTooltip('Remove line'), findsNWidgets(2));
    expect(find.byTooltip('Ready'), findsOneWidget);
    expect(find.byTooltip('Not ready'), findsOneWidget);
  });
}

InstalledModel _installedModel({
  required String id,
  required String displayName,
  List<Speaker> speakers = const [],
}) {
  return InstalledModel(
    status: ModelStatus.ready,
    modelDir: '/tmp/model',
    voice: VoiceModel(
      id: id,
      displayName: displayName,
      family: 'vits',
      runtime: 'sherpa-onnx',
      approvedForDistribution: false,
      archiveUrl: 'https://example.com/model.tar.bz2',
      archiveFormat: 'tar.bz2',
      installDirName: id,
      modelFile: 'model.onnx',
      tokensFile: 'tokens.txt',
      lexiconFile: '',
      voicesFile: '',
      dataDir: '',
      provider: 'cpu',
      numThreads: 1,
      defaultSpeed: 1,
      defaultSpeakerId: 0,
      maxNumSentences: 1,
      speakers: speakers,
    ),
  );
}
