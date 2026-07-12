import '../services/synthesis_settings.dart';
import 'voice_model.dart';

/// User choices that belong to one model rather than to one app screen.
class ModelSynthesisSettings {
  const ModelSynthesisSettings({
    this.volume = modelVolumeDefault,
    this.speed = speechSpeedDefault,
    this.speakerId = 0,
    this.generationLanguage = '',
    this.extensionValues = const <String, Object?>{},
  });

  factory ModelSynthesisSettings.defaultsFor(VoiceModel voice) {
    return ModelSynthesisSettings(
      speed: clampSpeechSpeed(voice.defaultSpeed),
      speakerId: _resolveSpeakerId(voice, voice.defaultSpeakerId),
      generationLanguage: voice.resolveGenerationLanguage(null),
    );
  }

  factory ModelSynthesisSettings.fromJson(
    Map<String, Object?> json,
    VoiceModel voice,
  ) {
    final defaults = ModelSynthesisSettings.defaultsFor(voice);
    final extensions = json['extensions'];
    return ModelSynthesisSettings(
      volume: clampModelVolume(
        (json['volume'] as num?)?.toDouble() ?? defaults.volume,
      ),
      speed: clampSpeechSpeed(
        (json['speed'] as num?)?.toDouble() ?? defaults.speed,
      ),
      speakerId: _resolveSpeakerId(
        voice,
        (json['speakerId'] as num?)?.toInt() ?? defaults.speakerId,
      ),
      generationLanguage: voice.resolveGenerationLanguage(
        json['generationLanguage'] as String?,
      ),
      extensionValues: extensions is Map
          ? Map<String, Object?>.from(extensions)
          : const <String, Object?>{},
    );
  }

  final double volume;
  final double speed;
  final int speakerId;
  final String generationLanguage;

  /// Model-family integrations can store additional JSON-safe values here.
  final Map<String, Object?> extensionValues;

  ModelSynthesisSettings copyWith({
    double? volume,
    double? speed,
    int? speakerId,
    String? generationLanguage,
    Map<String, Object?>? extensionValues,
  }) {
    return ModelSynthesisSettings(
      volume: clampModelVolume(volume ?? this.volume),
      speed: clampSpeechSpeed(speed ?? this.speed),
      speakerId: speakerId ?? this.speakerId,
      generationLanguage: generationLanguage ?? this.generationLanguage,
      extensionValues: extensionValues ?? this.extensionValues,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'volume': volume,
    'speed': speed,
    'speakerId': speakerId,
    'generationLanguage': generationLanguage,
    if (extensionValues.isNotEmpty) 'extensions': extensionValues,
  };

  static int _resolveSpeakerId(VoiceModel voice, int preferred) {
    if (voice.speakers.isEmpty) {
      return voice.defaultSpeakerId;
    }
    if (voice.speakers.any((speaker) => speaker.id == preferred)) {
      return preferred;
    }
    if (voice.speakers.any((speaker) => speaker.id == voice.defaultSpeakerId)) {
      return voice.defaultSpeakerId;
    }
    return voice.speakers.first.id;
  }
}
