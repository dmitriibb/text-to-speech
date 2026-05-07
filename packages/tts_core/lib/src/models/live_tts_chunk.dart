enum LiveTtsChunkStatus {
  pending,
  generating,
  ready,
  playing,
  completed,
  failed,
  cancelled,
}

class LiveTtsChunk {
  const LiveTtsChunk({
    required this.index,
    required this.text,
    required this.startOffset,
    required this.endOffset,
    required this.wordCount,
    required this.status,
    this.outputPath,
    this.errorMessage,
  });

  final int index;
  final String text;
  final int startOffset;
  final int endOffset;
  final int wordCount;
  final LiveTtsChunkStatus status;
  final String? outputPath;
  final String? errorMessage;

  LiveTtsChunk copyWith({
    int? index,
    String? text,
    int? startOffset,
    int? endOffset,
    int? wordCount,
    LiveTtsChunkStatus? status,
    Object? outputPath = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return LiveTtsChunk(
      index: index ?? this.index,
      text: text ?? this.text,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      wordCount: wordCount ?? this.wordCount,
      status: status ?? this.status,
      outputPath: identical(outputPath, _sentinel)
          ? this.outputPath
          : outputPath as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
