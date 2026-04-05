import 'package:desktop_app/screens/voice_lab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
