import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import '../../core/pool_contract.dart';

class DiscoveredPeer {
  final String id;
  final String name;
  final PlatformType platformType;
  final String ip;
  final int port;
  final DateTime lastSeen;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.platformType,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class PoolDiscoveryService {
  static const String serviceType = '_p2p-pool._tcp';
  static const int udpBroadcastPort = 45455;

  final DeviceNode localNode;
  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _peers = {};

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  Timer? _peerPruneTimer;

  PoolDiscoveryService({required this.localNode});

  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;
  List<DiscoveredPeer> get currentPeers => _peers.values.toList();

  Future<void> start() async {
    await _startMdnsBroadcast();
    await _startMdnsDiscovery();
    await _startUdpFallback();

    // Prune stale peers every 10 seconds
    _peerPruneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      final beforeCount = _peers.length;
      _peers.removeWhere(
        (id, peer) => now.difference(peer.lastSeen).inSeconds > 25,
      );
      if (_peers.length != beforeCount) {
        _peersController.add(currentPeers);
      }
    });
  }

  Future<void> _startMdnsBroadcast() async {
    try {
      final service = BonsoirService(
        name: localNode.name,
        type: serviceType,
        port: defaultLanPort,
        attributes: {
          'id': localNode.id,
          'platform': localNode.platformType.name,
        },
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
    } catch (_) {
      // If mDNS broadcast is blocked or unsupported, UDP fallback guarantees discovery
    }
  }

  Future<void> _startMdnsDiscovery() async {
    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.ready;

      _discovery!.eventStream?.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved &&
            event.service != null) {
          final service = event.service!;
          final id = service.attributes['id'] ?? service.name;
          if (id == localNode.id) return; // Ignore self

          String ip = '';
          if (service is ResolvedBonsoirService) {
            ip = service.host ?? '';
          }
          if (ip.isEmpty) return;

          final platformStr = service.attributes['platform'] ?? 'phone';
          _addOrUpdatePeer(
            DiscoveredPeer(
              id: id,
              name: service.name,
              platformType: PlatformType.fromJson(platformStr),
              ip: ip,
              port: service.port,
              lastSeen: DateTime.now(),
            ),
          );
        }
      });

      await _discovery!.start();
    } catch (_) {}
  }

  Future<void> _startUdpFallback() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBroadcastPort,
        reuseAddress: true,
        reusePort: false,
      );
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram == null) return;

          try {
            final msg = utf8.decode(datagram.data);
            if (msg.startsWith('p2p_pool:')) {
              final payload = jsonDecode(msg.substring(9)) as Map<String, dynamic>;
              final id = payload['id'] as String;
              if (id == localNode.id) return; // Skip self

              final name = payload['name'] as String? ?? 'Peer';
              final platform = payload['platform'] as String? ?? 'phone';
              final port = (payload['port'] as num?)?.toInt() ?? defaultLanPort;
              final senderIp = datagram.address.address;

              _addOrUpdatePeer(
                DiscoveredPeer(
                  id: id,
                  name: name,
                  platformType: PlatformType.fromJson(platform),
                  ip: senderIp,
                  port: port,
                  lastSeen: DateTime.now(),
                ),
              );
            }
          } catch (_) {}
        }
      });

      // Periodically broadcast beacon packet to 255.255.255.255
      _udpBeaconTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _broadcastUdpBeacon();
      });
      _broadcastUdpBeacon();
    } catch (_) {}
  }

  void _broadcastUdpBeacon() {
    if (_udpSocket == null) return;
    try {
      final data = jsonEncode({
        'id': localNode.id,
        'name': localNode.name,
        'platform': localNode.platformType.name,
        'port': defaultLanPort,
      });
      final bytes = utf8.encode('p2p_pool:$data');
      _udpSocket!.send(bytes, InternetAddress('255.255.255.255'), udpBroadcastPort);
    } catch (_) {}
  }

  void _addOrUpdatePeer(DiscoveredPeer peer) {
    _peers[peer.id] = peer;
    _peersController.add(currentPeers);
  }

  Future<void> stop() async {
    _peerPruneTimer?.cancel();
    _udpBeaconTimer?.cancel();
    _udpSocket?.close();
    await _discovery?.stop();
    await _broadcast?.stop();
    _peersController.close();
  }
}
