import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets(
    'live text input editor shows live controls and preserves highlight spans',
    (tester) async {
      final controller = HighlightedTextEditingController()
        ..text = 'Alpha beta gamma';
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      controller.setHighlights([
        const TextHighlightRange(
          start: 6,
          end: 10,
          backgroundColor: Colors.blue,
        ),
      ]);

      late BuildContext capturedContext;
      var playPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return LiveTextInputEditor(
                  controller: controller,
                  scrollController: scrollController,
                  liveModeEnabled: true,
                  isStreaming: false,
                  isPlaying: false,
                  chunkSizeWords: 10,
                  onLiveModeChanged: (_) {},
                  onChunkSizeChanged: (_) {},
                  onClearPressed: controller.clear,
                  onPlayPausePressed: () {
                    playPressed = true;
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Chunk words'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(playPressed, isTrue);

      final span = controller.buildTextSpan(
        context: capturedContext,
        style: const TextStyle(),
        withComposing: false,
      );
      final highlightedChild = span.children!.whereType<TextSpan>().firstWhere(
        (child) => child.text == 'beta',
      );
      expect(highlightedChild.style?.backgroundColor, Colors.blue);
    },
  );
}
