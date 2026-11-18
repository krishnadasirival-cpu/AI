import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class TempCacheManager {
  static final Set<String> _trackedPreviewFiles = {};

  /// Resolves the dedicated temp cache directory for P2P file pool previews.
  static Future<Directory> _getTempCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'p2p_pool_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Downloads or caches a remote stream for temporary modal preview.
  static Future<File> cacheForPreview(String streamUrl, String fileName) async {
    final dir = await _getTempCacheDir();
    final tempFile = File(p.join(dir.path, 'preview_${DateTime.now().millisecondsSinceEpoch}_$fileName'));

    final response = await http.get(Uri.parse(streamUrl));
    await tempFile.writeAsBytes(response.bodyBytes);

    _trackedPreviewFiles.add(tempFile.path);
    return tempFile;
  }

  /// Writes raw byte data to a temporary preview file.
  static Future<File> cacheBytesForPreview(Uint8List bytes, String fileName) async {
    final dir = await _getTempCacheDir();
    final tempFile = File(p.join(dir.path, 'preview_${DateTime.now().millisecondsSinceEpoch}_$fileName'));
    await tempFile.writeAsBytes(bytes);

    _trackedPreviewFiles.add(tempFile.path);
    return tempFile;
  }

  /// Purges previewed temporary files when the viewer modal closes.
  static Future<void> purgePreviewedFiles() async {
    for (final path in _trackedPreviewFiles) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
    _trackedPreviewFiles.clear();
  }

  /// Explicitly saves a previewed file or byte payload to permanent user storage (e.g. Downloads).
  static Future<String> saveToPermanentStorage(List<int> bytes, String fileName) async {
    Directory? targetDir;

    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        targetDir = downloadDir;
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final winDownloads = Directory(p.join(userProfile, 'Downloads'));
        if (await winDownloads.exists()) {
          targetDir = winDownloads;
        }
      }
    }

    // Fallback to app documents
    targetDir ??= await getApplicationDocumentsDirectory();

    final targetFile = File(p.join(targetDir.path, fileName));
    await targetFile.writeAsBytes(bytes);

    return targetFile.path;
  }
}
