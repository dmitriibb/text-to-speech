import 'package:archive/archive_io.dart';

class ModelArchiveExtractor {
  static Future<void> extractArchive({
    required String archivePath,
    required String archiveFormat,
    required String outputDir,
  }) async {
    switch (archiveFormat) {
      case 'tar.bz2':
        final input = InputFileStream(archivePath);
        try {
          final tarBytes = BZip2Decoder().decodeBuffer(input);
          final archive = TarDecoder().decodeBytes(tarBytes);
          extractArchiveToDisk(archive, outputDir);
        } finally {
          input.close();
        }
        return;
      default:
        throw UnsupportedError('Unsupported archive format: $archiveFormat');
    }
  }
}