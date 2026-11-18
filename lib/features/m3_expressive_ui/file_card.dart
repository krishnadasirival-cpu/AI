import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/pool_contract.dart';
import '../pool_aggregator/pool_aggregator_provider.dart';
import 'file_actions_dialog.dart';
import 'file_preview_modal.dart';
import 'theme.dart';

class FileCard extends ConsumerStatefulWidget {
  final PoolFileItem item;
  final bool isGrid;

  const FileCard({
    super.key,
    required this.item,
    this.isGrid = true,
  });

  @override
  ConsumerState<FileCard> createState() => _FileCardState();
}

class _FileCardState extends ConsumerState<FileCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        decoration: ExpressiveTheme.tvFocusDecoration(
          isFocused: _isFocused,
          colors: colorScheme,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (item.isDirectory) {
              ref
                  .read(poolAggregatorProvider.notifier)
                  .navigateIntoFolder(item.relativePath);
            } else {
              FilePreviewModal.show(context, item);
            }
          },
          onLongPress: () => FileActionsDialog.show(context, ref, item),
          child: widget.isGrid
              ? _buildGridCard(context, item, colorScheme)
              : _buildListTile(context, item, colorScheme),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, PoolFileItem item, ColorScheme colors) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Preview Section
          Expanded(
            child: Container(
              color: colors.surfaceContainerHighest.withOpacity(0.4),
              child: Stack(
                children: [
                  Center(
                    child: item.isDirectory
                        ? Icon(Icons.folder_rounded, size: 54, color: colors.primary)
                        : item.thumbnailUrl != null
                            ? Image.network(
                                item.thumbnailUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (ctx, err, stack) =>
                                    _buildFallbackIcon(item, colors),
                              )
                            : _buildFallbackIcon(item, colors),
                  ),

                  // Device Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.devices_rounded, size: 12, color: colors.primary),
                          const SizedBox(width: 4),
                          Text(
                            item.deviceName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Three-Dot Menu
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 18),
                      onPressed: () => FileActionsDialog.show(context, ref, item),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // File Info Footer
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.isDirectory ? 'Folder' : _formatBytes(item.sizeBytes),
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    ),
                    Text(
                      _formatDate(item.modifiedAt),
                      style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, PoolFileItem item, ColorScheme colors) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: item.isDirectory
              ? Icon(Icons.folder_rounded, color: colors.primary)
              : _buildFallbackIcon(item, colors),
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${item.deviceName} • ${item.isDirectory ? "Folder" : _formatBytes(item.sizeBytes)} • ${_formatDate(item.modifiedAt)}',
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => FileActionsDialog.show(context, ref, item),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon(PoolFileItem item, ColorScheme colors) {
    final mime = item.mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      return Icon(Icons.image_rounded, color: colors.primary);
    } else if (mime.startsWith('video/')) {
      return const Icon(Icons.movie_rounded, color: Colors.redAccent);
    } else if (mime.startsWith('audio/')) {
      return const Icon(Icons.audiotrack_rounded, color: Colors.purpleAccent);
    } else if (mime.contains('pdf')) {
      return const Icon(Icons.picture_as_pdf_rounded, color: Colors.red);
    } else if (mime.contains('zip') || mime.contains('archive')) {
      return const Icon(Icons.archive_rounded, color: Colors.amber);
    }
    return Icon(Icons.insert_drive_file_rounded, color: colors.onSurfaceVariant);
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

  static String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }
}
