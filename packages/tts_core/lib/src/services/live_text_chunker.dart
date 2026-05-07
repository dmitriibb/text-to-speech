import '../models/live_tts_chunk.dart';

class LiveTextChunker {
  static final RegExp _wordPattern = RegExp(r'\S+');
  static final RegExp _sentenceTrailerPattern = RegExp("[\"')\\]]+\$");

  static List<LiveTtsChunk> splitText(
    String text, {
    required int chunkSizeWords,
    int startOffset = 0,
  }) {
    final normalizedChunkSize = chunkSizeWords < 1 ? 1 : chunkSizeWords;
    final normalizedStartOffset = _normalizeStartOffset(text, startOffset);
    final words = _collectWords(text);
    if (words.isEmpty) {
      return const <LiveTtsChunk>[];
    }

    final firstWordIndex = _firstWordIndexAtOrAfter(
      words,
      normalizedStartOffset,
    );
    if (firstWordIndex == null) {
      return const <LiveTtsChunk>[];
    }

    final chunks = <LiveTtsChunk>[];
    var startWordIndex = firstWordIndex;

    while (startWordIndex < words.length) {
      var endWordIndex = startWordIndex + normalizedChunkSize - 1;
      if (endWordIndex >= words.length) {
        endWordIndex = words.length - 1;
      } else {
        while (endWordIndex < words.length - 1 &&
            !words[endWordIndex].endsSentence) {
          endWordIndex++;
        }
      }

      final chunkStartOffset = startWordIndex == firstWordIndex
          ? normalizedStartOffset
          : words[startWordIndex].startOffset;
      var chunkEndOffset = words[endWordIndex].endOffset;
      while (chunkEndOffset < text.length) {
        final codeUnit = text.codeUnitAt(chunkEndOffset);
        final isWhitespace =
            codeUnit == 0x20 ||
            codeUnit == 0x09 ||
            codeUnit == 0x0A ||
            codeUnit == 0x0D;
        if (!isWhitespace) {
          break;
        }
        chunkEndOffset++;
      }

      chunks.add(
        LiveTtsChunk(
          index: chunks.length,
          text: text.substring(chunkStartOffset, chunkEndOffset),
          startOffset: chunkStartOffset,
          endOffset: chunkEndOffset,
          wordCount: endWordIndex - startWordIndex + 1,
          status: LiveTtsChunkStatus.pending,
        ),
      );
      startWordIndex = endWordIndex + 1;
    }

    return chunks;
  }

  static List<_WordBoundary> _collectWords(String text) {
    final words = <_WordBoundary>[];

    for (final match in _wordPattern.allMatches(text)) {
      final wordText = match.group(0)!;
      words.add(
        _WordBoundary(
          startOffset: match.start,
          endOffset: match.end,
          endsSentence: _endsSentence(wordText),
        ),
      );
    }

    return words;
  }

  static bool _endsSentence(String wordText) {
    final sanitizedWord = wordText.replaceAll(_sentenceTrailerPattern, '');
    return sanitizedWord.endsWith('.') ||
        sanitizedWord.endsWith('!') ||
        sanitizedWord.endsWith('?');
  }

  static int _normalizeStartOffset(String text, int startOffset) {
    var normalizedOffset = startOffset;
    if (normalizedOffset < 0) {
      normalizedOffset = 0;
    } else if (normalizedOffset > text.length) {
      normalizedOffset = text.length;
    }
    while (normalizedOffset < text.length) {
      final codeUnit = text.codeUnitAt(normalizedOffset);
      final isWhitespace =
          codeUnit == 0x20 ||
          codeUnit == 0x09 ||
          codeUnit == 0x0A ||
          codeUnit == 0x0D;
      if (!isWhitespace) {
        break;
      }
      normalizedOffset++;
    }
    return normalizedOffset;
  }

  static int? _firstWordIndexAtOrAfter(
    List<_WordBoundary> words,
    int startOffset,
  ) {
    for (var index = 0; index < words.length; index++) {
      if (words[index].endOffset > startOffset) {
        return index;
      }
    }
    return null;
  }
}

class _WordBoundary {
  const _WordBoundary({
    required this.startOffset,
    required this.endOffset,
    required this.endsSentence,
  });

  final int startOffset;
  final int endOffset;
  final bool endsSentence;
}
