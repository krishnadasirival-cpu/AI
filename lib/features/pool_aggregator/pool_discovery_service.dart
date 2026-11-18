import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static const int udpBroadcastPort = 45455;

  final DeviceNode localNode;
  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _peers = {};

  RawDatagramSocket? _udpSocket;
  Timer? _udpBeaconTimer;
  Timer? _subnetSweepTimer;
  Timer? _peerPruneTimer;

  PoolDiscoveryService({required this.localNode});

  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;
  List<DiscoveredPeer> get currentPeers => _peers.values.toList();

  Future<void> start() async {
    await _startUdpDiscovery();
    _startPeriodicSubnetSweep();

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

  Future<void> _startUdpDiscovery() async {
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

  void _startPeriodicSubnetSweep() {
    // Run an initial sweep and repeat every 30 seconds
    sweepSubnet();
    _subnetSweepTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sweepSubnet();
    });
  }

  Future<void> sweepSubnet() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';

          // Concurrently ping /24 hosts on defaultLanPort (45454)
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 400);
          final futures = <Future<void>>[];

          for (int i = 1; i < 255; i++) {
            final targetIp = '$subnetPrefix.$i';
            if (targetIp == addr.address) continue; // Skip self IP

            futures.add(() async {
              try {
                final req = await client.getUrl(
                  Uri.parse('http://$targetIp:$defaultLanPort${PoolApiRoutes.ping}'),
                );
                final res = await req.close();
                if (res.statusCode == 200) {
                  final bodyStr = await res.transform(utf8.decoder).join();
                  final json = jsonDecode(bodyStr) as Map<String, dynamic>;
                  final node = DeviceNode.fromJson(json);
                  if (node.id != localNode.id) {
                    _addOrUpdatePeer(
                      DiscoveredPeer(
                        id: node.id,
                        name: node.name,
                        platformType: node.platformType,
                        ip: targetIp,
                        port: node.port,
                        lastSeen: DateTime.now(),
                      ),
                    );
                  }
                }
              } catch (_) {}
            }());

            if (futures.length >= 40) {
              await Future.wait(futures);
              futures.clear();
            }
          }

          if (futures.isNotEmpty) {
            await Future.wait(futures);
          }
          client.close();
        }
      }
    } catch (_) {}
  }

  void _addOrUpdatePeer(DiscoveredPeer peer) {
    _peers[peer.id] = peer;
    _peersController.add(currentPeers);
  }

  Future<void> stop() async {
    _peerPruneTimer?.cancel();
    _udpBeaconTimer?.cancel();
    _subnetSweepTimer?.cancel();
    _udpSocket?.close();
    _peersController.close();
  }
}
