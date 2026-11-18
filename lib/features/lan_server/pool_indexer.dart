import 'dart:async';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import '../../core/pool_contract.dart';

class PoolIndexer {
  final String deviceId;
  final String deviceName;
  final String hostIp;
  final int port;
  final List<String> sharedRoots;

  final Map<String, PoolFileItem> _items = {};
  final List<StreamSubscription> _watchers = [];
  final _changeController = StreamController<List<PoolFileItem>>.broadcast();

  PoolIndexer({
    required this.deviceId,
    required this.deviceName,
    required this.hostIp,
    required this.port,
    required this.sharedRoots,
  });

  Stream<List<PoolFileItem>> get onChange => _changeController.stream;

  List<PoolFileItem> getAllItems() => _items.values.toList();

  /// Starts indexing and attaches native file system watchers.
  Future<void> start() async {
    await rescanAll();
    _attachWatchers();
  }

  void _attachWatchers() {
    _disposeWatchers();
    for (final root in sharedRoots) {
      final dir = Directory(root);
      if (dir.existsSync()) {
        try {
          final sub = dir.watch(recursive: true).listen((event) {
            _handleFileSystemEvent(root, event);
          });
          _watchers.add(sub);
        } catch (_) {
          // File watching might not be supported on all virtual mount points
        }
      }
    }
  }

  void _disposeWatchers() {
    for (final w in _watchers) {
      w.cancel();
    }
    _watchers.clear();
  }

  Future<void> rescanAll() async {
    _items.clear();
    for (final root in sharedRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;

      final rootName = p.basename(root).isEmpty ? root : p.basename(root);

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          final relative = p.relative(entity.path, from: root).replaceAll('\\', '/');

          // Skip internal trash folder
          if (relative.startsWith('.pool_trash')) continue;

          final item = await _createPoolFileItem(entity, rootName, root, relative);
          if (item != null) {
            _items[item.relativePath] = item;
          }
        }
      } catch (_) {}
    }
    _changeController.add(getAllItems());
  }

  Future<PoolFileItem?> _createPoolFileItem(
    FileSystemEntity entity,
    String rootName,
    String rootPath,
    String relative,
  ) async {
    try {
      final stat = await entity.stat();
      final isDir = stat.type == FileSystemEntityType.directory;
      final fileName = p.basename(entity.path);
      final mime = isDir ? 'inode/directory' : (lookupMimeType(entity.path) ?? 'application/octet-stream');
      final encodedRel = Uri.encodeComponent(relative);

      final streamUrl = 'http://$hostIp:$port${PoolApiRoutes.pathStream}?path=$encodedRel';
      final thumbUrl = 'http://$hostIp:$port${PoolApiRoutes.pathThumb}?path=$encodedRel';

      return PoolFileItem(
        id: '${deviceId}_$relative',
        deviceId: deviceId,
        deviceName: deviceName,
        name: fileName,
        relativePath: relative,
        syncedRootFolder: rootName,
        mimeType: mime,
        sizeBytes: isDir ? 0 : stat.size,
        modifiedAt: stat.modified,
        isDirectory: isDir,
        thumbnailUrl: isDir ? null : thumbUrl,
        streamUrl: isDir ? null : streamUrl,
      );
    } catch (_) {
      return null;
    }
  }

  void _handleFileSystemEvent(String rootPath, FileSystemEvent event) async {
    final rootName = p.basename(rootPath);
    final relative = p.relative(event.path, from: rootPath).replaceAll('\\', '/');

    if (relative.startsWith('.pool_trash')) return;

    if (event.type == FileSystemEvent.delete) {
      _items.remove(relative);
      _changeController.add(getAllItems());
    } else {
      final entity = FileSystemEntity.isDirectorySync(event.path)
          ? Directory(event.path)
          : File(event.path);
      if (entity.existsSync()) {
        final item = await _createPoolFileItem(entity, rootName, rootPath, relative);
        if (item != null) {
          _items[item.relativePath] = item;
          _changeController.add(getAllItems());
        }
      }
    }
  }

  /// Resolves a relative path to an absolute FileSystemEntity on the host.
  FileSystemEntity? resolveEntity(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    for (final root in sharedRoots) {
      final absolute = p.join(root, normalized);
      if (File(absolute).existsSync()) {
        return File(absolute);
      } else if (Directory(absolute).existsSync()) {
        return Directory(absolute);
      }
    }
    return null;
  }

  /// Locates the corresponding root folder path for a given relative path.
  String? getRootForRelativePath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    for (final root in sharedRoots) {
      final absolute = p.join(root, normalized);
      if (File(absolute).existsSync() || Directory(absolute).existsSync()) {
        return root;
      }
    }
    return sharedRoots.isNotEmpty ? sharedRoots.first : null;
  }

  void dispose() {
    _disposeWatchers();
    _changeController.close();
  }
}
