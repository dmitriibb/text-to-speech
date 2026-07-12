import '../models/voice_model.dart';
import 'synthesis_settings.dart';

class VoiceModelTaskPayload {
  static Map<String, Object?> build({
    required String modelDir,
    required VoiceModel voice,
    String? providerOverride,
  }) {
    final provider = providerOverride ?? voice.provider;

    return {
      'cacheKey': '${voice.id}::$modelDir::$provider',
      'modelId': voice.id,
      'displayName': voice.displayName,
      'family': voice.family,
      'runtime': voice.runtime,
      'installDirName': voice.installDirName,
      'modelDir': modelDir,
      'modelFile': voice.modelFile,
      'tokensFile': voice.tokensFile,
      'lexiconFile': voice.lexiconFile,
      'extraLexiconFiles': voice.extraLexiconFiles,
      'ruleFsts': voice.ruleFsts,
      'ruleFars': voice.ruleFars,
      'voicesFile': voice.voicesFile,
      'dataDir': voice.dataDir,
      'dictDir': voice.dictDir,
      'provider': provider,
      'numThreads': voice.numThreads,
      'defaultSpeakerId': voice.defaultSpeakerId,
      'maxNumSentences': voice.maxNumSentences,
      'pocketLmMain': voice.pocketLmMain,
      'pocketEncoder': voice.pocketEncoder,
      'pocketDecoder': voice.pocketDecoder,
      'pocketTextConditioner': voice.pocketTextConditioner,
      'pocketVocabJson': voice.pocketVocabJson,
      'pocketTokenScoresJson': voice.pocketTokenScoresJson,
      'pocketDefaultReferenceAudio': voice.pocketDefaultReferenceAudio,
      'supertonicDurationPredictor': voice.supertonicDurationPredictor,
      'supertonicTextEncoder': voice.supertonicTextEncoder,
      'supertonicVectorEstimator': voice.supertonicVectorEstimator,
      'supertonicVocoder': voice.supertonicVocoder,
      'supertonicTtsJson': voice.supertonicTtsJson,
      'supertonicUnicodeIndexer': voice.supertonicUnicodeIndexer,
      'supertonicVoiceStyle': voice.supertonicVoiceStyle,
      'generationLanguage': voice.generationLanguage,
      'generationLanguages': voice.generationLanguages
          .map((language) => language.toJson())
          .toList(),
      'generationNumSteps': voice.generationNumSteps,
    };
  }

  static VoiceModel decode(Map<String, Object?> payload) {
    return VoiceModel.fromJson({
      'id': payload['modelId'],
      'display_name': payload['displayName'],
      'family': payload['family'],
      'runtime': payload['runtime'],
      'status': const {'approved_for_distribution': false},
      'source': const {'archive_url': ''},
      'install': {
        'archive_format': 'tar.bz2',
        'install_dir_name': payload['installDirName'],
      },
      'files': {
        'model': payload['modelFile'],
        'tokens': payload['tokensFile'],
        'lexicon': payload['lexiconFile'],
        'extra_lexicons': payload['extraLexiconFiles'] ?? const <String>[],
        'rule_fsts': payload['ruleFsts'] ?? const <String>[],
        'rule_fars': payload['ruleFars'] ?? const <String>[],
        'voices': payload['voicesFile'],
        'data_dir': payload['dataDir'],
        'dict_dir': payload['dictDir'],
        'pocket_lm_main': payload['pocketLmMain'],
        'pocket_encoder': payload['pocketEncoder'],
        'pocket_decoder': payload['pocketDecoder'],
        'pocket_text_conditioner': payload['pocketTextConditioner'],
        'pocket_vocab_json': payload['pocketVocabJson'],
        'pocket_token_scores_json': payload['pocketTokenScoresJson'],
        'pocket_default_reference_audio':
            payload['pocketDefaultReferenceAudio'],
        'supertonic_duration_predictor': payload['supertonicDurationPredictor'],
        'supertonic_text_encoder': payload['supertonicTextEncoder'],
        'supertonic_vector_estimator': payload['supertonicVectorEstimator'],
        'supertonic_vocoder': payload['supertonicVocoder'],
        'supertonic_tts_json': payload['supertonicTtsJson'],
        'supertonic_unicode_indexer': payload['supertonicUnicodeIndexer'],
        'supertonic_voice_style': payload['supertonicVoiceStyle'],
      },
      'defaults': {
        'provider': payload['provider'],
        'num_threads': payload['numThreads'],
        'speed': speechSpeedDefault,
        'speaker_id': payload['defaultSpeakerId'],
        'max_num_sentences': payload['maxNumSentences'],
        'language': payload['generationLanguage'],
        'num_steps': payload['generationNumSteps'],
      },
      'generation_languages': payload['generationLanguages'],
    });
  }
}
