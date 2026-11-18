import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/pool_contract.dart';
import '../lan_server/server_provider.dart';
import 'pool_client.dart';
import 'pool_discovery_service.dart';
import 'pool_filter_state.dart';
import 'temp_cache_manager.dart';

class PoolAggregatorState {
  final bool isLoading;
  final List<DeviceNode> nodes;
  final List<PoolFileItem> allFiles;
  final PoolFilterState filter;
  final Map<String, String> peerPins; // Saved PINs for paired devices
  final String? statusMessage;

  const PoolAggregatorState({
    this.isLoading = false,
    this.nodes = const [],
    this.allFiles = const [],
    this.filter = const PoolFilterState(),
    this.peerPins = const {},
    this.statusMessage,
  });

  PoolAggregatorState copyWith({
    bool? isLoading,
    List<DeviceNode>? nodes,
    List<PoolFileItem>? allFiles,
    PoolFilterState? filter,
    Map<String, String>? peerPins,
    String? statusMessage,
  }) {
    return PoolAggregatorState(
      isLoading: isLoading ?? this.isLoading,
      nodes: nodes ?? this.nodes,
      allFiles: allFiles ?? this.allFiles,
      filter: filter ?? this.filter,
      peerPins: peerPins ?? this.peerPins,
      statusMessage: statusMessage,
    );
  }

  /// Returns files matching current device filter, category, search query, and folder hierarchy.
  List<PoolFileItem> get filteredFiles {
    return allFiles.where((item) {
      // 1. Device filter (null = Unified Pool)
      if (filter.selectedDeviceId != null && item.deviceId != filter.selectedDeviceId) {
        return false;
      }

      // 2. Search query filter
      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        if (!item.name.toLowerCase().contains(query)) {
          return false;
        }
      }

      // 3. Category filter
      if (filter.category != FileCategory.all) {
        if (item.isDirectory) {
          if (filter.category != FileCategory.folders) return false;
        } else {
          final mime = item.mimeType.toLowerCase();
          switch (filter.category) {
            case FileCategory.images:
              if (!mime.startsWith('image/')) return false;
              break;
            case FileCategory.videos:
              if (!mime.startsWith('video/')) return false;
              break;
            case FileCategory.audio:
              if (!mime.startsWith('audio/')) return false;
              break;
            case FileCategory.documents:
              if (!mime.startsWith('text/') && !mime.contains('pdf') && !mime.contains('word') && !mime.contains('document')) {
                return false;
              }
              break;
            case FileCategory.archives:
              if (!mime.contains('zip') && !mime.contains('tar') && !mime.contains('compressed') && !mime.contains('archive')) {
                return false;
              }
              break;
            case FileCategory.folders:
              if (!item.isDirectory) return false;
              break;
            case FileCategory.all:
              break;
          }
        }
      }

      // 4. Folder drill-down filter (if navigating subdirectories)
      if (filter.currentFolder != null && filter.currentFolder!.isNotEmpty) {
        final parent = p.dirname(item.relativePath).replaceAll('\\', '/');
        final current = filter.currentFolder!.replaceAll('\\', '/');
        if (parent != current && parent != '.') {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

class PoolAggregatorController extends StateNotifier<PoolAggregatorState> {
  final Ref ref;
  final PoolClient _client = PoolClient();
  PoolDiscoveryService? _discovery;
  Timer? _syncTimer;

  PoolAggregatorController(this.ref) : super(const PoolAggregatorState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    // Ensure local server is started
    await ref.read(serverControllerProvider.notifier).startServer();
    final localServerState = ref.read(serverControllerProvider);

    // Initialize discovery
    _discovery = PoolDiscoveryService(localNode: localServerState.localNode);
    await _discovery!.start();

    _discovery!.peersStream.listen((peers) {
      _onPeersDiscovered(peers);
    });

    // Sync loop: query index and ping concurrently every 6 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      syncAllNodes();
    });

    await syncAllNodes();
    state = state.copyWith(isLoading: false);
  }

  void _onPeersDiscovered(List<DiscoveredPeer> peers) {
    syncAllNodes();
  }

  Future<void> syncAllNodes() async {
    final localServerState = ref.read(serverControllerProvider);
    final localNode = localServerState.localNode;
    final List<DeviceNode> updatedNodes = [localNode];
    final List<PoolFileItem> aggregatedFiles = [];

    // 1. Fetch local files from local server
    final localFiles = await _client.fetchIndex('127.0.0.1', localNode.port);
    aggregatedFiles.addAll(localFiles);

    // 2. Concurrently fetch ping and index from all discovered remote peers
    final peers = _discovery?.currentPeers ?? [];
    final futures = peers.map((peer) async {
      try {
        final node = await _client.ping(peer.ip, peer.port);
        if (node != null) {
          updatedNodes.add(node);
          final peerFiles = await _client.fetchIndex(peer.ip, peer.port);
          aggregatedFiles.addAll(peerFiles);
        }
      } catch (_) {}
    });

    await Future.wait(futures);

    state = state.copyWith(
      nodes: updatedNodes,
      allFiles: aggregatedFiles,
      statusMessage: 'Synced ${updatedNodes.length} devices, ${aggregatedFiles.length} files',
    );
  }

  // Filter modifiers
  void selectDevice(String? deviceId) {
    if (state.filter.selectedDeviceId == deviceId) {
      // Toggle back to Unified Pool
      state = state.copyWith(filter: state.filter.copyWith(clearDevice: true));
    } else {
      state = state.copyWith(filter: state.filter.copyWith(selectedDeviceId: deviceId));
    }
  }

  void setCategory(FileCategory category) {
    state = state.copyWith(filter: state.filter.copyWith(category: category));
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query));
  }

  void toggleViewMode() {
    state = state.copyWith(
      filter: state.filter.copyWith(isGridView: !state.filter.isGridView),
    );
  }

  void navigateIntoFolder(String folderPath) {
    state = state.copyWith(filter: state.filter.copyWith(currentFolder: folderPath));
  }

  void navigateUp() {
    if (state.filter.currentFolder == null) return;
    final parent = p.dirname(state.filter.currentFolder!);
    if (parent == '.' || parent.isEmpty) {
      state = state.copyWith(filter: state.filter.copyWith(clearFolder: true));
    } else {
      state = state.copyWith(filter: state.filter.copyWith(currentFolder: parent));
    }
  }

  void setDevicePin(String deviceId, String pin) {
    final pins = Map<String, String>.from(state.peerPins);
    pins[deviceId] = pin;
    state = state.copyWith(peerPins: pins);
  }

  /// Downloads a file permanently to the user's storage.
  Future<String?> downloadFileToDevice(PoolFileItem item) async {
    if (item.streamUrl == null) return null;
    try {
      final uri = Uri.parse(item.streamUrl!);
      final bytes = await _client.fetchThumbnail(uri.toString());
      if (bytes != null) {
        final path = await TempCacheManager.saveToPermanentStorage(bytes, item.name);
        return path;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads and extracts or saves an entire remote directory archive.
  Future<String?> downloadFolderToDevice(PoolFileItem item) async {
    final node = state.nodes.firstWhere(
      (n) => n.id == item.deviceId,
      orElse: () => state.nodes.first,
    );
    final url = 'http://${node.ipAddress}:${node.port}${PoolApiRoutes.pathDownloadFolder}?path=${Uri.encodeComponent(item.relativePath)}';
    final zipBytes = await _client.downloadFolderArchive(url);
    if (zipBytes != null) {
      return await TempCacheManager.saveToPermanentStorage(zipBytes, '${item.name}.zip');
    }
    return null;
  }

  /// Executes remote mutation (rename, move, soft-delete) with security PIN token.
  Future<bool> mutateFile({
    required PoolFileItem item,
    required String action,
    String? targetPath,
  }) async {
    final node = state.nodes.firstWhere(
      (n) => n.id == item.deviceId,
      orElse: () => state.nodes.first,
    );
    final pin = state.peerPins[item.deviceId] ?? '123456';

    final res = await _client.mutate(
      host: node.ipAddress,
      port: node.port,
      pinToken: pin,
      action: action,
      sourcePath: item.relativePath,
      targetPath: targetPath,
    );

    if (res['success'] == true) {
      await syncAllNodes();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _discovery?.stop();
    _client.close();
    super.dispose();
  }
}

final poolAggregatorProvider =
    StateNotifierProvider<PoolAggregatorController, PoolAggregatorState>((ref) {
  return PoolAggregatorController(ref);
});
