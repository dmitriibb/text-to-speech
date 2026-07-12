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
            onLanguageSelected: (_, _) {},
            onVolumeChanged: (_, _) {},
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
                  volume: 7,
                ),
                'Omar': DialogSpeakerSettings(
                  speakerName: 'Omar',
                  modelId: 'model-1',
                  speakerId: 1,
                  volume: 5,
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
              onLanguageSelected: (_, _) {},
              onVolumeChanged: (_, _) {},
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
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byTooltip('Decrease volume'), findsNWidgets(2));
    expect(find.byTooltip('Increase volume'), findsNWidgets(2));
    expect(find.byTooltip('Play line'), findsNWidgets(2));
    expect(find.byTooltip('Remove line'), findsNWidgets(2));
    expect(find.byTooltip('Ready'), findsOneWidget);
    expect(find.byTooltip('Not ready'), findsOneWidget);
  });

  testWidgets(
    'dialog speaker row shows language selector for multilingual model',
    (tester) async {
      var selectedLanguage = '';
      final model = _installedModel(
        id: 'supertonic-3-multilingual',
        displayName: 'Supertonic 3 Multilingual',
        supportedLanguages: const ['English', 'French'],
        generationLanguage: 'en',
        generationLanguages: const [
          VoiceLanguage(code: 'en', name: 'English'),
          VoiceLanguage(code: 'fr', name: 'French'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialogModePanel(
              lines: const [
                DialogLineItem(
                  id: 'line-1',
                  speakerName: 'Narrator',
                  text: 'Bonjour.',
                ),
              ],
              readyModels: [model],
              speakerSettings: const {
                'Narrator': DialogSpeakerSettings(
                  speakerName: 'Narrator',
                  modelId: 'supertonic-3-multilingual',
                  generationLanguage: 'fr',
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
              onLanguageSelected: (_, language) {
                selectedLanguage = language;
              },
              onVolumeChanged: (_, _) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Supertonic 3 Multilingual · English, French'),
        findsOneWidget,
      );
      expect(find.text('French'), findsOneWidget);

      await tester.tap(find.text('French'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);

      expect(selectedLanguage, 'en');
    },
  );
}

InstalledModel _installedModel({
  required String id,
  required String displayName,
  List<Speaker> speakers = const [],
  List<String> supportedLanguages = const [],
  String generationLanguage = '',
  List<VoiceLanguage> generationLanguages = const [],
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
      supportedLanguages: supportedLanguages,
      generationLanguage: generationLanguage,
      generationLanguages: generationLanguages,
    ),
  );
}
