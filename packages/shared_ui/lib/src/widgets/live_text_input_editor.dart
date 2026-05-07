import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextHighlightRange {
  const TextHighlightRange({
    required this.start,
    required this.end,
    required this.backgroundColor,
  });

  final int start;
  final int end;
  final Color backgroundColor;
}

class HighlightedTextEditingController extends TextEditingController {
  List<TextHighlightRange> _highlights = const <TextHighlightRange>[];

  List<TextHighlightRange> get highlights =>
      List<TextHighlightRange>.unmodifiable(_highlights);

  void setHighlights(List<TextHighlightRange> highlights) {
    if (_hasSameHighlights(highlights)) {
      return;
    }

    _highlights = List<TextHighlightRange>.from(highlights);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    if (text.isEmpty || _highlights.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final normalizedHighlights = _normalizedHighlights(text.length);
    if (normalizedHighlights.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final children = <TextSpan>[];
    var cursor = 0;

    for (final highlight in normalizedHighlights) {
      if (highlight.start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, highlight.start), style: style),
        );
      }
      children.add(
        TextSpan(
          text: text.substring(highlight.start, highlight.end),
          style: (style ?? const TextStyle()).copyWith(
            backgroundColor: highlight.backgroundColor,
          ),
        ),
      );
      cursor = highlight.end;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: style));
    }

    return TextSpan(style: style, children: children);
  }

  List<TextHighlightRange> _normalizedHighlights(int textLength) {
    final normalized = <TextHighlightRange>[];
    for (final highlight in _highlights) {
      final start = highlight.start.clamp(0, textLength);
      final end = highlight.end.clamp(0, textLength);
      if (start >= end) {
        continue;
      }
      normalized.add(
        TextHighlightRange(
          start: start,
          end: end,
          backgroundColor: highlight.backgroundColor,
        ),
      );
    }

    normalized.sort((left, right) => left.start.compareTo(right.start));
    return normalized;
  }

  bool _hasSameHighlights(List<TextHighlightRange> nextHighlights) {
    if (_highlights.length != nextHighlights.length) {
      return false;
    }

    for (var index = 0; index < _highlights.length; index++) {
      final current = _highlights[index];
      final next = nextHighlights[index];
      if (current.start != next.start ||
          current.end != next.end ||
          current.backgroundColor != next.backgroundColor) {
        return false;
      }
    }

    return true;
  }
}

class LiveTextInputEditor extends StatefulWidget {
  const LiveTextInputEditor({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.liveModeEnabled,
    required this.isStreaming,
    required this.chunkSizeWords,
    required this.onLiveModeChanged,
    required this.onChunkSizeChanged,
    required this.onClearPressed,
    this.onPlayPressed,
    this.onStopPressed,
    this.footer,
    this.title = 'Text',
    this.hintText = 'Type or paste English text here...',
    this.normalMinLines = 5,
    this.normalMaxLines = 7,
    this.liveMinLines = 10,
    this.liveMaxLines = 14,
  });

  final HighlightedTextEditingController controller;
  final ScrollController scrollController;
  final bool liveModeEnabled;
  final bool isStreaming;
  final int chunkSizeWords;
  final ValueChanged<bool> onLiveModeChanged;
  final ValueChanged<int> onChunkSizeChanged;
  final VoidCallback onClearPressed;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onStopPressed;
  final Widget? footer;
  final String title;
  final String hintText;
  final int normalMinLines;
  final int normalMaxLines;
  final int liveMinLines;
  final int liveMaxLines;

  @override
  State<LiveTextInputEditor> createState() => _LiveTextInputEditorState();
}

class _LiveTextInputEditorState extends State<LiveTextInputEditor> {
  late final TextEditingController _chunkSizeController;

  @override
  void initState() {
    super.initState();
    _chunkSizeController = TextEditingController(
      text: widget.chunkSizeWords.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant LiveTextInputEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextChunkSizeText = widget.chunkSizeWords.toString();
    if (_chunkSizeController.text != nextChunkSizeText) {
      _chunkSizeController.value = TextEditingValue(
        text: nextChunkSizeText,
        selection: TextSelection.collapsed(offset: nextChunkSizeText.length),
      );
    }
  }

  @override
  void dispose() {
    _chunkSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showClearButton = widget.controller.text.isNotEmpty;
    final isLiveModeEnabled = widget.liveModeEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            const Text('Live'),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: isLiveModeEnabled,
              onChanged: widget.onLiveModeChanged,
            ),
          ],
        ),
        if (isLiveModeEnabled) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 124,
                child: TextField(
                  controller: _chunkSizeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Chunk words',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsedValue = int.tryParse(value);
                    if (parsedValue != null && parsedValue > 0) {
                      widget.onChunkSizeChanged(parsedValue);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: widget.isStreaming
                        ? widget.onStopPressed
                        : widget.onPlayPressed,
                    icon: Icon(
                      widget.isStreaming ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(widget.isStreaming ? 'Stop' : 'Play'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 8),
        Scrollbar(
          controller: widget.scrollController,
          thumbVisibility: isLiveModeEnabled,
          child: TextField(
            controller: widget.controller,
            scrollController: widget.scrollController,
            maxLines: isLiveModeEnabled
                ? widget.liveMaxLines
                : widget.normalMaxLines,
            minLines: isLiveModeEnabled
                ? widget.liveMinLines
                : widget.normalMinLines,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
              suffixIcon: showClearButton
                  ? IconButton(
                      onPressed: widget.onClearPressed,
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear text',
                    )
                  : null,
            ),
          ),
        ),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}
