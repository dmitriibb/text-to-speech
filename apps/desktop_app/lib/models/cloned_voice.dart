import 'dart:convert';

class ClonedVoice {
  const ClonedVoice({
    required this.id,
    required this.name,
    required this.referenceAudioPath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String referenceAudioPath;
  final DateTime createdAt;

  factory ClonedVoice.fromJson(Map<String, Object?> json) {
    return ClonedVoice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      referenceAudioPath: json['referenceAudioPath'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'referenceAudioPath': referenceAudioPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<ClonedVoice> listFromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException('Cloned voice index must be a JSON array.');
    }

    return decoded
        .whereType<Map>()
        .map(
          (entry) => ClonedVoice.fromJson(
            Map<String, Object?>.from(entry as Map<Object?, Object?>),
          ),
        )
        .toList(growable: false);
  }

  static String listToJson(List<ClonedVoice> voices) {
    return const JsonEncoder.withIndent('  ').convert(
      voices.map((voice) => voice.toJson()).toList(growable: false),
    );
  }
}
