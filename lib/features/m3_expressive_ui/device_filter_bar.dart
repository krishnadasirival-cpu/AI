import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/pool_contract.dart';
import '../pool_aggregator/pool_aggregator_provider.dart';
import '../pool_aggregator/pool_filter_state.dart';

class DeviceFilterBar extends ConsumerWidget {
  const DeviceFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(poolAggregatorProvider);
    final controller = ref.read(poolAggregatorProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SearchBar(
            hintText: 'Search pool files across devices...',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (state.filter.searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => controller.setSearchQuery(''),
                ),
            ],
            onChanged: controller.setSearchQuery,
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(
              colorScheme.surfaceContainerHighest.withOpacity(0.6),
            ),
          ),
        ),

        // 2. Horizontal Animated Device Filter Chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Unified Pool Chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: state.filter.selectedDeviceId == null,
                  avatar: Icon(
                    Icons.all_inclusive_rounded,
                    size: 18,
                    color: state.filter.selectedDeviceId == null
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text('Unified Pool (${state.allFiles.length})'),
                  onSelected: (_) => controller.selectDevice(null),
                ),
              ),

              // Individual Device Chips
              ...state.nodes.map((node) {
                final isSelected = state.filter.selectedDeviceId == node.id;
                final isLocked = node.isLocked;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Icon(
                      _iconForPlatform(node.platformType),
                      size: 18,
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(node.name),
                        const SizedBox(width: 6),
                        // Live Lock Status Indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLocked ? Colors.amber : Colors.greenAccent,
                          ),
                        ),
                        if (isLocked) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _showPinEntryDialog(context, ref, node),
                            child: const Icon(Icons.lock_rounded, size: 14, color: Colors.amber),
                          ),
                        ],
                      ],
                    ),
                    onSelected: (_) => controller.selectDevice(node.id),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 3. Category Filter Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: FileCategory.values.length,
            itemBuilder: (context, index) {
              final cat = FileCategory.values[index];
              final isCatSelected = state.filter.category == cat;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCatSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isCatSelected,
                  onSelected: (_) => controller.setCategory(cat),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static IconData _iconForPlatform(PlatformType type) {
    switch (type) {
      case PlatformType.phone:
        return Icons.phone_android_rounded;
      case PlatformType.tv:
        return Icons.tv_rounded;
      case PlatformType.pc:
        return Icons.laptop_chromebook_rounded;
    }
  }

  static void _showPinEntryDialog(BuildContext context, WidgetRef ref, DeviceNode node) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pair with ${node.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the 6-digit pairing PIN shown on the host device:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(letterSpacing: 6, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '123456',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (pinController.text.trim().isNotEmpty) {
                ref
                    .read(poolAggregatorProvider.notifier)
                    .setDevicePin(node.id, pinController.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PIN saved for ${node.name}')),
                );
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }
}
