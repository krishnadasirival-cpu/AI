import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';

class ThumbnailGenerator {
  static final Map<String, Uint8List> _memoryCache = {};

  /// Generates or retrieves a lightweight thumbnail (~15KB) for a given file.
  static Future<Uint8List> getThumbnail(File file) async {
    final path = file.path;
    if (_memoryCache.containsKey(path)) {
      return _memoryCache[path]!;
    }

    final mime = lookupMimeType(path) ?? '';
    Uint8List result;

    if (mime.startsWith('image/')) {
      try {
        final length = await file.length();
        if (length <= 25 * 1024) {
          // If image is already tiny, read directly
          result = await file.readAsBytes();
        } else {
          // Read first 16KB of file or header
          final raf = await file.open(mode: FileMode.read);
          final buffer = Uint8List(16 * 1024);
          final readBytes = await raf.readInto(buffer);
          await raf.close();
          result = Uint8List.sublistView(buffer, 0, readBytes);
        }
      } catch (_) {
        result = _generateSvgPlaceholder(mime);
      }
    } else {
      result = _generateSvgPlaceholder(mime);
    }

    _memoryCache[path] = result;
    return result;
  }

  static Uint8List _generateSvgPlaceholder(String mime) {
    String iconLabel = 'FILE';
    String color = '#5C6BC0';

    if (mime.startsWith('video/')) {
      iconLabel = 'VIDEO';
      color = '#EF5350';
    } else if (mime.startsWith('audio/')) {
      iconLabel = 'AUDIO';
      color = '#AB47BC';
    } else if (mime.contains('pdf')) {
      iconLabel = 'PDF';
      color = '#E53935';
    } else if (mime.contains('zip') || mime.contains('tar') || mime.contains('archive')) {
      iconLabel = 'ZIP';
      color = '#FFA726';
    } else if (mime.startsWith('text/')) {
      iconLabel = 'DOC';
      color = '#42A5F5';
    }

    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <rect width="120" height="120" rx="20" fill="$color" opacity="0.15"/>
  <rect x="15" y="15" width="90" height="90" rx="16" fill="$color" opacity="0.85"/>
  <text x="60" y="68" font-family="sans-serif" font-weight="bold" font-size="20" fill="#FFFFFF" text-anchor="middle">$iconLabel</text>
</svg>
''';
    return Uint8List.fromList(svg.codeUnits);
  }

  static void clearCache() {
    _memoryCache.clear();
  }
}
