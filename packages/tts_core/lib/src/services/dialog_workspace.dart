import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/dialog_mode.dart';
import '../models/synthesis_target.dart';
import 'conversation_renderer.dart';
import 'dialog_reference_store.dart';

class DialogCancellation {
  bool cancelled = false;
  void check() {
    if (cancelled) throw StateError('Generation cancelled.');
  }
}

class DialogGenerationRequest {
  const DialogGenerationRequest({
    required this.projectId,
    required this.runId,
    required this.line,
    required this.actor,
    required this.outputPath,
    required this.projectDirectory,
    required this.cancellation,
  });
  final String projectId, runId, outputPath;
  final DialogLineItem line;
  final DialogSpeakerSettings actor;
  final Directory projectDirectory;
  final DialogCancellation cancellation;
}

typedef DialogGenerator =
    Future<void> Function(DialogGenerationRequest request);

/// Shared dialogue lifecycle. Apps inject only synthesis, writable storage,
/// playback and save/share glue. Owned clips never depend on task-list files.
class DialogWorkspace extends ChangeNotifier {
  DialogWorkspace({required this.directoryProvider, required this.generate});
  final Future<Directory> Function() directoryProvider;
  final DialogGenerator generate;
  List<DialogLineItem> lines = const [];
  Map<String, DialogSpeakerSettings> actors = const {};
  List<DialogImportIssue> importIssues = const [];
  String? error;
  String projectId = _identity('project');
  int revision = 0;
  int defaultPauseMs = 250;
  bool trimSilence = false;
  bool isGenerating = false, isRendering = false;
  double progress = 0;
  DateTime? startedAt;
  String? masterPath;
  String? masterHash;
  int? masterRevision;
  DialogCancellation? _cancellation;
  int _renderRun = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Timer? _ticker;
  bool get masterIsCurrent => masterPath != null && masterRevision == revision;
  String get elapsed => startedAt == null
      ? ''
      : '${DateTime.now().difference(startedAt!).inSeconds}s';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _change() {
    revision++;
    error = null;
    _notify();
  }

  void importText(
    String text,
    DialogSpeakerSettings Function(String) defaults,
  ) {
    if (isGenerating) return;
    final result = const DialogModeParser().parseWithDiagnostics(text);
    importIssues = result.issues;
    if (result.lines.isEmpty) {
      error = 'Clipboard does not contain lines in the form "Speaker: text".';
      _notify();
      return;
    }
    cancel();
    projectId = _identity('project');
    lines = result.lines
        .map((line) => line.copyWith(id: _identity('turn')))
        .toList();
    actors = {
      for (final name in lines.map((line) => line.speakerName).toSet())
        name: actors[name] ?? defaults(name),
    };
    masterPath = null;
    masterHash = null;
    masterRevision = null;
    _change();
  }

  void setActor(DialogSpeakerSettings actor) {
    actors = {...actors, actor.speakerName: actor};
    lines = lines
        .map(
          (line) =>
              line.speakerName == actor.speakerName ? _invalidate(line) : line,
        )
        .toList();
    _change();
  }

  void edit(DialogLineItem edited) {
    final old = lines.where((line) => line.id == edited.id).firstOrNull;
    if (old == null) return;
    if (edited.pauseAfterMs != null &&
        (edited.pauseAfterMs! < 0 || edited.pauseAfterMs! > 2000)) {
      throw ArgumentError('Pause must be between 0 and 2000 ms.');
    }
    final needsGeneration =
        old.text != edited.text || old.textOverride != edited.textOverride;
    final next = needsGeneration
        ? _invalidate(edited).copyWith(revision: old.revision + 1)
        : edited;
    lines = lines.map((line) => line.id == edited.id ? next : line).toList();
    _change();
  }

  void remove(String id) {
    lines = lines.where((line) => line.id != id).toList();
    _change();
  }

  void setTiming(int pause, bool trim) {
    if (pause < 0 || pause > 2000) {
      throw ArgumentError('Pause must be between 0 and 2000 ms.');
    }
    defaultPauseMs = pause;
    trimSilence = trim;
    _change();
  }

  String fingerprint(DialogLineItem line, DialogSpeakerSettings actor) => sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'project': projectId,
            'turn': line.id,
            'revision': line.revision,
            'text': line.effectiveText,
            'actor': actor.toJson(),
          }),
        ),
      )
      .toString();

  bool _current(DialogLineItem line) {
    final actor = actors[line.speakerName];
    return actor != null &&
        line.status == DialogLineStatus.ready &&
        line.outputPath != null &&
        line.clipHash != null &&
        line.clipFingerprint == fingerprint(line, actor);
  }

  Future<void> generateMissing({String? onlyTurnId}) async {
    if (isGenerating || isRendering) return;
    final selected = lines
        .where(
          (line) =>
              line.included &&
              line.hasText &&
              (onlyTurnId == null
                  ? !_current(line) || !File(line.outputPath!).existsSync()
                  : line.id == onlyTurnId),
        )
        .toList();
    if (selected.isEmpty) {
      error = 'All included turns are already current.';
      _notify();
      return;
    }
    for (final line in selected) {
      if (actors[line.speakerName]?.effectiveTarget == null) {
        error = 'Select a ready AI model for ${line.speakerName}.';
        _notify();
        return;
      }
    }
    final token = DialogCancellation();
    _cancellation = token;
    final run = _identity('run');
    final capturedProject = projectId;
    final snapshots = {
      for (final line in selected)
        line.id: DialogSpeakerSettings.fromJson(
          actors[line.speakerName]!.toJson(),
        ),
    };
    isGenerating = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    startedAt = DateTime.now();
    progress = 0;
    error = null;
    revision++;
    final ids = selected.map((line) => line.id).toSet();
    lines = lines
        .map(
          (line) => ids.contains(line.id)
              ? _invalidate(line).copyWith(status: DialogLineStatus.queued)
              : line,
        )
        .toList();
    _notify();
    try {
      final directory = await directoryProvider();
      await directory.create(recursive: true);
      final clips = Directory(p.join(directory.path, 'clips'));
      await clips.create(recursive: true);
      for (var i = 0; i < selected.length; i++) {
        token.check();
        final snapshot = selected[i];
        final actor = snapshots[snapshot.id]!;
        final fp = fingerprint(snapshot, actor);
        bool stillCurrent() {
          final current = lines
              .where((line) => line.id == snapshot.id)
              .firstOrNull;
          final currentActor = actors[snapshot.speakerName];
          return !token.cancelled &&
              projectId == capturedProject &&
              current != null &&
              currentActor != null &&
              fingerprint(current, currentActor) == fp;
        }

        if (!stillCurrent()) continue;
        _replace(
          snapshot.id,
          _invalidate(
            lines.firstWhere((line) => line.id == snapshot.id),
          ).copyWith(status: DialogLineStatus.generating),
        );
        _notify();
        final output = p.join(clips.path, '${snapshot.id}-$run.wav');
        try {
          await generate(
            DialogGenerationRequest(
              projectId: capturedProject,
              runId: run,
              line: snapshot,
              actor: actor,
              outputPath: output,
              projectDirectory: directory,
              cancellation: token,
            ),
          );
          token.check();
          final hash = await _hashValidatedFile(output);
          if (!stillCurrent()) {
            await _delete(output);
            continue;
          }
          _replace(
            snapshot.id,
            lines
                .firstWhere((line) => line.id == snapshot.id)
                .copyWith(
                  status: DialogLineStatus.ready,
                  outputPath: output,
                  clipFingerprint: fp,
                  clipHash: hash,
                  errorMessage: null,
                  taskId: null,
                ),
          );
        } catch (failure) {
          await _delete(output);
          if (stillCurrent()) {
            _replace(
              snapshot.id,
              _invalidate(snapshot).copyWith(
                status: DialogLineStatus.failed,
                errorMessage: failure.toString(),
              ),
            );
            error = '${snapshot.speakerName}: $failure';
          }
        }
        progress = (i + 1) / selected.length;
        _notify();
      }
    } catch (failure) {
      error = failure.toString();
    } finally {
      lines = lines
          .map(
            (line) =>
                line.status == DialogLineStatus.queued ||
                    line.status == DialogLineStatus.generating
                ? _invalidate(
                    line,
                  ).copyWith(errorMessage: 'Generation cancelled.')
                : line,
          )
          .toList();
      isGenerating = false;
      _ticker?.cancel();
      _cancellation = null;
      _notify();
      if (!_disposed) await save();
    }
  }

  void cancel() {
    _cancellation?.cancelled = true;
    _renderRun++;
    if (isGenerating) {
      error =
          'Cancelled. In-flight backend computation may finish; its result will not be attached.';
    }
    _notify();
  }

  Future<void> render() async {
    if (isGenerating || isRendering) return;
    final included = lines
        .where((line) => line.included && line.hasText)
        .toList();
    final missing = included
        .where(
          (line) => !_current(line) || !File(line.outputPath!).existsSync(),
        )
        .toList();
    if (included.isEmpty || missing.isNotEmpty) {
      error = included.isEmpty
          ? 'No included turns to render.'
          : 'Generate or retry these turns first: ${missing.map((line) => '${lines.indexOf(line) + 1} (${line.speakerName})').join(', ')}';
      _notify();
      return;
    }
    final capturedRevision = revision;
    final run = ++_renderRun;
    isRendering = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    progress = 0;
    startedAt = DateTime.now();
    error = null;
    _notify();
    try {
      final directory = await directoryProvider();
      final output = p.join(
        directory.path,
        'renders',
        '${_identity('conversation')}.wav',
      );
      await ConversationRenderer().render(
        inputs: included
            .map(
              (line) => ConversationRenderInput(
                turnId: line.id,
                actorId: actors[line.speakerName]!.actorId,
                path: line.outputPath!,
                sha256: line.clipHash!,
                pauseAfterMs: line.pauseAfterMs ?? defaultPauseMs,
              ),
            )
            .toList(),
        outputPath: output,
        projectId: projectId,
        revision: capturedRevision,
        trimSilence: trimSilence,
        isCancelled: () =>
            _disposed || run != _renderRun || revision != capturedRevision,
        onProgress: (value) {
          progress = value;
          _notify();
        },
      );
      masterPath = output;
      masterHash = await _hashValidatedFile(output);
      masterRevision = capturedRevision;
    } catch (failure) {
      error = failure.toString();
      masterRevision = null;
    } finally {
      isRendering = false;
      _ticker?.cancel();
      _notify();
      if (!_disposed) await save();
    }
  }

  Future<DialogReferenceAsset> importReference(
    File file,
    String transcript,
  ) async {
    final directory = await directoryProvider();
    return DialogReferenceStore(
      projectDirectory: directory,
    ).importWav(file, transcript: transcript);
  }

  Map<String, Object?> _json(Directory directory) => {
    'version': 1,
    'projectId': projectId,
    'revision': revision,
    'defaultPauseMs': defaultPauseMs,
    'trimSilence': trimSilence,
    'actors': actors.values.map((actor) => actor.toJson()).toList(),
    'master': masterPath == null
        ? null
        : p.relative(masterPath!, from: directory.path).replaceAll('\\', '/'),
    'masterRevision': masterRevision,
    'masterHash': masterHash,
    'turns': lines
        .map(
          (line) => {
            'id': line.id,
            'speakerName': line.speakerName,
            'text': line.text,
            'textOverride': line.textOverride,
            'revision': line.revision,
            'included': line.included,
            'pauseAfterMs': line.pauseAfterMs,
            'clip': line.outputPath == null
                ? null
                : p
                      .relative(line.outputPath!, from: directory.path)
                      .replaceAll('\\', '/'),
            'clipFingerprint': line.clipFingerprint,
            'clipHash': line.clipHash,
          },
        )
        .toList(),
  };

  Future<void> save() async {
    try {
      final directory = await directoryProvider();
      final json = jsonEncode(_json(directory));
      final operation = _writes.then((_) async {
        await directory.create(recursive: true);
        final file = File(p.join(directory.path, 'project.json'));
        final temporary = File('${file.path}.part');
        await temporary.writeAsString(json, flush: true);
        await temporary.rename(file.path);
      });
      _writes = operation.catchError((Object _) {});
      await operation;
    } catch (failure) {
      error = 'Project save failed: $failure';
      _notify();
    }
  }

  Future<void> load() async {
    if (isGenerating || isRendering) return;
    try {
      await _writes;
      final directory = await directoryProvider();
      final file = File(p.join(directory.path, 'project.json'));
      if (!await file.exists()) return;
      if (await file.length() > 8 * 1024 * 1024) {
        throw const FormatException('Project exceeds 8 MiB.');
      }
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported project version.');
      }
      String? path(Object? relative) {
        if (relative == null) return null;
        final value = relative as String;
        if (p.isAbsolute(value) ||
            value.contains(':') ||
            value.contains('\\') ||
            value.split('/').any((part) => part == '..' || part.isEmpty)) {
          throw const FormatException('Invalid project asset path.');
        }
        return p.joinAll([directory.path, ...value.split('/')]);
      }

      final nextActors = <String, DialogSpeakerSettings>{};
      for (final value in json['actors'] as List) {
        final actor = DialogSpeakerSettings.fromJson(
          Map<String, Object?>.from(value as Map),
        );
        if (nextActors.containsKey(actor.speakerName)) {
          throw const FormatException('Duplicate actor.');
        }
        nextActors[actor.speakerName] = actor;
        for (final reference in actor.referencesByTarget.values) {
          try {
            await DialogReferenceStore(
              projectDirectory: directory,
            ).readVerifiedBytes(reference);
          } catch (_) {
            /* Invalid references are retained for repair; dependent clips become stale below. */
          }
        }
      }
      final nextLines = <DialogLineItem>[];
      final ids = <String>{};
      for (final value in json['turns'] as List) {
        final item = value as Map;
        final pause = item['pauseAfterMs'] as int?;
        if (pause != null && (pause < 0 || pause > 2000)) {
          throw const FormatException('Invalid turn pause.');
        }
        var line = DialogLineItem(
          id: item['id'] as String,
          speakerName: item['speakerName'] as String,
          text: item['text'] as String,
          textOverride: item['textOverride'] as String?,
          revision: item['revision'] as int,
          included: item['included'] as bool,
          pauseAfterMs: pause,
          outputPath: path(item['clip']),
          clipFingerprint: item['clipFingerprint'] as String?,
          clipHash: item['clipHash'] as String?,
        );
        if (!ids.add(line.id) || !nextActors.containsKey(line.speakerName)) {
          throw const FormatException('Invalid turn identity/actor.');
        }
        final actor = nextActors[line.speakerName]!;
        var valid = line.outputPath != null && line.clipHash != null;
        if (valid) {
          try {
            final owned = File(line.outputPath!);
            final root = await directory.resolveSymbolicLinks();
            if (!p.isWithin(root, await owned.resolveSymbolicLinks())) {
              throw StateError('Clip escapes project.');
            }
            final hash = await sha256.bind(owned.openRead()).first;
            valid = hash.toString() == line.clipHash;
            if (actor.reference != null) {
              await DialogReferenceStore(
                projectDirectory: directory,
              ).readVerifiedBytes(actor.reference!);
            }
          } catch (_) {
            valid = false;
          }
        }
        nextLines.add(
          line.copyWith(
            status: valid ? DialogLineStatus.ready : DialogLineStatus.idle,
            errorMessage: valid
                ? null
                : 'Missing or changed clip/reference; regenerate.',
          ),
        );
      }
      final pause = json['defaultPauseMs'] as int;
      if (pause < 0 || pause > 2000) {
        throw const FormatException('Invalid default pause.');
      }
      // Commit only after all JSON validation; corrupt projects retain current work.
      final nextProjectId = json['projectId'] as String;
      final nextRevision = json['revision'] as int;
      final nextTrim = json['trimSilence'] as bool;
      final nextMaster = path(json['master']);
      final nextMasterRevision = json['masterRevision'] as int?;
      final nextMasterHash = json['masterHash'] as String?;
      var masterValid = false;
      if (nextMaster != null && nextMasterHash != null) {
        try {
          masterValid = await _hashValidatedFile(nextMaster) == nextMasterHash;
        } catch (_) {}
      }
      projectId = nextProjectId;
      revision = nextRevision;
      actors = nextActors;
      lines = nextLines;
      defaultPauseMs = pause;
      trimSilence = nextTrim;
      masterPath = nextMaster;
      masterHash = nextMasterHash;
      masterRevision = masterValid ? nextMasterRevision : null;
      if (masterPath != null && !await File(masterPath!).exists()) {
        masterPath = null;
      }
      lines = lines
          .map((line) => _current(line) ? line : _invalidate(line))
          .toList();
      if (lines.any(
        (line) => line.included && line.hasText && !_current(line),
      )) {
        masterRevision = null;
      }
      importIssues = const [];
      error = null;
      _notify();
    } catch (failure) {
      error =
          'Project reload failed; current work and exported WAVs were retained: $failure';
      _notify();
    }
  }

  void _replace(String id, DialogLineItem next) {
    lines = lines.map((line) => line.id == id ? next : line).toList();
  }

  DialogLineItem _invalidate(DialogLineItem line) => line.copyWith(
    taskId: null,
    outputPath: null,
    status: DialogLineStatus.idle,
    clipFingerprint: null,
    clipHash: null,
    errorMessage: null,
  );
  Future<void> _delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String _identity(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;
  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    cancel();
    super.dispose();
  }
}

Future<String> _hashValidatedFile(String path) => Isolate.run(() {
  final file = File(path);
  if (file.lengthSync() > 128 * 1024 * 1024) {
    throw StateError('Clip exceeds 128 MiB.');
  }
  final bytes = file.readAsBytesSync();
  PcmWave.decode(bytes);
  return sha256.convert(bytes).toString();
});
