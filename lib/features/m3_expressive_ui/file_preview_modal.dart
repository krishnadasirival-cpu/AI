import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/pool_contract.dart';
import '../pool_aggregator/pool_aggregator_provider.dart';
import '../pool_aggregator/temp_cache_manager.dart';

class FilePreviewModal extends ConsumerStatefulWidget {
  final PoolFileItem item;

  const FilePreviewModal({super.key, required this.item});

  static Future<void> show(BuildContext context, PoolFileItem item) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => FilePreviewModal(item: item),
    );

    // Module 3 requirement: Purge preview cache upon closing the modal
    await TempCacheManager.purgePreviewedFiles();
  }

  @override
  ConsumerState<FilePreviewModal> createState() => _FilePreviewModalState();
}

class _FilePreviewModalState extends ConsumerState<FilePreviewModal> {
  bool _isLoading = true;
  String? _textContent;
  double _playbackPosition = 0.0;
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final mime = widget.item.mimeType.toLowerCase();
    if (mime.startsWith('text/') || mime.contains('json') || mime.contains('yaml')) {
      try {
        if (widget.item.streamUrl != null) {
          final res = await http.get(Uri.parse(widget.item.streamUrl!));
          if (res.statusCode == 200) {
            setState(() {
              _textContent = utf8.decode(res.bodyBytes, allowMalformed: true);
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to load text preview: $e';
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog.fullscreen(
      backgroundColor: Colors.black.withOpacity(0.92),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.black45,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontSize: 16, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${item.deviceName} • ${_formatBytes(item.sizeBytes)} • ${item.mimeType}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
              ),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading ${item.name}...')),
                );
                final path = await ref
                    .read(poolAggregatorProvider.notifier)
                    .downloadFileToDevice(item);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        path != null ? 'Permanently saved to $path' : 'Download failed',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Save to Device'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.redAccent))
                  : _buildViewer(context),
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    final mime = widget.item.mimeType.toLowerCase();

    // 1. Image Viewer (with Pan & Zoom)
    if (mime.startsWith('image/')) {
      if (widget.item.streamUrl != null) {
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            widget.item.streamUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (ctx, err, stack) {
              return const Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38);
            },
          ),
        );
      }
    }

    // 2. Video & Audio Player View with scrubbing bar
    if (mime.startsWith('video/') || mime.startsWith('audio/')) {
      return Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                mime.startsWith('video/') ? Icons.videocam_rounded : Icons.music_note_rounded,
                size: 60,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.item.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'HTTP 206 Byte-Range Media Stream',
              style: TextStyle(fontSize: 12, color: Colors.cyanAccent.shade200),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _playbackPosition,
              max: 100.0,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                setState(() => _playbackPosition = val);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _playbackPosition = (_playbackPosition - 10).clamp(0.0, 100.0);
                    });
                  },
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  iconSize: 48,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: () {
                    setState(() => _isPlaying = !_isPlaying);
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _playbackPosition = (_playbackPosition + 10).clamp(0.0, 100.0);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Text & Code Preview
    if (_textContent != null) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _textContent!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Color(0xFFD4D4D4),
            ),
          ),
        ),
      );
    }

    // 4. Generic File Fallback
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file_rounded, size: 80, color: Colors.white38),
        const SizedBox(height: 16),
        Text(
          widget.item.name,
          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Preview not supported for ${widget.item.mimeType}',
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
