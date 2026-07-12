import '../services/synthesis_settings.dart';

enum DialogLineStatus { idle, queued, generating, ready, failed }

class DialogLineItem {
  const DialogLineItem({
    required this.id,
    required this.speakerName,
    required this.text,
    this.taskId,
    this.outputPath,
    this.status = DialogLineStatus.idle,
    this.errorMessage,
  });

  final String id;
  final String speakerName;
  final String text;
  final String? taskId;
  final String? outputPath;
  final DialogLineStatus status;
  final String? errorMessage;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasPlayableAudio =>
      outputPath != null && outputPath!.trim().isNotEmpty;

  DialogLineItem copyWith({
    String? id,
    String? speakerName,
    String? text,
    Object? taskId = _sentinel,
    Object? outputPath = _sentinel,
    DialogLineStatus? status,
    Object? errorMessage = _sentinel,
  }) {
    return DialogLineItem(
      id: id ?? this.id,
      speakerName: speakerName ?? this.speakerName,
      text: text ?? this.text,
      taskId: identical(taskId, _sentinel) ? this.taskId : taskId as String?,
      outputPath: identical(outputPath, _sentinel)
          ? this.outputPath
          : outputPath as String?,
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class DialogSpeakerSettings {
  const DialogSpeakerSettings({
    required this.speakerName,
    this.modelId,
    this.speakerId,
    this.generationLanguage,
    this.volume = dialogVolumeDefault,
  });

  final String speakerName;
  final String? modelId;
  final int? speakerId;
  final String? generationLanguage;
  final int volume;

  DialogSpeakerSettings copyWith({
    String? speakerName,
    Object? modelId = _sentinel,
    Object? speakerId = _sentinel,
    Object? generationLanguage = _sentinel,
    int? volume,
  }) {
    return DialogSpeakerSettings(
      speakerName: speakerName ?? this.speakerName,
      modelId: identical(modelId, _sentinel)
          ? this.modelId
          : modelId as String?,
      speakerId: identical(speakerId, _sentinel)
          ? this.speakerId
          : speakerId as int?,
      generationLanguage: identical(generationLanguage, _sentinel)
          ? this.generationLanguage
          : generationLanguage as String?,
      volume: volume == null ? this.volume : clampDialogVolume(volume),
    );
  }
}

class DialogModeParser {
  const DialogModeParser();

  List<DialogLineItem> parse(String rawText) {
    final lines = <DialogLineItem>[];
    var sourceLineNumber = 0;

    for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
      sourceLineNumber++;
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final separator = line.indexOf(':');
      if (separator <= 0 || separator == line.length - 1) {
        continue;
      }

      final speakerName = line.substring(0, separator).trim();
      final text = line.substring(separator + 1).trim();
      if (speakerName.isEmpty || text.isEmpty) {
        continue;
      }

      lines.add(
        DialogLineItem(
          id: 'dialog-line-$sourceLineNumber',
          speakerName: speakerName,
          text: text,
        ),
      );
    }

    return lines;
  }
}

const Object _sentinel = Object();
