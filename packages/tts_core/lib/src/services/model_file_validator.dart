import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/voice_model.dart';

class ModelFileValidator {
  static List<String> requiredFileEntries(VoiceModel model) {
    return [
      model.modelFile,
      model.tokensFile,
      model.lexiconFile,
      model.voicesFile,
      model.pocketLmMain,
      model.pocketEncoder,
      model.pocketDecoder,
      model.pocketTextConditioner,
      model.pocketVocabJson,
      model.pocketTokenScoresJson,
    ].where((entry) => entry.isNotEmpty).toList(growable: false);
  }

  static List<String> requiredDirectoryEntries(VoiceModel model) {
    return [
      model.dataDir,
    ].where((entry) => entry.isNotEmpty).toList(growable: false);
  }

  static List<String> requiredEntries(VoiceModel model) {
    return [...requiredFileEntries(model), ...requiredDirectoryEntries(model)];
  }

  static Future<List<String>> missingEntries(
    String dir,
    VoiceModel model,
  ) async {
    final missing = <String>[];

    for (final fileEntry in requiredFileEntries(model)) {
      final filePath = p.join(dir, fileEntry);
      if (!await File(filePath).exists()) {
        missing.add(fileEntry);
      }
    }

    for (final directoryEntry in requiredDirectoryEntries(model)) {
      final directoryPath = p.join(dir, directoryEntry);
      if (!await Directory(directoryPath).exists()) {
        missing.add(directoryEntry);
      }
    }

    return missing;
  }

  static Future<ModelStatus> getStatus(String dir, VoiceModel model) async {
    final missing = await missingEntries(dir, model);
    return missing.isEmpty ? ModelStatus.ready : ModelStatus.incomplete;
  }

  /// Returns the first valid model directory at [dir] or within its first two
  /// nested directory levels. This repairs archives that unpack with an
  /// extra wrapper directory.
  static Future<String?> findValidatedModelDir(
    String dir,
    VoiceModel model,
  ) async {
    if (await Directory(dir).exists() &&
        await getStatus(dir, model) == ModelStatus.ready) {
      return dir;
    }

    final root = Directory(dir);
    if (!await root.exists()) {
      return null;
    }

    final levelOneDirectories = await root
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    for (final child in levelOneDirectories) {
      if (await getStatus(child.path, model) == ModelStatus.ready) {
        return child.path;
      }
    }

    for (final child in levelOneDirectories) {
      final levelTwoDirectories = await child
          .list(followLinks: false)
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();

      for (final grandchild in levelTwoDirectories) {
        if (await getStatus(grandchild.path, model) == ModelStatus.ready) {
          return grandchild.path;
        }
      }
    }

    return null;
  }

  /// Normalizes a nested extracted model directory back to [expectedDir].
  static Future<String> normalizeExtractedModelDir(
    String expectedDir,
    VoiceModel model,
  ) async {
    final resolvedDir = await findValidatedModelDir(expectedDir, model);
    if (resolvedDir == null || resolvedDir == expectedDir) {
      return expectedDir;
    }

    final parentDir = p.dirname(expectedDir);
    final tempResolvedDir = p.join(
      parentDir,
      '${p.basename(expectedDir)}.__resolved__',
    );

    final tempDirectory = Directory(tempResolvedDir);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }

    await Directory(resolvedDir).rename(tempResolvedDir);

    final expectedDirectory = Directory(expectedDir);
    if (await expectedDirectory.exists()) {
      await expectedDirectory.delete(recursive: true);
    }

    await tempDirectory.rename(expectedDir);
    return expectedDir;
  }

  static Future<List<String>> listTopLevelEntries(
    String dir, {
    int maxEntries = 20,
  }) async {
    final directory = Directory(dir);
    if (!await directory.exists()) {
      return const [];
    }

    final entries = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        entries.add('$name/');
      } else {
        entries.add(name);
      }
    }

    entries.sort();
    if (entries.length > maxEntries) {
      return [
        ...entries.take(maxEntries),
        '... (${entries.length - maxEntries} more)',
      ];
    }
    return entries;
  }
}
