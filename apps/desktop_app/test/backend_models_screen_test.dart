import 'package:desktop_app/screens/backend_models_screen.dart';
import 'package:desktop_app/state/app_state.dart';
import 'package:desktop_app/state/voice_lab_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('lists every separately configured model backend', (
    tester,
  ) async {
    final state = VoiceLabState(appState: AppState());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<VoiceLabState>.value(
        value: state,
        child: const MaterialApp(home: BackendModelsScreen()),
      ),
    );

    expect(find.text('OpenVoice'), findsOneWidget);
    expect(find.text('OmniVoice'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('VoxCPM2'), findsOneWidget);
  });
}
