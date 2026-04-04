import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/voice_model.dart';

class ModelFileValidator {
  static List<String> requiredEntries(VoiceModel model) {
    return [
      model.modelFile,
      model.tokensFile,
      if (model.lexiconFile.isNotEmpty) model.lexiconFile,
      if (model.voicesFile.isNotEmpty) model.voicesFile,
      if (model.dataDir.isNotEmpty) model.dataDir,
    ];
  }

  static Future<List<String>> missingEntries(String dir, VoiceModel model) async {
    final missing = <String>[];

    final modelPath = p.join(dir, model.modelFile);
    if (!await File(modelPath).exists()) {
      missing.add(model.modelFile);
    }

    final tokensPath = p.join(dir, model.tokensFile);
    if (!await File(tokensPath).exists()) {
      missing.add(model.tokensFile);
    }

    if (model.lexiconFile.isNotEmpty) {
      final lexiconPath = p.join(dir, model.lexiconFile);
      if (!await File(lexiconPath).exists()) {
        missing.add(model.lexiconFile);
      }
    }

    if (model.voicesFile.isNotEmpty) {
      final voicesPath = p.join(dir, model.voicesFile);
      if (!await File(voicesPath).exists()) {
        missing.add(model.voicesFile);
      }
    }

    if (model.dataDir.isNotEmpty) {
      final dataDirPath = p.join(dir, model.dataDir);
      if (!await Directory(dataDirPath).exists()) {
        missing.add(model.dataDir);
      }
    }

    return missing;
  }

  static Future<ModelStatus> getStatus(String dir, VoiceModel model) async {
    final missing = await missingEntries(dir, model);
    return missing.isEmpty ? ModelStatus.ready : ModelStatus.incomplete;
  }
}