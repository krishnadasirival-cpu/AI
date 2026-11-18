import 'dart:io';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

class ByteRangeHandler {
  /// Handles HTTP 206 Byte-Range streaming for instant seekable media streaming.
  static Future<Response> handleStreaming(Request request, File file) async {
    if (!await file.exists()) {
      return Response.notFound('File not found');
    }

    final fileSize = await file.length();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final rangeHeader = request.headers['range'];

    if (rangeHeader == null || !rangeHeader.startsWith('bytes=')) {
      // Full file stream with 200 OK
      final stream = file.openRead();
      return Response.ok(
        stream,
        headers: {
          'Content-Type': mimeType,
          'Content-Length': fileSize.toString(),
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'no-cache',
        },
      );
    }

    // Parse Range: bytes=start-end
    final parts = rangeHeader.substring(6).split('-');
    int start = 0;
    int end = fileSize - 1;

    try {
      if (parts[0].isNotEmpty) {
        start = int.parse(parts[0]);
      }
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.parse(parts[1]);
      }
    } catch (_) {
      return Response(
        416,
        body: 'Requested Range Not Satisfiable',
        headers: {'Content-Range': 'bytes */$fileSize'},
      );
    }

    if (start >= fileSize || end >= fileSize || start > end) {
      return Response(
        416,
        body: 'Requested Range Not Satisfiable',
        headers: {'Content-Range': 'bytes */$fileSize'},
      );
    }

    final contentLength = end - start + 1;
    final stream = file.openRead(start, end + 1);

    return Response(
      206,
      body: stream,
      headers: {
        'Content-Type': mimeType,
        'Content-Length': contentLength.toString(),
        'Content-Range': 'bytes $start-$end/$fileSize',
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'no-cache',
      },
    );
  }
}
