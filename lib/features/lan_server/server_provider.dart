import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/pool_contract.dart';
import '../native_onboarding/onboarding_constants.dart';
import 'lan_server.dart';
import 'pool_indexer.dart';

class ServerState {
  final bool isRunning;
  final bool isLocked;
  final DeviceNode localNode;
  final int indexedItemCount;
  final String? error;

  const ServerState({
    required this.isRunning,
    required this.isLocked,
    required this.localNode,
    this.indexedItemCount = 0,
    this.error,
  });

  ServerState copyWith({
    bool? isRunning,
    bool? isLocked,
    DeviceNode? localNode,
    int? indexedItemCount,
    String? error,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      isLocked: isLocked ?? this.isLocked,
      localNode: localNode ?? this.localNode,
      indexedItemCount: indexedItemCount ?? this.indexedItemCount,
      error: error,
    );
  }
}

class ServerController extends StateNotifier<ServerState> {
  LanServer? _lanServer;

  ServerController()
      : super(
          ServerState(
            isRunning: false,
            isLocked: false,
            localNode: DeviceNode(
              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
              name: Platform.localHostname.isEmpty ? 'Local Device' : Platform.localHostname,
              platformType: _detectPlatformType(),
              ipAddress: '127.0.0.1',
              port: defaultLanPort,
            ),
          ),
        );

  static PlatformType _detectPlatformType() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return PlatformType.pc;
    }
    // Android TV check or phone
    return PlatformType.phone;
  }

  Future<void> startServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString(OnboardingKeys.keyPairingPin) ?? OnboardingKeys.defaultPin;
      final sharedFolders = prefs.getStringList(OnboardingKeys.keySharedFolders) ?? [];

      final hostIp = await _findPrimaryLocalIp();
      final node = state.localNode.copyWith(ipAddress: hostIp);

      final indexer = PoolIndexer(
        deviceId: node.id,
        deviceName: node.name,
        hostIp: hostIp,
        port: defaultLanPort,
        sharedRoots: sharedFolders,
      );

      _lanServer = LanServer(
        localNode: node,
        indexer: indexer,
        pairingPin: pin,
        port: defaultLanPort,
      );

      await _lanServer!.start();

      indexer.onChange.listen((items) {
        state = state.copyWith(indexedItemCount: items.length);
      });

      state = state.copyWith(
        isRunning: true,
        localNode: node,
        indexedItemCount: indexer.getAllItems().length,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to start server: $e');
    }
  }

  void toggleLock() {
    if (_lanServer != null) {
      final newLock = !_lanServer!.isLocked;
      _lanServer!.setLocked(newLock);
      state = state.copyWith(
        isLocked: newLock,
        localNode: state.localNode.copyWith(isLocked: newLock),
      );
    }
  }

  Future<void> stopServer() async {
    await _lanServer?.stop();
    _lanServer = null;
    state = state.copyWith(isRunning: false);
  }

  static Future<String> _findPrimaryLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  @override
  void dispose() {
    _lanServer?.stop();
    super.dispose();
  }
}

final serverControllerProvider =
    StateNotifierProvider<ServerController, ServerState>((ref) {
  return ServerController();
});
