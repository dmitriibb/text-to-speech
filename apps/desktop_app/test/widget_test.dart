import 'package:desktop_app/widgets/app_navigation_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop navigation drawer exposes backend models destination', (
    tester,
  ) async {
    AppDestination? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          drawer: AppNavigationDrawer(
            selectedDestination: AppDestination.home,
            onDestinationSelected: (destination) {
              selectedDestination = destination;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live TTS'), findsOneWidget);
    expect(find.text('Dialog'), findsOneWidget);
    expect(find.text('Models'), findsOneWidget);
    expect(find.text('Backend models'), findsOneWidget);

    await tester.tap(find.text('Backend models'));
    expect(selectedDestination, AppDestination.voiceLab);
  });
}
