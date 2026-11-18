import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/pool_contract.dart';

class PoolClient {
  final http.Client _client = http.Client();

  /// Queries GET /api/ping from a remote host to check online and lock state.
  Future<DeviceNode?> ping(String host, int port) async {
    try {
      final url = Uri.parse('http://$host:$port${PoolApiRoutes.pathPing}');
      final response = await _client.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return DeviceNode.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Queries GET /api/index to retrieve all shared files from a remote host.
  Future<List<PoolFileItem>> fetchIndex(String host, int port) async {
    try {
      final url = Uri.parse('http://$host:$port${PoolApiRoutes.pathIndex}');
      final response = await _client.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((item) => PoolFileItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Downloads thumbnail bytes from GET /api/thumb?path=...
  Future<Uint8List?> fetchThumbnail(String thumbnailUrl) async {
    try {
      final response = await _client.get(Uri.parse(thumbnailUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads a folder archive from GET /api/download-folder?path=...
  Future<Uint8List?> downloadFolderArchive(String downloadUrl) async {
    try {
      final response = await _client.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Sends a POST /api/mutate action (rename, move, delete) with X-Pool-Pin-Token.
  Future<Map<String, dynamic>> mutate({
    required String host,
    required int port,
    required String pinToken,
    required String action,
    required String sourcePath,
    String? targetPath,
  }) async {
    final url = Uri.parse('http://$host:$port${PoolApiRoutes.pathMutate}');
    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              poolPinTokenHeader: pinToken,
            },
            body: jsonEncode({
              'action': action,
              'sourcePath': sourcePath,
              'targetPath': targetPath,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body) as Map<String, dynamic>?;
        return {
          'success': false,
          'error': err?['error'] ?? 'HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void close() {
    _client.close();
  }
}
