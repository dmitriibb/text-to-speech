import 'package:archive/archive_io.dart';

class ModelArchiveExtractor {
  static Future<void> extractArchive({
    required String archivePath,
    required String archiveFormat,
    required String outputDir,
  }) async {
    switch (archiveFormat) {
      case 'tar.bz2':
        await extractFileToDisk(archivePath, outputDir);
        return;
      default:
        throw UnsupportedError('Unsupported archive format: $archiveFormat');
    }
  }
}
