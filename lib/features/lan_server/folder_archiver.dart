import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class FolderArchiver {
  /// Recursively compresses the folder at [directory] into an in-memory ZIP byte buffer.
  static Future<List<int>> zipFolder(Directory directory) async {
    final archive = Archive();
    final basePath = directory.path;

    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relative = p.relative(entity.path, from: basePath);
        // Exclude system trash folders or hidden files from ZIP download
        if (relative.startsWith('.pool_trash') || relative.startsWith('.')) {
          continue;
        }

        try {
          final bytes = await entity.readAsBytes();
          final archiveFile = ArchiveFile(
            relative.replaceAll('\\', '/'),
            bytes.length,
            bytes,
          );
          archiveFile.lastModTime = (await entity.lastModified()).millisecondsSinceEpoch ~/ 1000;
          archive.addFile(archiveFile);
        } catch (_) {
          // Skip unreadable files
        }
      }
    }

    final encoder = ZipEncoder();
    final output = encoder.encode(archive);
    return output ?? <int>[];
  }
}
