import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lan_server/server_provider.dart';
import '../native_onboarding/onboarding_screen.dart';
import '../pool_aggregator/pool_aggregator_provider.dart';
import 'device_filter_bar.dart';
import 'file_card.dart';

class MainPoolScreen extends ConsumerWidget {
  const MainPoolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolState = ref.watch(poolAggregatorProvider);
    final poolController = ref.read(poolAggregatorProvider.notifier);
    final serverState = ref.watch(serverControllerProvider);
    final serverController = ref.read(serverControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final files = poolState.filteredFiles;
    final isGrid = poolState.filter.isGridView;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.hub_rounded, size: 20, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'Virtual File Pool',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Live Host Lock Toggle Button
          IconButton(
            tooltip: serverState.isLocked ? 'Host is Locked' : 'Host is Unlocked',
            icon: Icon(
              serverState.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: serverState.isLocked ? Colors.amber : Colors.greenAccent,
            ),
            onPressed: serverController.toggleLock,
          ),

          // View Mode (Grid / List) Toggle
          IconButton(
            tooltip: isGrid ? 'Switch to List' : 'Switch to Grid',
            icon: Icon(isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: poolController.toggleViewMode,
          ),

          // Setup / Shared Folders Onboarding
          IconButton(
            tooltip: 'Folder Sharing Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => OnboardingScreen(
                    onSetupCompleted: () {
                      Navigator.pop(ctx);
                      serverController.startServer();
                      poolController.syncAllNodes();
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: poolController.syncAllNodes,
          child: CustomScrollView(
            slivers: [
              // Top filter bar (Search + Animated Device Chips + Category Pills)
              const SliverToBoxAdapter(
                child: DeviceFilterBar(),
              ),

              // Folder Hierarchy Breadcrumbs (if navigating subdirectories)
              if (poolState.filter.currentFolder != null)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: poolController.navigateUp,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.folder_open_rounded, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            poolState.filter.currentFolder!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Empty State or File Listing
              if (files.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No files found in the current pool view',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          poolState.nodes.length <= 1
                              ? 'Waiting for other LAN peers running on port 45454...'
                              : 'Try changing category or clear search filters',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: poolController.syncAllNodes,
                          child: const Text('Rescan LAN Pool'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isGrid)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => FileCard(item: files[index], isGrid: true),
                      childCount: files.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => FileCard(item: files[index], isGrid: false),
                      childCount: files.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
