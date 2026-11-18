import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../../core/pool_contract.dart';
import 'byte_range_handler.dart';
import 'folder_archiver.dart';
import 'pool_indexer.dart';
import 'thumbnail_generator.dart';

class LanServer {
  final DeviceNode localNode;
  final PoolIndexer indexer;
  final String pairingPin;
  final int port;

  HttpServer? _server;
  bool _isLocked = false;

  LanServer({
    required this.localNode,
    required this.indexer,
    required this.pairingPin,
    this.port = defaultLanPort,
  });

  bool get isRunning => _server != null;
  bool get isLocked => _isLocked;

  void setLocked(bool locked) {
    _isLocked = locked;
  }

  /// Starts the Shelf HTTP server on 0.0.0.0:45454.
  Future<void> start() async {
    if (_server != null) return;

    await indexer.start();

    final router = Router();

    // GET /api/ping
    router.get(PoolApiRoutes.pathPing, (Request request) {
      final currentNode = localNode.copyWith(
        isOnline: true,
        isLocked: _isLocked,
        port: port,
      );
      return Response.ok(
        jsonEncode(currentNode.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // GET /api/index
    router.get(PoolApiRoutes.pathIndex, (Request request) {
      final items = indexer.getAllItems().map((item) => item.toJson()).toList();
      return Response.ok(
        jsonEncode(items),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    });

    // GET /api/thumb?path=<encoded_path>
    router.get(PoolApiRoutes.pathThumb, (Request request) async {
      final rawPath = request.url.queryParameters['path'];
      if (rawPath == null || rawPath.isEmpty) {
        return Response.badRequest(body: 'Missing path parameter');
      }

      final entity = indexer.resolveEntity(rawPath);
      if (entity is! File || !entity.existsSync()) {
        return Response.notFound('File not found for thumbnail');
      }

      final thumbBytes = await ThumbnailGenerator.getThumbnail(entity);
      return Response.ok(
        thumbBytes,
        headers: {
          'Content-Type': 'image/webp',
          'Cache-Control': 'public, max-age=86400',
          'Access-Control-Allow-Origin': '*',
        },
      );
    });

    // GET /api/stream?path=<encoded_path>
    router.get(PoolApiRoutes.pathStream, (Request request) async {
      final rawPath = request.url.queryParameters['path'];
      if (rawPath == null || rawPath.isEmpty) {
        return Response.badRequest(body: 'Missing path parameter');
      }

      final entity = indexer.resolveEntity(rawPath);
      if (entity is! File || !entity.existsSync()) {
        return Response.notFound('File not found for streaming');
      }

      return await ByteRangeHandler.handleStreaming(request, entity);
    });

    // GET /api/download-folder?path=<encoded_path>
    router.get(PoolApiRoutes.pathDownloadFolder, (Request request) async {
      final rawPath = request.url.queryParameters['path'];
      if (rawPath == null || rawPath.isEmpty) {
        return Response.badRequest(body: 'Missing path parameter');
      }

      final entity = indexer.resolveEntity(rawPath);
      if (entity is! Directory || !entity.existsSync()) {
        return Response.notFound('Directory not found for download');
      }

      final zipBytes = await FolderArchiver.zipFolder(entity);
      final folderName = p.basename(entity.path);

      return Response.ok(
        zipBytes,
        headers: {
          'Content-Type': 'application/zip',
          'Content-Disposition': 'attachment; filename="$folderName.zip"',
          'Content-Length': zipBytes.length.toString(),
          'Access-Control-Allow-Origin': '*',
        },
      );
    });

    // POST /api/mutate
    router.post(PoolApiRoutes.pathMutate, (Request request) async {
      // Security PIN Token Verification
      final token = request.headers[poolPinTokenHeader.toLowerCase()] ??
          request.headers[poolPinTokenHeader];

      if (token == null || token.trim() != pairingPin.trim()) {
        return Response(
          401,
          body: jsonEncode({
            'error': 'Unauthorized: Invalid or missing X-Pool-Pin-Token header'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final payload = await request.readAsString();
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        return Response.badRequest(body: 'Invalid JSON body');
      }

      final action = data['action'] as String?;
      final sourcePath = data['sourcePath'] as String?;
      final targetPath = data['targetPath'] as String?;

      if (action == null || sourcePath == null) {
        return Response.badRequest(body: 'Action and sourcePath required');
      }

      final sourceEntity = indexer.resolveEntity(sourcePath);
      if (sourceEntity == null || !sourceEntity.existsSync()) {
        return Response.notFound('Source entity not found');
      }

      try {
        if (action == 'rename') {
          if (targetPath == null || targetPath.isEmpty) {
            return Response.badRequest(body: 'targetPath required for rename');
          }
          final parent = sourceEntity.parent.path;
          final newPath = p.join(parent, targetPath);
          await sourceEntity.rename(newPath);
          await indexer.rescanAll();
          return Response.ok(
            jsonEncode({'success': true, 'action': 'rename', 'newPath': newPath}),
            headers: {'Content-Type': 'application/json'},
          );
        } else if (action == 'move') {
          if (targetPath == null || targetPath.isEmpty) {
            return Response.badRequest(body: 'targetPath required for move');
          }
          final root = indexer.getRootForRelativePath(sourcePath);
          if (root == null) {
            return Response.notFound('Root not resolved for source');
          }
          final destination = p.join(root, targetPath, p.basename(sourceEntity.path));
          await sourceEntity.rename(destination);
          await indexer.rescanAll();
          return Response.ok(
            jsonEncode({'success': true, 'action': 'move', 'newPath': destination}),
            headers: {'Content-Type': 'application/json'},
          );
        } else if (action == 'delete') {
          // Soft-delete to .pool_trash directory
          final root = indexer.getRootForRelativePath(sourcePath);
          if (root == null) {
            return Response.notFound('Root not found for delete target');
          }

          final trashDir = Directory(p.join(root, '.pool_trash'));
          if (!await trashDir.exists()) {
            await trashDir.create(recursive: true);
          }

          final stamp = DateTime.now().millisecondsSinceEpoch;
          final trashTarget = p.join(
            trashDir.path,
            '${stamp}_${p.basename(sourceEntity.path)}',
          );

          await sourceEntity.rename(trashTarget);
          await indexer.rescanAll();

          return Response.ok(
            jsonEncode({
              'success': true,
              'action': 'delete',
              'softDeletedTo': trashTarget,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } else {
          return Response.badRequest(body: 'Unsupported action: $action');
        }
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Mutation failed: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    indexer.dispose();
  }
}
