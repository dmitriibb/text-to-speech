import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/voice_model.dart';
import 'synthesis_settings.dart';

class SynthesisResult {
  final Float32List samples;
  final int sampleRate;

  const SynthesisResult({required this.samples, required this.sampleRate});
}

class TtsService {
  static bool _bindingsInitialized = false;
  static const Map<String, Object> _pocketDefaultExtra = {
    'max_reference_audio_len': 12,
  };

  sherpa.OfflineTts? _tts;
  VoiceModel? _loadedModel;
  String? _loadedModelDir;

  bool get isReady => _tts != null;
  int get sampleRate => _tts?.sampleRate ?? 0;
  int get numSpeakers => _tts?.numSpeakers ?? 0;

  void initBindings() {
    _ensureBindingsInitialized();
  }

  void loadModel(String modelDir, VoiceModel model) {
    _tts?.free();
    _tts = null;
    _loadedModel = model;
    _loadedModelDir = modelDir;

    final modelPath = p.join(modelDir, model.modelFile);
    final tokensPath = model.tokensFile.isNotEmpty
        ? p.join(modelDir, model.tokensFile)
        : '';
    final lexiconPath = model.allLexiconFiles
        .map((entry) => p.join(modelDir, entry))
        .join(',');
    final ruleFstsPath = model.ruleFsts
        .map((entry) => p.join(modelDir, entry))
        .join(',');
    final ruleFarsPath = model.ruleFars
        .map((entry) => p.join(modelDir, entry))
        .join(',');
    final dataDirPath = model.dataDir.isNotEmpty
        ? p.join(modelDir, model.dataDir)
        : '';
    final dictDirPath = model.dictDir.isNotEmpty
        ? p.join(modelDir, model.dictDir)
        : '';

    final sherpa.OfflineTtsModelConfig modelConfig;

    switch (model.family) {
      case 'kokoro':
        final voicesPath = model.voicesFile.isNotEmpty
            ? p.join(modelDir, model.voicesFile)
            : '';
        final kokoroConfig = sherpa.OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
          dictDir: dictDirPath,
          lexicon: lexiconPath,
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          kokoro: kokoroConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
        break;
      case 'kitten':
        final voicesPath = model.voicesFile.isNotEmpty
            ? p.join(modelDir, model.voicesFile)
            : '';
        final kittenConfig = sherpa.OfflineTtsKittenModelConfig(
          model: modelPath,
          voices: voicesPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          kitten: kittenConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
        break;
      case 'pocket':
        final pocketConfig = sherpa.OfflineTtsPocketModelConfig(
          lmFlow: modelPath,
          lmMain: p.join(modelDir, model.pocketLmMain),
          encoder: p.join(modelDir, model.pocketEncoder),
          decoder: p.join(modelDir, model.pocketDecoder),
          textConditioner: p.join(modelDir, model.pocketTextConditioner),
          vocabJson: p.join(modelDir, model.pocketVocabJson),
          tokenScoresJson: p.join(modelDir, model.pocketTokenScoresJson),
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          pocket: pocketConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
        break;
      default:
        final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
          model: modelPath,
          lexicon: lexiconPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
          dictDir: dictDirPath,
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          vits: vitsConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
    }

    final ttsConfig = sherpa.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: model.maxNumSentences,
      ruleFsts: ruleFstsPath,
      ruleFars: ruleFarsPath,
    );

    try {
      _tts = sherpa.OfflineTts(ttsConfig);
    } catch (_) {
      if (model.provider == 'cpu') {
        rethrow;
      }

      loadModel(modelDir, _withProvider(model, 'cpu'));
    }
  }

  SynthesisResult synthesize(
    String text, {
    double speed = speechSpeedDefault,
    int speakerId = 0,
  }) {
    if (_tts == null) {
      throw StateError('TTS engine not initialized. Call loadModel first.');
    }

    final model = _loadedModel;
    if (model != null && model.family == 'pocket') {
      return _synthesizePocketWithDefaultReference(text, speed: speed);
    }

    final normalizedSpeed = clampSpeechSpeed(speed);
    final audio = _tts!.generate(
      text: text,
      sid: speakerId,
      speed: normalizedSpeed,
    );
    return _toSynthesisResult(audio, context: 'speech synthesis');
  }

  /// Synthesize speech using a reference audio clip for zero-shot voice cloning.
  SynthesisResult synthesizeWithReference(
    String text, {
    required Float32List referenceAudio,
    required int referenceSampleRate,
    double speed = speechSpeedDefault,
    int numSteps = 2,
  }) {
    if (_tts == null) {
      throw StateError('TTS engine not initialized. Call loadModel first.');
    }

    final normalizedSpeed = clampSpeechSpeed(speed);
    final config = sherpa.OfflineTtsGenerationConfig(
      speed: normalizedSpeed,
      referenceAudio: referenceAudio,
      referenceSampleRate: referenceSampleRate,
      numSteps: numSteps,
      extra: _loadedModel?.family == 'pocket' ? _pocketDefaultExtra : const {},
    );

    final audio = _tts!.generateWithConfig(text: text, config: config);
    return _toSynthesisResult(audio, context: 'reference speech synthesis');
  }

  bool saveWav(SynthesisResult result, String outputPath) {
    return sherpa.writeWave(
      filename: outputPath,
      samples: result.samples,
      sampleRate: result.sampleRate,
    );
  }

  /// Reads a WAV file and returns its samples and sample rate.
  static SynthesisResult readWavFile(String path) {
    _ensureBindingsInitialized();
    final wave = sherpa.readWave(path);
    return SynthesisResult(samples: wave.samples, sampleRate: wave.sampleRate);
  }

  void dispose() {
    _tts?.free();
    _tts = null;
    _loadedModel = null;
    _loadedModelDir = null;
  }

  SynthesisResult _synthesizePocketWithDefaultReference(
    String text, {
    required double speed,
  }) {
    final referencePath = _resolvePocketDefaultReferencePath();
    final wave = readWavFile(referencePath);
    if (wave.samples.isEmpty || wave.sampleRate == 0) {
      throw StateError(
        'Pocket TTS default reference audio is empty: $referencePath',
      );
    }

    final normalizedSpeed = clampSpeechSpeed(speed);
    final config = sherpa.OfflineTtsGenerationConfig(
      speed: normalizedSpeed,
      referenceAudio: wave.samples,
      referenceSampleRate: wave.sampleRate,
      extra: _pocketDefaultExtra,
    );

    final audio = _tts!.generateWithConfig(text: text, config: config);
    return _toSynthesisResult(audio, context: 'Pocket TTS synthesis');
  }

  String _resolvePocketDefaultReferencePath() {
    final model = _loadedModel;
    final modelDir = _loadedModelDir;

    if (model == null || model.family != 'pocket' || modelDir == null) {
      throw StateError('Pocket TTS model is not loaded.');
    }

    if (model.pocketDefaultReferenceAudio.isEmpty) {
      throw StateError(
        'Pocket TTS model does not define a bundled default reference audio.',
      );
    }

    final referencePath = p.join(modelDir, model.pocketDefaultReferenceAudio);
    if (!File(referencePath).existsSync()) {
      throw StateError(
        'Pocket TTS default reference audio is missing: $referencePath',
      );
    }

    return referencePath;
  }

  VoiceModel _withProvider(VoiceModel model, String provider) {
    final json = model.toJson();
    final defaults = Map<String, Object?>.from(json['defaults']! as Map);
    defaults['provider'] = provider;
    json['defaults'] = defaults;
    return VoiceModel.fromJson(json);
  }

  SynthesisResult _toSynthesisResult(
    sherpa.GeneratedAudio audio, {
    required String context,
  }) {
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw StateError('No audio was generated during $context.');
    }

    return SynthesisResult(
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
  }

  static void _ensureBindingsInitialized() {
    if (_bindingsInitialized) {
      return;
    }

    sherpa.initBindings();
    _bindingsInitialized = true;
  }
}
