import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/pool_contract.dart';
import '../pool_aggregator/pool_aggregator_provider.dart';

class FileActionsDialog {
  static void show(BuildContext context, WidgetRef ref, PoolFileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  item.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${item.deviceName} • ${item.syncedRootFolder}'),
              ),
              const Divider(color: Colors.white12),

              // Action 1: Download to Device
              if (!item.isDirectory)
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download to Device'),
                  subtitle: const Text('Saves permanently to your Downloads folder'),
                  onTap: () async {
                    Navigator.pop(ctx);
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
                            path != null
                                ? 'Saved to $path'
                                : 'Download failed',
                          ),
                        ),
                      );
                    }
                  },
                ),

              // Action 2: Download Whole Folder (for directories)
              if (item.isDirectory)
                ListTile(
                  leading: const Icon(Icons.folder_zip_rounded),
                  title: const Text('Download Whole Folder (ZIP)'),
                  subtitle: const Text('Streams complete folder as a compressed ZIP'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Compressing & downloading ${item.name}...')),
                    );
                    final path = await ref
                        .read(poolAggregatorProvider.notifier)
                        .downloadFolderToDevice(item);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            path != null
                                ? 'Folder saved to $path'
                                : 'Folder download failed',
                          ),
                        ),
                      );
                    }
                  },
                ),

              // Action 3: Rename
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, ref, item);
                },
              ),

              // Action 4: Move
              ListTile(
                leading: const Icon(Icons.drive_file_move_rounded),
                title: const Text('Move'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showMoveDialog(context, ref, item);
                },
              ),

              // Action 5: Soft-Delete to .pool_trash
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: const Text('Safely moves item to .pool_trash'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(context, ref, item);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static void _showRenameDialog(BuildContext context, WidgetRef ref, PoolFileItem item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != item.name) {
                Navigator.pop(ctx);
                final ok = await ref
                    .read(poolAggregatorProvider.notifier)
                    .mutateFile(item: item, action: 'rename', targetPath: newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Renamed successfully' : 'Rename failed (verify PIN)')),
                  );
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  static void _showMoveDialog(BuildContext context, WidgetRef ref, PoolFileItem item) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Target Folder Path',
            hintText: 'e.g. Subfolder or . for root',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final target = controller.text.trim();
              Navigator.pop(ctx);
              final ok = await ref
                  .read(poolAggregatorProvider.notifier)
                  .mutateFile(item: item, action: 'move', targetPath: target);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Moved successfully' : 'Move failed (verify PIN)')),
                );
              }
            },
            child: const Text('Move'),
          ),
        ],
      ),
    );
  }

  static void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref, PoolFileItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to .pool_trash?'),
        content: Text(
          'Are you sure you want to delete "${item.name}" from ${item.deviceName}? '
          'It will be safely relocated to the hidden .pool_trash folder.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(poolAggregatorProvider.notifier)
                  .mutateFile(item: item, action: 'delete');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Moved to .pool_trash' : 'Delete failed (verify PIN)',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
