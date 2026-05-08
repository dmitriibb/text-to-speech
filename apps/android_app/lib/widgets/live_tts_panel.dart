import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

import '../services/audio_service.dart';
import '../state/app_state.dart';

class LiveTtsPanel extends StatefulWidget {
  const LiveTtsPanel({super.key});

  @override
  State<LiveTtsPanel> createState() => _LiveTtsPanelState();
}

class _LiveTtsPanelState extends State<LiveTtsPanel> {
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

    return LiveTextInputEditor(
      controller: _controller,
      scrollController: _scrollController,
      liveModeEnabled: true,
      isStreaming: state.isLiveTtsStreaming,
      isPlaying:
          state.isLiveTtsStreaming &&
          state.playbackState == PlaybackState.playing,
      chunkSizeWords: state.liveChunkSizeWords,
      onLiveModeChanged: (_) {},
      onChunkSizeChanged: state.setLiveChunkSizeWords,
      onPlayPausePressed: state.livePlayPauseAction,
      onStopPressed: state.isLiveTtsStreaming ? state.stopLiveTts : null,
      onClearPressed: _controller.clear,
      showHeader: false,
      expandEditor: true,
      liveMinLines: 12,
      liveMaxLines: 9999,
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
