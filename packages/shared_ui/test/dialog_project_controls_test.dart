import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets(
    'project controls fit a narrow screen and edit explicit overrides/timing',
    (tester) async {
      final workspace = DialogWorkspace(
        directoryProvider: () async => Directory.systemTemp,
        generate: (_) async {},
      );
      addTearDown(workspace.dispose);
      workspace.importText(
        'Анна: Алло, ты меня слышишь?\nСергей: Да, всё хорошо.',
        (name) => DialogSpeakerSettings(speakerName: name),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: DialogModePanel(
                    lines: workspace.lines,
                    readyModels: const [],
                    speakerSettings: workspace.actors,
                    workspace: workspace,
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
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byTooltip('Edit text / timing / inclusion').first,
      );
      await tester.tap(find.byTooltip('Edit text / timing / inclusion').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(1),
        'Алло́, ты меня слы́шишь?',
      );
      await tester.tap(find.text('Include in conversation'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(workspace.lines.first.text, 'Алло, ты меня слышишь?');
      expect(workspace.lines.first.textOverride, 'Алло́, ты меня слы́шишь?');
      expect(workspace.lines.first.included, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
