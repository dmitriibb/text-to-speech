import 'package:flutter_test/flutter_test.dart';

import 'package:desktop_app/app.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Text to Speech'), findsOneWidget);
  });
}
