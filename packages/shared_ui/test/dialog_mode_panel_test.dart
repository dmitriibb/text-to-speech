import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets(
    'applying one actor modal preserves the other actor and exact gain',
    (tester) async {
      final model = _installedModel(id: 'shared', displayName: 'Shared voice');
      var profiles = {
        'Анна': const DialogSpeakerSettings(speakerName: 'Анна').selectTarget(
          const SynthesisTarget.local('shared'),
          const ModelSynthesisSettings(speed: 1.1, volume: 1.05),
        ),
        'Сергей': const DialogSpeakerSettings(speakerName: 'Сергей')
            .selectTarget(
              const SynthesisTarget.local('shared'),
              const ModelSynthesisSettings(speed: 0.8, volume: 0.9),
            ),
      };
      final changed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => DialogModePanel(
                lines: const [
                  DialogLineItem(id: '1', speakerName: 'Анна', text: 'Алло?'),
                  DialogLineItem(id: '2', speakerName: 'Сергей', text: 'Да.'),
                ],
                readyModels: [model],
                speakerSettings: profiles,
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
                onSettingsChanged: (name, settings) {
                  changed.add(name);
                  setState(
                    () => profiles = {
                      ...profiles,
                      name: profiles[name]!.withSynthesisSettings(settings),
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Model settings').first);
      await tester.pumpAndSettle();
      expect(find.text('1.05×'), findsOneWidget);
      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      sliders[1].onChanged!(1.5);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(changed, ['Анна']);
      expect(profiles['Анна']!.speed, 1.5);
      expect(profiles['Анна']!.volumeGain, 1.05);
      expect(profiles['Сергей']!.speed, 0.8);
      expect(profiles['Сергей']!.volumeGain, 0.9);
      await tester.tap(find.byTooltip('Model settings').last);
      await tester.pumpAndSettle();
      expect(find.text('0.80×'), findsOneWidget);
      expect(find.text('0.90×'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(changed, ['Анна']);
    },
  );

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
            onSettingsChanged: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Paste from buffer'));

    expect(pastePressed, isTrue);
  });

  testWidgets('failed first import shows the error and skipped source rows', (
    tester,
  ) async {
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
            errorMessage: 'No valid transcript rows.',
            importIssues: const [
              DialogImportIssue(
                sourceLineNumber: 3,
                sourceText: 'Ещё одна строка',
                message: 'Expected Speaker: text.',
              ),
            ],
            onPasteFromClipboard: () async {},
            onGenerate: () async {},
            onPlayPauseSequence: () async {},
            onStopSequence: () async {},
            onPlayLine: (_) async {},
            onRemoveLine: (_) async {},
            onModelSelected: (_, _) {},
            onSettingsChanged: (_, _) {},
          ),
        ),
      ),
    );
    expect(find.text('No valid transcript rows.'), findsOneWidget);
    await tester.tap(find.text('Skipped 1 transcript row'));
    await tester.pumpAndSettle();
    expect(find.text('Line 3: Expected Speaker: text.'), findsOneWidget);
    expect(find.text('Ещё одна строка'), findsOneWidget);
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
              onSettingsChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mitarbeiterin'), findsNWidgets(2));
    expect(find.text('Omar'), findsNWidgets(2));
    expect(find.text('Dialog Voice'), findsWidgets);
    expect(find.byTooltip('Model settings'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Model settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Voice A'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
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
              onSettingsChanged: (_, settings) {
                selectedLanguage = settings.generationLanguage;
              },
            ),
          ),
        ),
      );

      expect(
        find.text('Supertonic 3 Multilingual · English, French'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Model settings'));
      await tester.pumpAndSettle();
      expect(find.text('French'), findsOneWidget);

      await tester.tap(find.text('French'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

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
