import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Portable, bounded PCM decoder. A turn may contain up to 128 MiB; the full
/// conversation is streamed through disk, never accumulated in memory.
class PcmWave {
  PcmWave(this.samples, this.sampleRate);
  final Float64List samples;
  final int sampleRate;

  static PcmWave decode(Uint8List bytes) {
    if (bytes.length < 44 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const FormatException('Expected a RIFF PCM WAV.');
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(4, Endian.little) + 8 != bytes.length) {
      throw const FormatException('Truncated or invalid WAV size.');
    }
    int? format, channels, rate, bits, block, start, length;
    for (var offset = 12; offset + 8 <= bytes.length;) {
      final id = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (body + size > bytes.length) {
        throw const FormatException('Truncated WAV chunk.');
      }
      if (id == 'fmt ') {
        if (size < 16) throw const FormatException('Invalid WAV format.');
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        rate = data.getUint32(body + 4, Endian.little);
        block = data.getUint16(body + 12, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        start = body;
        length = size;
      }
      offset = body + size + (size & 1);
    }
    if (format == null ||
        channels == null ||
        rate == null ||
        bits == null ||
        block == null ||
        start == null ||
        length == null ||
        channels < 1 ||
        channels > 8 ||
        rate < 8000 ||
        rate > 192000 ||
        !((format == 1 && [8, 16, 24, 32].contains(bits)) ||
            (format == 3 && bits == 32)) ||
        block != channels * bits ~/ 8 ||
        length == 0 ||
        length % block != 0) {
      throw const FormatException(
        'Unsupported WAV: use PCM 8/16/24/32-bit or float32, 1–8 channels.',
      );
    }
    final samples = Float64List(length ~/ block);
    for (var frame = 0; frame < samples.length; frame++) {
      var sum = 0.0;
      for (var channel = 0; channel < channels; channel++) {
        final offset = start + frame * block + channel * bits ~/ 8;
        double sample;
        if (format == 3) {
          sample = data.getFloat32(offset, Endian.little);
        } else {
          sample = switch (bits) {
            8 => (data.getUint8(offset) - 128) / 128,
            16 => data.getInt16(offset, Endian.little) / 32768,
            24 =>
              (((data.getUint8(offset) |
                              (data.getUint8(offset + 1) << 8) |
                              (data.getUint8(offset + 2) << 16)) <<
                          8) >>
                      8) /
                  8388608,
            _ => data.getInt32(offset, Endian.little) / 2147483648,
          };
          // Dart ints are wider than 32 bits: explicitly sign extend PCM24.
          if (bits == 24 && sample >= 1) sample -= 2;
        }
        if (!sample.isFinite) {
          throw const FormatException('Non-finite WAV sample.');
        }
        sum += sample;
      }
      samples[frame] = sum / channels;
    }
    return PcmWave(samples, rate);
  }

  static Uint8List header(int frames, int rate) {
    final bytes = Uint8List(44);
    final data = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, ascii.encode('RIFF'));
    data.setUint32(4, 36 + frames * 2, Endian.little);
    bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    bytes.setRange(36, 40, ascii.encode('data'));
    data.setUint32(40, frames * 2, Endian.little);
    return bytes;
  }
}

class ConversationRenderInput {
  const ConversationRenderInput({
    required this.turnId,
    required this.actorId,
    required this.path,
    required this.sha256,
    required this.pauseAfterMs,
  });
  final String turnId, actorId, path, sha256;
  final int pauseAfterMs;
}

class ConversationRenderer {
  Future<void> render({
    required List<ConversationRenderInput> inputs,
    required String outputPath,
    required String projectId,
    required int revision,
    bool trimSilence = false,
    bool Function()? isCancelled,
    void Function(double)? onProgress,
  }) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final exits = ReceivePort();
    final exited = Completer<void>();
    final exitSubscription = exits.listen((_) {
      if (!exited.isCompleted) exited.complete();
    });
    final done = Completer<void>();
    final subscription = messages.listen((message) {
      if (message is double) {
        onProgress?.call(message);
      } else if (message == 'done') {
        if (!done.isCompleted) done.complete();
      } else if (!done.isCompleted) {
        done.completeError(StateError(message.toString()));
      }
    });
    final errorSubscription = errors.listen((error) {
      if (!done.isCompleted) done.completeError(StateError(error.toString()));
    });
    Isolate? worker;
    Timer? timer;
    try {
      if (isCancelled?.call() ?? false) throw StateError('Render cancelled.');
      worker = await Isolate.spawn(
        _renderWorker,
        (
          messages.sendPort,
          inputs,
          outputPath,
          projectId,
          revision,
          trimSilence,
        ),
        onError: errors.sendPort,
        onExit: exits.sendPort,
      );
      timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if ((isCancelled?.call() ?? false) && !done.isCompleted) {
          worker?.kill(priority: Isolate.immediate);
          done.completeError(
            StateError('Render cancelled or project changed.'),
          );
        }
      });
      await done.future;
      if (isCancelled?.call() ?? false) {
        throw StateError('Render cancelled or project changed.');
      }
    } catch (_) {
      worker?.kill(priority: Isolate.immediate);
      if (worker != null && !exited.isCompleted) {
        await exited.future.timeout(const Duration(seconds: 5));
      }
      // Unique destinations are owned by this render, never an old master.
      for (final suffix in [
        '',
        '.part',
        '.float',
        '.manifest.json',
        '.manifest.json.part',
      ]) {
        final file = File('$outputPath$suffix');
        if (await file.exists()) await file.delete();
      }
      rethrow;
    } finally {
      timer?.cancel();
      worker?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      messages.close();
      errors.close();
      exits.close();
    }
  }
}

void _renderWorker(
  (SendPort, List<ConversationRenderInput>, String, String, int, bool) args,
) {
  final (port, inputs, outputPath, projectId, revision, trim) = args;
  try {
    if (inputs.isEmpty) throw StateError('No included turns.');
    const rate = 48000;
    final raw = File('$outputPath.float');
    raw.parent.createSync(recursive: true);
    final sink = raw.openSync(mode: FileMode.write);
    var frames = 0;
    var peak = 0.0;
    final timeline = <Map<String, Object?>>[];
    try {
      for (var index = 0; index < inputs.length; index++) {
        final input = inputs[index];
        final file = File(input.path);
        if (file.lengthSync() > 128 * 1024 * 1024) {
          throw StateError('Turn exceeds 128 MiB: ${input.turnId}');
        }
        final bytes = file.readAsBytesSync();
        if (sha256.convert(bytes).toString() != input.sha256) {
          throw StateError('Clip changed: ${input.turnId}');
        }
        final wave = PcmWave.decode(bytes);
        var start = 0;
        var end = wave.samples.length;
        // Trim only sustained digital near-silence; retain 20 ms and never
        // touch breaths/consonants. No fade is applied to audible boundaries.
        if (trim) {
          final margin = (wave.sampleRate * .020).round();
          while (start < end && wave.samples[start].abs() < .00001) {
            start++;
          }
          while (end > start && wave.samples[end - 1].abs() < .00001) {
            end--;
          }
          start = math.max(0, start - margin);
          end = math.min(wave.samples.length, end + margin);
          if (end <= start) {
            start = 0;
            end = wave.samples.length;
          }
        }
        final count = ((end - start) * rate / wave.sampleRate).round();
        timeline.add({
          'turnId': input.turnId,
          'actorId': input.actorId,
          'inputHash': input.sha256,
          'offsetFrames': frames,
          'speechFrames': count,
          'pauseAfterMs': index == inputs.length - 1 ? 0 : input.pauseAfterMs,
          'trimStartFrames': start,
          'trimEndFrames': wave.samples.length - end,
          'inputRate': wave.sampleRate,
        });
        final cutoff = math.min(1.0, rate / wave.sampleRate) * .94;
        const radius = 32;
        for (var base = 0; base < count; base += 4096) {
          final n = math.min(4096, count - base);
          final chunk = ByteData(n * 8);
          for (var j = 0; j < n; j++) {
            final position = start + (base + j) * wave.sampleRate / rate;
            double sample;
            if (wave.sampleRate == rate) {
              sample = wave.samples[math.min(end - 1, position.round())];
            } else {
              var sum = 0.0, weightSum = 0.0;
              final center = position.floor();
              for (var k = center - radius + 1; k <= center + radius; k++) {
                if (k < start || k >= end) continue;
                final distance = position - k;
                final x = math.pi * distance * cutoff;
                final sinc = x.abs() < 1e-9 ? 1.0 : math.sin(x) / x;
                final window = .5 + .5 * math.cos(math.pi * distance / radius);
                final weight = cutoff * sinc * window;
                sum += wave.samples[k] * weight;
                weightSum += weight;
              }
              sample = weightSum.abs() < 1e-9 ? 0 : sum / weightSum;
            }
            peak = math.max(peak, sample.abs());
            chunk.setFloat64(j * 8, sample, Endian.little);
          }
          sink.writeFromSync(chunk.buffer.asUint8List());
        }
        frames += count;
        if (index < inputs.length - 1) {
          final pause = (input.pauseAfterMs * rate / 1000).round();
          for (var remaining = pause; remaining > 0; remaining -= 4096) {
            sink.writeFromSync(Uint8List(math.min(remaining, 4096) * 8));
          }
          frames += pause;
        }
        if (frames * 2 > 0xffffffff - 36) {
          throw StateError('Conversation exceeds RIFF size limit.');
        }
        port.send((index + 1) / inputs.length * .8);
      }
    } finally {
      sink.closeSync();
    }
    final gain = peak > math.pow(10, -1 / 20)
        ? math.pow(10, -1 / 20) / peak
        : 1.0;
    final source = raw.openSync();
    final destination = File('$outputPath.part').openSync(mode: FileMode.write);
    try {
      destination.writeFromSync(PcmWave.header(frames, rate));
      var processed = 0;
      while (processed < frames) {
        final n = math.min(4096, frames - processed);
        final chunk = ByteData.sublistView(source.readSync(n * 8));
        final pcm = ByteData(n * 2);
        for (var i = 0; i < n; i++) {
          pcm.setInt16(
            i * 2,
            (chunk.getFloat64(i * 8, Endian.little) * gain * 32767)
                .round()
                .clamp(-32768, 32767),
            Endian.little,
          );
        }
        destination.writeFromSync(pcm.buffer.asUint8List());
        processed += n;
        port.send(.8 + processed / frames * .2);
      }
      destination.flushSync();
    } finally {
      source.closeSync();
      destination.closeSync();
    }
    final manifest = File('$outputPath.manifest.json.part');
    manifest.writeAsStringSync(
      jsonEncode({
        'version': 1,
        'projectId': projectId,
        'revision': revision,
        'sampleRate': rate,
        'channels': 1,
        'bits': 16,
        'totalFrames': frames,
        'trimSilence': trim,
        'peakGain': gain,
        'resampler': '64-tap Hann-windowed sinc, 0.94 Nyquist cutoff',
        'turns': timeline,
      }),
      flush: true,
    );
    manifest.renameSync('$outputPath.manifest.json');
    File('$outputPath.part').renameSync(outputPath);
    raw.deleteSync();
    port.send('done');
  } catch (error) {
    port.send(error.toString());
  }
}
