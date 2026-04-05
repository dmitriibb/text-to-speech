import '../models/voice_model.dart';

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
      'voicesFile': voice.voicesFile,
      'dataDir': voice.dataDir,
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
        'voices': payload['voicesFile'],
        'data_dir': payload['dataDir'],
        'pocket_lm_main': payload['pocketLmMain'],
        'pocket_encoder': payload['pocketEncoder'],
        'pocket_decoder': payload['pocketDecoder'],
        'pocket_text_conditioner': payload['pocketTextConditioner'],
        'pocket_vocab_json': payload['pocketVocabJson'],
        'pocket_token_scores_json': payload['pocketTokenScoresJson'],
        'pocket_default_reference_audio':
            payload['pocketDefaultReferenceAudio'],
      },
      'defaults': {
        'provider': payload['provider'],
        'num_threads': payload['numThreads'],
        'speed': 1.0,
        'speaker_id': payload['defaultSpeakerId'],
        'max_num_sentences': payload['maxNumSentences'],
      },
    });
  }
}
