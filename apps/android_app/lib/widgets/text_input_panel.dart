import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

import '../state/app_state.dart';

class TextInputPanel extends StatefulWidget {
  const TextInputPanel({super.key});

  @override
  State<TextInputPanel> createState() => _TextInputPanelState();
}

class _TextInputPanelState extends State<TextInputPanel> {
  late final HighlightedTextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = HighlightedTextEditingController();
    _scrollController = ScrollController();
    _controller.addListener(() {
      final state = context.read<AppState>();
      state.setInputText(_controller.text);
      state.setInputCursorOffset(_controller.selection.baseOffset);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _syncControllerText(state);
    _controller.setHighlights(_buildHighlights(context, state.liveTtsChunks));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LiveTextInputEditor(
          controller: _controller,
          scrollController: _scrollController,
          liveModeEnabled: state.isLiveTtsEnabled,
          isStreaming: state.isLiveTtsStreaming,
          chunkSizeWords: state.liveChunkSizeWords,
          onLiveModeChanged: state.setLiveTtsEnabled,
          onChunkSizeChanged: state.setLiveChunkSizeWords,
          onPlayPressed: state.canGenerate ? () => state.startLiveTts() : null,
          onStopPressed: state.stopLiveTts,
          onClearPressed: _controller.clear,
          normalMinLines: 4,
          normalMaxLines: 8,
          liveMinLines: 10,
          liveMaxLines: 16,
          footer: GenerationEstimateSummary(
            expectedGenerationDuration: state.expectedGenerationDuration,
            expectedOutputDuration: state.expectedOutputDuration,
          ),
        ),
      ),
    );
  }

  void _syncControllerText(AppState state) {
    final nextText = state.inputText;
    if (_controller.text == nextText) {
      return;
    }

    final preferredOffset = state.inputCursorOffset.clamp(0, nextText.length);
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: preferredOffset),
    );
  }

  List<TextHighlightRange> _buildHighlights(
    BuildContext context,
    List<LiveTtsChunk> chunks,
  ) {
    final theme = Theme.of(context);
    final nextReadyIndex = chunks.indexWhere(
      (chunk) => chunk.status == LiveTtsChunkStatus.ready,
    );
    final highlights = <TextHighlightRange>[];

    for (final chunk in chunks) {
      Color? backgroundColor;
      if (chunk.status == LiveTtsChunkStatus.playing) {
        backgroundColor = theme.colorScheme.tertiary.withValues(alpha: 0.28);
      } else if (chunk.status == LiveTtsChunkStatus.generating) {
        backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.14);
      } else if (chunk.status == LiveTtsChunkStatus.ready &&
          chunk.index == nextReadyIndex) {
        backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.24);
      }

      if (backgroundColor != null) {
        highlights.add(
          TextHighlightRange(
            start: chunk.startOffset,
            end: chunk.endOffset,
            backgroundColor: backgroundColor,
          ),
        );
      }
    }

    return highlights;
  }
}
