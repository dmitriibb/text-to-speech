import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/synthesis_target.dart';

/// Apps inject a project directory in their own writable storage. Actor JSON
/// contains relative paths/hashes; reference bytes stay in this directory.
class DialogReferenceStore {
  DialogReferenceStore({
    required this.projectDirectory,
    this.maxBytes = 64 * 1024 * 1024,
  }) {
    if (maxBytes < 12) {
      throw ArgumentError('Reference size limit is too small.');
    }
  }

  final Directory projectDirectory;
  final int maxBytes;

  Future<DialogReferenceAsset> importWav(
    File source, {
    required String transcript,
  }) async {
    final references = Directory(p.join(projectDirectory.path, 'references'));
    await references.create(recursive: true);
    await _assertWithinProject(references.path);
    final staging = await references.createTemp('.import-');
    try {
      final temporary = File(p.join(staging.path, 'reference.wav'));
      final output = await temporary.open(mode: FileMode.write);
      var size = 0;
      try {
        await for (final chunk in source.openRead()) {
          size += chunk.length;
          if (size > maxBytes) {
            throw StateError('Reference exceeds $maxBytes bytes.');
          }
          await output.writeFrom(chunk);
        }
      } finally {
        await output.close();
      }
      final handle = await temporary.open();
      try {
        _requireWav(await handle.read(12));
      } finally {
        await handle.close();
      }
      // Hash the owned copy, avoiding a changed-source hash/copy race.
      final hash = (await sha256.bind(temporary.openRead()).first).toString();
      final asset = DialogReferenceAsset(
        relativePath: 'references/$hash.wav',
        sha256: hash,
        transcript: transcript,
      );
      final destination = File(p.join(references.path, '$hash.wav'));
      if (await destination.exists()) {
        await readVerifiedBytes(asset);
      } else {
        await temporary.rename(destination.path);
      }
      return asset;
    } finally {
      // The staging directory is created and owned by this operation.
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// Returns bytes suitable for multipart upload, verified against the saved
  /// identity. Missing or changed assets cannot silently become another voice.
  Future<Uint8List> readVerifiedBytes(DialogReferenceAsset asset) async {
    final file = File(
      p.joinAll([projectDirectory.path, ...asset.relativePath.split('/')]),
    );
    if (!await file.exists()) {
      throw StateError('Reference is missing: ${asset.relativePath}');
    }
    await _assertWithinProject(file.path);
    final bytes = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in file.openRead()) {
      size += chunk.length;
      if (size > maxBytes) {
        throw StateError('Reference exceeds $maxBytes bytes.');
      }
      bytes.add(chunk);
    }
    final result = bytes.takeBytes();
    _requireWav(result);
    if (sha256.convert(result).toString() != asset.sha256) {
      throw StateError('Reference content changed: ${asset.relativePath}');
    }
    return result;
  }

  Future<void> _assertWithinProject(String path) async {
    final root = await projectDirectory.resolveSymbolicLinks();
    final resolved = await File(path).resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) {
      throw StateError('Reference path escapes the project directory.');
    }
  }

  void _requireWav(List<int> bytes) {
    if (bytes.length < 12 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const FormatException('Reference must be a RIFF WAV file.');
    }
    // Header/container identification only; model-specific rate, duration and
    // PCM validation belong to the backend adapter/decoder.
  }
}
