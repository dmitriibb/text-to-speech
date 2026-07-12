import 'dart:convert';

class ModelCatalog {
  const ModelCatalog({
    required this.catalogVersion,
    required this.defaultModelId,
    required this.models,
    this.updatedOn,
  });

  final int catalogVersion;
  final String defaultModelId;
  final List<VoiceModel> models;
  final String? updatedOn;

  factory ModelCatalog.fromRawJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Model catalog must be a JSON object.');
    }

    return ModelCatalog.fromJson(
      Map<String, Object?>.from(decoded as Map<Object?, Object?>),
    );
  }

  factory ModelCatalog.fromJson(Map<String, Object?> json) {
    final rawModels = json['models'];
    if (rawModels is! List) {
      throw const FormatException('Model catalog is missing the models list.');
    }

    return ModelCatalog(
      catalogVersion: (json['catalog_version'] as num?)?.toInt() ?? 0,
      defaultModelId: json['default_model_id'] as String? ?? '',
      updatedOn: json['updated_on'] as String?,
      models: rawModels
          .whereType<Map>()
          .map(
            (model) => VoiceModel.fromJson(
              Map<String, Object?>.from(model as Map<Object?, Object?>),
            ),
          )
          .toList(growable: false),
    );
  }
}

enum ModelStatus { notInstalled, downloading, ready, incomplete }

class InstalledModel {
  const InstalledModel({
    required this.voice,
    required this.status,
    this.modelDir,
  });

  final VoiceModel voice;
  final ModelStatus status;
  final String? modelDir;
}

class Speaker {
  const Speaker({required this.id, required this.name});

  final int id;
  final String name;

  factory Speaker.fromJson(Map<String, Object?> json) {
    return Speaker(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'name': name};
  }
}

class VoiceLanguage {
  const VoiceLanguage({required this.code, required this.name});

  final String code;
  final String name;

  factory VoiceLanguage.fromJson(Map<String, Object?> json) {
    return VoiceLanguage(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {'code': code, 'name': name};
  }
}

class VoiceModel {
  const VoiceModel({
    required this.id,
    required this.displayName,
    required this.family,
    required this.runtime,
    required this.approvedForDistribution,
    required this.archiveUrl,
    required this.archiveFormat,
    required this.installDirName,
    required this.modelFile,
    required this.tokensFile,
    required this.lexiconFile,
    required this.voicesFile,
    required this.dataDir,
    required this.provider,
    required this.numThreads,
    required this.defaultSpeed,
    required this.defaultSpeakerId,
    required this.maxNumSentences,
    this.sizeMb = 0,
    this.supportedLanguages = const <String>[],
    this.description = '',
    this.speakers = const <Speaker>[],
    this.voiceCloning = false,
    this.dictDir = '',
    this.extraLexiconFiles = const <String>[],
    this.ruleFsts = const <String>[],
    this.ruleFars = const <String>[],
    this.pocketLmMain = '',
    this.pocketEncoder = '',
    this.pocketDecoder = '',
    this.pocketTextConditioner = '',
    this.pocketVocabJson = '',
    this.pocketTokenScoresJson = '',
    this.pocketDefaultReferenceAudio = '',
    this.supertonicDurationPredictor = '',
    this.supertonicTextEncoder = '',
    this.supertonicVectorEstimator = '',
    this.supertonicVocoder = '',
    this.supertonicTtsJson = '',
    this.supertonicUnicodeIndexer = '',
    this.supertonicVoiceStyle = '',
    this.generationLanguage = '',
    this.generationLanguages = const <VoiceLanguage>[],
    this.generationNumSteps = 5,
  });

  final String id;
  final String displayName;
  final String family;
  final String runtime;
  final double sizeMb;
  final List<String> supportedLanguages;
  final String description;
  final bool approvedForDistribution;
  final String archiveUrl;
  final String archiveFormat;
  final String installDirName;
  final String modelFile;
  final String tokensFile;
  final String lexiconFile;
  final String voicesFile;
  final String dataDir;
  final String dictDir;
  final String provider;
  final int numThreads;
  final double defaultSpeed;
  final int defaultSpeakerId;
  final int maxNumSentences;
  final List<Speaker> speakers;
  final bool voiceCloning;
  final List<String> extraLexiconFiles;
  final List<String> ruleFsts;
  final List<String> ruleFars;
  final String pocketLmMain;
  final String pocketEncoder;
  final String pocketDecoder;
  final String pocketTextConditioner;
  final String pocketVocabJson;
  final String pocketTokenScoresJson;
  final String pocketDefaultReferenceAudio;
  final String supertonicDurationPredictor;
  final String supertonicTextEncoder;
  final String supertonicVectorEstimator;
  final String supertonicVocoder;
  final String supertonicTtsJson;
  final String supertonicUnicodeIndexer;
  final String supertonicVoiceStyle;
  final String generationLanguage;
  final List<VoiceLanguage> generationLanguages;
  final int generationNumSteps;

  bool get hasLanguageSelection => generationLanguages.length > 1;

  String get languageDisplayLabel {
    if (supportedLanguages.isNotEmpty) {
      return supportedLanguages.join(', ');
    }
    if (generationLanguages.isNotEmpty) {
      return generationLanguages.map((language) => language.name).join(', ');
    }
    return '';
  }

  String languageNameForCode(String code) {
    for (final language in generationLanguages) {
      if (language.code == code) {
        return language.name;
      }
    }
    return code;
  }

  String resolveGenerationLanguage(String? preferredLanguage) {
    final normalizedPreferred = preferredLanguage?.trim() ?? '';
    if (normalizedPreferred.isNotEmpty &&
        generationLanguages.any(
          (language) => language.code == normalizedPreferred,
        )) {
      return normalizedPreferred;
    }

    if (generationLanguage.isNotEmpty &&
        (generationLanguages.isEmpty ||
            generationLanguages.any(
              (language) => language.code == generationLanguage,
            ))) {
      return generationLanguage;
    }

    if (generationLanguages.isNotEmpty) {
      return generationLanguages.first.code;
    }

    return generationLanguage;
  }

  List<String> get allLexiconFiles {
    return [if (lexiconFile.isNotEmpty) lexiconFile, ...extraLexiconFiles];
  }

  factory VoiceModel.fromJson(Map<String, Object?> json) {
    final status = _asObjectMap(json['status']);
    final source = _asObjectMap(json['source']);
    final install = _asObjectMap(json['install']);
    final files = _asObjectMap(json['files']);
    final defaults = _asObjectMap(json['defaults']);
    final rawSpeakers = json['speakers'];
    final rawGenerationLanguages = json['generation_languages'];

    return VoiceModel(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      family: json['family'] as String? ?? '',
      runtime: json['runtime'] as String? ?? '',
      sizeMb: (json['size_mb'] as num?)?.toDouble() ?? 0,
      supportedLanguages: _asStringList(json['supported_languages']),
      description: json['description'] as String? ?? '',
      approvedForDistribution:
          status['approved_for_distribution'] as bool? ?? false,
      archiveUrl: source['archive_url'] as String? ?? '',
      archiveFormat: install['archive_format'] as String? ?? '',
      installDirName: install['install_dir_name'] as String? ?? '',
      modelFile: files['model'] as String? ?? '',
      tokensFile: files['tokens'] as String? ?? '',
      lexiconFile: files['lexicon'] as String? ?? '',
      voicesFile: files['voices'] as String? ?? '',
      dataDir: files['data_dir'] as String? ?? '',
      dictDir: files['dict_dir'] as String? ?? '',
      provider: defaults['provider'] as String? ?? 'cpu',
      numThreads: (defaults['num_threads'] as num?)?.toInt() ?? 1,
      defaultSpeed: (defaults['speed'] as num?)?.toDouble() ?? 1.0,
      defaultSpeakerId: (defaults['speaker_id'] as num?)?.toInt() ?? 0,
      maxNumSentences: (defaults['max_num_sentences'] as num?)?.toInt() ?? 1,
      speakers: rawSpeakers is List
          ? rawSpeakers
                .whereType<Map>()
                .map(
                  (speaker) => Speaker.fromJson(
                    Map<String, Object?>.from(speaker as Map<Object?, Object?>),
                  ),
                )
                .toList(growable: false)
          : const <Speaker>[],
      voiceCloning: json['voice_cloning'] as bool? ?? false,
      extraLexiconFiles: _asStringList(files['extra_lexicons']),
      ruleFsts: _asStringList(files['rule_fsts']),
      ruleFars: _asStringList(files['rule_fars']),
      pocketLmMain: files['pocket_lm_main'] as String? ?? '',
      pocketEncoder: files['pocket_encoder'] as String? ?? '',
      pocketDecoder: files['pocket_decoder'] as String? ?? '',
      pocketTextConditioner: files['pocket_text_conditioner'] as String? ?? '',
      pocketVocabJson: files['pocket_vocab_json'] as String? ?? '',
      pocketTokenScoresJson: files['pocket_token_scores_json'] as String? ?? '',
      pocketDefaultReferenceAudio:
          files['pocket_default_reference_audio'] as String? ?? '',
      supertonicDurationPredictor:
          files['supertonic_duration_predictor'] as String? ?? '',
      supertonicTextEncoder: files['supertonic_text_encoder'] as String? ?? '',
      supertonicVectorEstimator:
          files['supertonic_vector_estimator'] as String? ?? '',
      supertonicVocoder: files['supertonic_vocoder'] as String? ?? '',
      supertonicTtsJson: files['supertonic_tts_json'] as String? ?? '',
      supertonicUnicodeIndexer:
          files['supertonic_unicode_indexer'] as String? ?? '',
      supertonicVoiceStyle: files['supertonic_voice_style'] as String? ?? '',
      generationLanguage: defaults['language'] as String? ?? '',
      generationLanguages: rawGenerationLanguages is List
          ? rawGenerationLanguages
                .whereType<Map>()
                .map(
                  (language) => VoiceLanguage.fromJson(
                    Map<String, Object?>.from(
                      language as Map<Object?, Object?>,
                    ),
                  ),
                )
                .where((language) => language.code.isNotEmpty)
                .toList(growable: false)
          : const <VoiceLanguage>[],
      generationNumSteps: (defaults['num_steps'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'family': family,
      'runtime': runtime,
      'size_mb': sizeMb,
      'supported_languages': supportedLanguages,
      'description': description,
      'status': {'approved_for_distribution': approvedForDistribution},
      'source': {'archive_url': archiveUrl},
      'install': {
        'archive_format': archiveFormat,
        'install_dir_name': installDirName,
      },
      'files': {
        'model': modelFile,
        'tokens': tokensFile,
        'lexicon': lexiconFile,
        'extra_lexicons': extraLexiconFiles,
        'rule_fsts': ruleFsts,
        'rule_fars': ruleFars,
        'voices': voicesFile,
        'data_dir': dataDir,
        'dict_dir': dictDir,
        'pocket_lm_main': pocketLmMain,
        'pocket_encoder': pocketEncoder,
        'pocket_decoder': pocketDecoder,
        'pocket_text_conditioner': pocketTextConditioner,
        'pocket_vocab_json': pocketVocabJson,
        'pocket_token_scores_json': pocketTokenScoresJson,
        'pocket_default_reference_audio': pocketDefaultReferenceAudio,
        'supertonic_duration_predictor': supertonicDurationPredictor,
        'supertonic_text_encoder': supertonicTextEncoder,
        'supertonic_vector_estimator': supertonicVectorEstimator,
        'supertonic_vocoder': supertonicVocoder,
        'supertonic_tts_json': supertonicTtsJson,
        'supertonic_unicode_indexer': supertonicUnicodeIndexer,
        'supertonic_voice_style': supertonicVoiceStyle,
      },
      'defaults': {
        'provider': provider,
        'num_threads': numThreads,
        'speed': defaultSpeed,
        'speaker_id': defaultSpeakerId,
        'max_num_sentences': maxNumSentences,
        'language': generationLanguage,
        'num_steps': generationNumSteps,
      },
      'voice_cloning': voiceCloning,
      'generation_languages': generationLanguages
          .map((language) => language.toJson())
          .toList(),
      'speakers': speakers.map((speaker) => speaker.toJson()).toList(),
    };
  }

  static Map<String, Object?> _asObjectMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value as Map<Object?, Object?>);
    }
    return <String, Object?>{};
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}
