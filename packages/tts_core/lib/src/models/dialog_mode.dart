import '../services/synthesis_settings.dart';
import 'model_synthesis_settings.dart';
import 'synthesis_target.dart';

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
    this.revision = 0,
    this.included = true,
    this.textOverride,
    this.pauseAfterMs,
    this.clipFingerprint,
    this.clipHash,
  });

  final String id;
  final String speakerName;
  final String text;
  final String? taskId;
  final String? outputPath;
  final DialogLineStatus status;
  final String? errorMessage;
  final int revision;
  final bool included;
  final String? textOverride;
  final int? pauseAfterMs;
  final String? clipFingerprint;
  final String? clipHash;
  String get effectiveText => textOverride ?? text;

  bool get hasText => effectiveText.trim().isNotEmpty;
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
    int? revision,
    bool? included,
    Object? textOverride = _sentinel,
    Object? pauseAfterMs = _sentinel,
    Object? clipFingerprint = _sentinel,
    Object? clipHash = _sentinel,
  }) {
    return DialogLineItem(
      id: id ?? this.id,
      speakerName: speakerName ?? this.speakerName,
      text: text ?? this.text,
      revision: revision ?? this.revision,
      included: included ?? this.included,
      textOverride: identical(textOverride, _sentinel)
          ? this.textOverride
          : textOverride as String?,
      pauseAfterMs: identical(pauseAfterMs, _sentinel)
          ? this.pauseAfterMs
          : pauseAfterMs as int?,
      clipFingerprint: identical(clipFingerprint, _sentinel)
          ? this.clipFingerprint
          : clipFingerprint as String?,
      clipHash: identical(clipHash, _sentinel)
          ? this.clipHash
          : clipHash as String?,
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
    String? actorId,
    String? modelId,
    int? speakerId,
    String? generationLanguage,
    int volume = dialogVolumeDefault,
    this.target,
    this.modelSettingsByTarget = const {},
    this.referencesByTarget = const {},
    this.revision = 0,
  }) : _actorId = actorId,
       _modelId = modelId,
       _speakerId = speakerId,
       _generationLanguage = generationLanguage,
       _volume = volume;

  final String speakerName;
  final String? _actorId;
  final String? _modelId;
  final int? _speakerId;
  final String? _generationLanguage;
  final int _volume;
  final SynthesisTarget? target;
  final int revision;
  final Map<String, ModelSynthesisSettings> modelSettingsByTarget;
  final Map<String, DialogReferenceAsset> referencesByTarget;

  String get actorId => _actorId ?? speakerName;
  String? get modelId => target?.modelId ?? _modelId;
  SynthesisTarget? get effectiveTarget =>
      target ?? (modelId == null ? null : SynthesisTarget.local(modelId!));
  ModelSynthesisSettings get synthesisSettings =>
      modelSettingsByTarget[effectiveTarget?.settingsKey] ??
      ModelSynthesisSettings(
        speakerId: _speakerId ?? 0,
        generationLanguage: _generationLanguage ?? '',
        volume: clampModelVolume(dialogVolumeToGain(_volume)),
      );
  DialogReferenceAsset? get reference =>
      referencesByTarget[effectiveTarget?.settingsKey];
  int get speakerId => synthesisSettings.speakerId;
  String get generationLanguage => synthesisSettings.generationLanguage;
  double get speed => synthesisSettings.speed;
  double get volumeGain => synthesisSettings.volume;

  /// Legacy callers can display the old scale, but synthesis uses gain once.
  int get volume => modelSettingsByTarget[effectiveTarget?.settingsKey] == null
      ? clampDialogVolume(_volume)
      : clampDialogVolume((volumeGain * dialogVolumeDefault).round());

  DialogSpeakerSettings selectTarget(
    SynthesisTarget next,
    ModelSynthesisSettings defaults,
  ) {
    final history = _settingsHistory();
    history.putIfAbsent(next.settingsKey, defaults.snapshot);
    return DialogSpeakerSettings(
      speakerName: speakerName,
      actorId: actorId,
      target: next,
      revision: revision + 1,
      modelSettingsByTarget: Map.unmodifiable(history),
      referencesByTarget: Map.unmodifiable(referencesByTarget),
    );
  }

  DialogSpeakerSettings withSynthesisSettings(ModelSynthesisSettings settings) {
    final selected = effectiveTarget;
    if (selected == null) throw StateError('Select an actor target first.');
    return DialogSpeakerSettings(
      speakerName: speakerName,
      actorId: actorId,
      target: selected,
      revision: revision + 1,
      modelSettingsByTarget: Map.unmodifiable({
        ..._settingsHistory(),
        selected.settingsKey: settings.snapshot(),
      }),
      referencesByTarget: Map.unmodifiable(referencesByTarget),
    );
  }

  DialogSpeakerSettings withReference(DialogReferenceAsset? reference) {
    final selected = effectiveTarget;
    if (selected == null) throw StateError('Select an actor target first.');
    final references = {...referencesByTarget};
    if (reference == null) {
      references.remove(selected.settingsKey);
    } else {
      references[selected.settingsKey] = reference;
    }
    return DialogSpeakerSettings(
      speakerName: speakerName,
      actorId: actorId,
      target: selected,
      revision: revision + 1,
      modelSettingsByTarget: Map.unmodifiable(_settingsHistory()),
      referencesByTarget: Map.unmodifiable(references),
    );
  }

  Map<String, ModelSynthesisSettings> _settingsHistory() => {
    for (final entry in modelSettingsByTarget.entries)
      entry.key: entry.value.snapshot(),
    if (effectiveTarget != null)
      effectiveTarget!.settingsKey: synthesisSettings.snapshot(),
  };

  Map<String, Object?> toJson() => {
    'version': 2,
    'actorId': actorId,
    'speakerName': speakerName,
    'revision': revision,
    'target': effectiveTarget?.toJson(),
    'modelSettings': _settingsHistory().map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'references': referencesByTarget.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
  };

  factory DialogSpeakerSettings.fromJson(Map<String, Object?> json) {
    final version = json['version'] ?? 1;
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported actor profile version.');
    }
    final name = json['speakerName'] as String;
    if (version == 1) {
      final legacy = DialogSpeakerSettings(
        speakerName: name,
        actorId: json['actorId'] as String?,
        modelId: json['modelId'] as String?,
        speakerId: (json['speakerId'] as num?)?.toInt(),
        generationLanguage: json['generationLanguage'] as String?,
        volume: (json['volume'] as num?)?.toInt() ?? dialogVolumeDefault,
      );
      final selected = legacy.effectiveTarget;
      return selected == null
          ? legacy
          : legacy.withSynthesisSettings(
              legacy.synthesisSettings.copyWith(
                speed: (json['speed'] as num?)?.toDouble(),
              ),
            );
    }
    final rawTarget = json['target'];
    final settings = <String, ModelSynthesisSettings>{};
    final rawSettings = json['modelSettings'] as Map? ?? {};
    for (final entry in rawSettings.entries) {
      final value = Map<String, Object?>.from(entry.value as Map);
      settings[entry.key as String] = ModelSynthesisSettings(
        volume: (value['volume'] as num?)?.toDouble() ?? modelVolumeDefault,
        speed: (value['speed'] as num?)?.toDouble() ?? speechSpeedDefault,
        speakerId: (value['speakerId'] as num?)?.toInt() ?? 0,
        generationLanguage: value['generationLanguage'] as String? ?? '',
        extensionValues: Map<String, Object?>.from(
          value['extensions'] as Map? ?? {},
        ),
      ).snapshot();
    }
    final rawReferences = json['references'] as Map? ?? {};
    return DialogSpeakerSettings(
      speakerName: name,
      actorId: json['actorId'] as String,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      target: rawTarget == null
          ? null
          : SynthesisTarget.fromJson(
              Map<String, Object?>.from(rawTarget as Map),
            ),
      modelSettingsByTarget: Map.unmodifiable(settings),
      referencesByTarget: Map.unmodifiable(
        rawReferences.map(
          (key, value) => MapEntry(
            key as String,
            DialogReferenceAsset.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          ),
        ),
      ),
    );
  }

  DialogSpeakerSettings copyWith({
    String? speakerName,
    Object? modelId = _sentinel,
    Object? speakerId = _sentinel,
    Object? generationLanguage = _sentinel,
    int? volume,
  }) {
    var next = DialogSpeakerSettings(
      speakerName: speakerName ?? this.speakerName,
      actorId: actorId,
      modelId: identical(modelId, _sentinel)
          ? this.modelId
          : modelId as String?,
      target: identical(modelId, _sentinel) ? effectiveTarget : null,
      speakerId: identical(speakerId, _sentinel)
          ? this.speakerId
          : speakerId as int?,
      generationLanguage: identical(generationLanguage, _sentinel)
          ? this.generationLanguage
          : generationLanguage as String?,
      volume: volume ?? this.volume,
      revision: revision,
      modelSettingsByTarget: Map.unmodifiable(_settingsHistory()),
      referencesByTarget: Map.unmodifiable(referencesByTarget),
    );
    if (next.effectiveTarget != null) {
      next = next.withSynthesisSettings(
        next.synthesisSettings.copyWith(
          speakerId: identical(speakerId, _sentinel) ? null : speakerId as int?,
          generationLanguage: identical(generationLanguage, _sentinel)
              ? null
              : generationLanguage as String?,
          volume: volume == null ? null : dialogVolumeToGain(volume),
        ),
      );
    }
    return next;
  }
}

class DialogImportIssue {
  const DialogImportIssue({
    required this.sourceLineNumber,
    required this.sourceText,
    required this.message,
  });

  final int sourceLineNumber;
  final String sourceText;
  final String message;
}

class DialogParseResult {
  DialogParseResult({
    required List<DialogLineItem> lines,
    required List<DialogImportIssue> issues,
  }) : lines = List.unmodifiable(lines),
       issues = List.unmodifiable(issues);

  final List<DialogLineItem> lines;
  final List<DialogImportIssue> issues;
}

class DialogModeParser {
  const DialogModeParser();

  List<DialogLineItem> parse(String rawText) =>
      parseWithDiagnostics(rawText).lines;

  DialogParseResult parseWithDiagnostics(String rawText) {
    final lines = <DialogLineItem>[];
    final issues = <DialogImportIssue>[];
    var sourceLineNumber = 0;

    for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
      sourceLineNumber++;
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final separator = line.indexOf(':');
      final speakerName = separator < 0
          ? ''
          : line.substring(0, separator).trim();
      final text = separator < 0 ? '' : line.substring(separator + 1).trim();
      if (speakerName.isEmpty || text.isEmpty) {
        issues.add(
          DialogImportIssue(
            sourceLineNumber: sourceLineNumber,
            sourceText: rawLine,
            message: separator < 0
                ? 'Expected Speaker: text.'
                : speakerName.isEmpty
                ? 'Speaker name is missing.'
                : 'Spoken text is missing.',
          ),
        );
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

    return DialogParseResult(lines: lines, issues: issues);
  }
}

const Object _sentinel = Object();
