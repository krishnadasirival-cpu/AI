import 'dart:io';
import 'package:path/path.dart' as p;

class ScannedFolder {
  final String path;
  final String name;
  final int estimatedItemCount;

  const ScannedFolder({
    required this.path,
    required this.name,
    this.estimatedItemCount = 0,
  });

  @override
  String toString() => 'ScannedFolder($name, $path, items: $estimatedItemCount)';
}

class StorageScanner {
  /// Scans common user-facing media, documents, and download directories.
  static Future<List<ScannedFolder>> scanAvailableFolders() async {
    final List<ScannedFolder> results = [];
    final List<Directory> candidates = [];

    if (Platform.isAndroid) {
      final base = Directory('/storage/emulated/0');
      if (await base.exists()) {
        try {
          final entries = base.listSync();
          for (final entry in entries) {
            if (entry is Directory) {
              final baseName = p.basename(entry.path);
              // Filter hidden folders and system Android data folders by default
              if (!baseName.startsWith('.') && baseName.toLowerCase() != 'android') {
                candidates.add(entry);
              }
            }
          }
        } catch (_) {
          // If directory listing fails, fall back to known standard subdirectories
          const standard = [
            'Download',
            'Documents',
            'Pictures',
            'DCIM',
            'Music',
            'Movies',
            'Podcasts',
            'Books'
          ];
          for (final name in standard) {
            final dir = Directory('/storage/emulated/0/$name');
            if (await dir.exists()) {
              candidates.add(dir);
            }
          }
        }
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final common = [
          'Downloads',
          'Documents',
          'Pictures',
          'Videos',
          'Music',
          'Desktop'
        ];
        for (final sub in common) {
          final dir = Directory(p.join(userProfile, sub));
          if (dir.existsSync()) {
            candidates.add(dir);
          }
        }
      }

      // Check root drive C:\
      final cDrive = Directory('C:\\');
      if (cDrive.existsSync()) {
        final poolShare = Directory('C:\\P2P_Pool_Share');
        if (poolShare.existsSync()) {
          candidates.add(poolShare);
        }
      }
    } else {
      // macOS / Linux / other fallbacks
      final home = Platform.environment['HOME'];
      if (home != null) {
        final common = ['Downloads', 'Documents', 'Pictures', 'Music', 'Videos'];
        for (final sub in common) {
          final dir = Directory(p.join(home, sub));
          if (dir.existsSync()) {
            candidates.add(dir);
          }
        }
      }
    }

    // Measure shallow item count for each candidate folder
    for (final dir in candidates) {
      int count = 0;
      try {
        count = dir.listSync().length;
      } catch (_) {
        count = 0;
      }
      results.add(
        ScannedFolder(
          path: dir.path,
          name: p.basename(dir.path).isEmpty ? dir.path : p.basename(dir.path),
          estimatedItemCount: count,
        ),
      );
    }

    return results;
  }
}
