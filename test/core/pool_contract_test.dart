import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import '../../lib/core/pool_contract.dart';

/// Fake implementation of [PoolApiRoutes] to verify interface contract fulfillment.
class FakePoolApiServer implements PoolApiRoutes {
  final DeviceNode node;
  final List<PoolFileItem> items;

  FakePoolApiServer({required this.node, required this.items});

  @override
  Future<DeviceNode> ping() async => node;

  @override
  Future<List<PoolFileItem>> index() async => items;

  @override
  Future<Uint8List> thumb(String path) async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<Stream<List<int>>> stream(String path, {String? range}) async {
    return Stream.value([10, 20, 30]);
  }

  @override
  Future<Stream<List<int>>> downloadFolder(String path) async {
    return Stream.value([100, 200]);
  }

  @override
  Future<Map<String, dynamic>> mutate({
    required String action,
    required String sourcePath,
    String? targetPath,
  }) async {
    return {
      'success': true,
      'action': action,
      'sourcePath': sourcePath,
      'targetPath': targetPath,
    };
  }
}

void main() {
  group('Pool Contract Constants', () {
    test('defaultLanPort is 45454', () {
      expect(defaultLanPort, equals(45454));
    });

    test('poolPinTokenHeader is X-Pool-Pin-Token', () {
      expect(poolPinTokenHeader, equals('X-Pool-Pin-Token'));
    });
  });

  group('PlatformType Enum', () {
    test('contains phone, tv, pc', () {
      expect(PlatformType.values, containsAll([
        PlatformType.phone,
        PlatformType.tv,
        PlatformType.pc,
      ]));
      expect(PlatformType.values.length, equals(3));
    });

    test('toJson produces correct string', () {
      expect(PlatformType.phone.toJson(), equals('phone'));
      expect(PlatformType.tv.toJson(), equals('tv'));
      expect(PlatformType.pc.toJson(), equals('pc'));
    });

    test('fromJson deserializes known types', () {
      expect(PlatformType.fromJson('phone'), equals(PlatformType.phone));
      expect(PlatformType.fromJson('tv'), equals(PlatformType.tv));
      expect(PlatformType.fromJson('pc'), equals(PlatformType.pc));
    });

    test('fromJson handles case insensitivity and whitespace', () {
      expect(PlatformType.fromJson(' TV '), equals(PlatformType.tv));
      expect(PlatformType.fromJson('PHONE'), equals(PlatformType.phone));
      expect(PlatformType.fromJson('Pc'), equals(PlatformType.pc));
    });

    test('fromJson defaults to phone for unknown string', () {
      expect(PlatformType.fromJson('unknown_device'), equals(PlatformType.phone));
      expect(PlatformType.fromJson(''), equals(PlatformType.phone));
    });
  });

  group('DeviceNode Model', () {
    const node = DeviceNode(
      id: 'node-1',
      name: 'Pixel 8 Pro',
      platformType: PlatformType.phone,
      ipAddress: '192.168.1.50',
      port: 45454,
      isOnline: true,
      isLocked: false,
    );

    test('field values are initialized accurately', () {
      expect(node.id, equals('node-1'));
      expect(node.name, equals('Pixel 8 Pro'));
      expect(node.platformType, equals(PlatformType.phone));
      expect(node.ipAddress, equals('192.168.1.50'));
      expect(node.port, equals(45454));
      expect(node.isOnline, isTrue);
      expect(node.isLocked, isFalse);
    });

    test('default parameters apply correctly', () {
      const defaultNode = DeviceNode(
        id: 'node-default',
        name: 'Windows Desktop',
        platformType: PlatformType.pc,
        ipAddress: '192.168.1.100',
      );
      expect(defaultNode.port, equals(defaultLanPort));
      expect(defaultNode.isOnline, isTrue);
      expect(defaultNode.isLocked, isFalse);
    });

    test('toJson serialization produces expected map', () {
      final json = node.toJson();
      expect(json['id'], equals('node-1'));
      expect(json['name'], equals('Pixel 8 Pro'));
      expect(json['platformType'], equals('phone'));
      expect(json['ipAddress'], equals('192.168.1.50'));
      expect(json['port'], equals(45454));
      expect(json['isOnline'], isTrue);
      expect(json['isLocked'], isFalse);
    });

    test('fromJson deserialization reconstructs object faithfully', () {
      final json = {
        'id': 'node-tv',
        'name': 'Sony Bravia TV',
        'platformType': 'tv',
        'ipAddress': '192.168.1.75',
        'port': 45454,
        'isOnline': true,
        'isLocked': true,
      };
      final reconstructed = DeviceNode.fromJson(json);
      expect(reconstructed.id, equals('node-tv'));
      expect(reconstructed.name, equals('Sony Bravia TV'));
      expect(reconstructed.platformType, equals(PlatformType.tv));
      expect(reconstructed.ipAddress, equals('192.168.1.75'));
      expect(reconstructed.port, equals(45454));
      expect(reconstructed.isOnline, isTrue);
      expect(reconstructed.isLocked, isTrue);
    });

    test('fromJson gracefully handles missing fields and numeric conversions', () {
      final partialJson = {
        'id': 'node-partial',
        'name': 'PC Host',
        'ipAddress': '192.168.1.20',
        'port': 45454.0, // test num to int conversion
      };
      final parsed = DeviceNode.fromJson(partialJson);
      expect(parsed.id, equals('node-partial'));
      expect(parsed.name, equals('PC Host'));
      expect(parsed.platformType, equals(PlatformType.phone)); // default
      expect(parsed.ipAddress, equals('192.168.1.20'));
      expect(parsed.port, equals(45454));
      expect(parsed.isOnline, isTrue);
      expect(parsed.isLocked, isFalse);
    });

    test('copyWith creates modified copy without mutating original', () {
      final modified = node.copyWith(
        isLocked: true,
        ipAddress: '192.168.1.99',
      );
      expect(modified.id, equals(node.id));
      expect(modified.name, equals(node.name));
      expect(modified.platformType, equals(node.platformType));
      expect(modified.ipAddress, equals('192.168.1.99'));
      expect(modified.port, equals(node.port));
      expect(modified.isOnline, equals(node.isOnline));
      expect(modified.isLocked, isTrue);

      expect(node.isLocked, isFalse);
      expect(node.ipAddress, equals('192.168.1.50'));
    });

    test('equality and hashCode verify value identity', () {
      final clone = DeviceNode.fromJson(node.toJson());
      expect(clone, equals(node));
      expect(clone.hashCode, equals(node.hashCode));

      final different = node.copyWith(name: 'Changed Name');
      expect(different, isNot(equals(node)));
    });

    test('toString returns readable string description', () {
      expect(node.toString(), contains('DeviceNode'));
      expect(node.toString(), contains('Pixel 8 Pro'));
      expect(node.toString(), contains('192.168.1.50:45454'));
    });
  });

  group('PoolFileItem Model', () {
    final modified = DateTime.utc(2026, 11, 18, 14, 30, 0);
    final fileItem = PoolFileItem(
      id: 'file-123',
      deviceId: 'node-1',
      deviceName: 'Pixel 8 Pro',
      name: 'vacation.mp4',
      relativePath: 'Movies/vacation.mp4',
      syncedRootFolder: 'SharedVideos',
      mimeType: 'video/mp4',
      sizeBytes: 104857600,
      modifiedAt: modified,
      isDirectory: false,
      thumbnailUrl: 'http://192.168.1.50:45454/api/thumb?path=Movies%2Fvacation.mp4',
      streamUrl: 'http://192.168.1.50:45454/api/stream?path=Movies%2Fvacation.mp4',
    );

    test('field values are initialized accurately', () {
      expect(fileItem.id, equals('file-123'));
      expect(fileItem.deviceId, equals('node-1'));
      expect(fileItem.deviceName, equals('Pixel 8 Pro'));
      expect(fileItem.name, equals('vacation.mp4'));
      expect(fileItem.relativePath, equals('Movies/vacation.mp4'));
      expect(fileItem.syncedRootFolder, equals('SharedVideos'));
      expect(fileItem.mimeType, equals('video/mp4'));
      expect(fileItem.sizeBytes, equals(104857600));
      expect(fileItem.modifiedAt, equals(modified));
      expect(fileItem.isDirectory, isFalse);
      expect(fileItem.thumbnailUrl, isNotNull);
      expect(fileItem.streamUrl, isNotNull);
    });

    test('default parameters apply correctly for folders', () {
      final folderItem = PoolFileItem(
        id: 'folder-456',
        deviceId: 'node-1',
        deviceName: 'Pixel 8 Pro',
        name: 'Movies',
        relativePath: 'Movies',
        syncedRootFolder: 'SharedVideos',
        mimeType: 'inode/directory',
        sizeBytes: 0,
        modifiedAt: modified,
        isDirectory: true,
      );
      expect(folderItem.isDirectory, isTrue);
      expect(folderItem.thumbnailUrl, isNull);
      expect(folderItem.streamUrl, isNull);
    });

    test('toJson serialization produces expected map with ISO8601 string', () {
      final json = fileItem.toJson();
      expect(json['id'], equals('file-123'));
      expect(json['deviceId'], equals('node-1'));
      expect(json['deviceName'], equals('Pixel 8 Pro'));
      expect(json['name'], equals('vacation.mp4'));
      expect(json['relativePath'], equals('Movies/vacation.mp4'));
      expect(json['syncedRootFolder'], equals('SharedVideos'));
      expect(json['mimeType'], equals('video/mp4'));
      expect(json['sizeBytes'], equals(104857600));
      expect(json['modifiedAt'], equals(modified.toIso8601String()));
      expect(json['isDirectory'], isFalse);
      expect(json['thumbnailUrl'], contains('/api/thumb'));
      expect(json['streamUrl'], contains('/api/stream'));
    });

    test('fromJson deserialization reconstructs object faithfully', () {
      final json = fileItem.toJson();
      final parsed = PoolFileItem.fromJson(json);
      expect(parsed, equals(fileItem));
      expect(parsed.modifiedAt, equals(modified));
      expect(parsed.sizeBytes, equals(104857600));
    });

    test('fromJson defensively parses missing dates and numbers', () {
      final partialJson = {
        'id': 'file-minimal',
        'deviceId': 'node-1',
        'name': 'notes.txt',
        'sizeBytes': 512.0,
      };
      final item = PoolFileItem.fromJson(partialJson);
      expect(item.id, equals('file-minimal'));
      expect(item.name, equals('notes.txt'));
      expect(item.sizeBytes, equals(512));
      expect(item.mimeType, equals('application/octet-stream'));
      expect(item.modifiedAt, equals(DateTime.fromMillisecondsSinceEpoch(0)));
      expect(item.isDirectory, isFalse);
      expect(item.thumbnailUrl, isNull);
      expect(item.streamUrl, isNull);
    });

    test('fromJson parses numeric epoch timestamp cleanly without throwing TypeError', () {
      const epochMillis = 1700000000000;
      final intJson = {
        'id': 'file-int-epoch',
        'deviceId': 'node-1',
        'deviceName': 'Device 1',
        'name': 'data.bin',
        'modifiedAt': epochMillis,
      };
      final itemInt = PoolFileItem.fromJson(intJson);
      expect(
        itemInt.modifiedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(epochMillis)),
      );

      final doubleJson = {
        'id': 'file-double-epoch',
        'deviceId': 'node-1',
        'deviceName': 'Device 1',
        'name': 'data_double.bin',
        'modifiedAt': 1700000000000.0,
      };
      final itemDouble = PoolFileItem.fromJson(doubleJson);
      expect(
        itemDouble.modifiedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(epochMillis)),
      );

      final malformedBoolJson = {
        'id': 'file-malformed-bool',
        'deviceId': 'node-1',
        'deviceName': 'Device 1',
        'name': 'malformed.bin',
        'modifiedAt': true,
      };
      final itemBool = PoolFileItem.fromJson(malformedBoolJson);
      expect(
        itemBool.modifiedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(0)),
      );

      final malformedStringJson = {
        'id': 'file-malformed-string',
        'deviceId': 'node-1',
        'deviceName': 'Device 1',
        'name': 'invalid_date.bin',
        'modifiedAt': 'not-a-valid-date-string',
      };
      final itemString = PoolFileItem.fromJson(malformedStringJson);
      expect(
        itemString.modifiedAt,
        equals(DateTime.fromMillisecondsSinceEpoch(0)),
      );
    });

    test('copyWith creates modified copy preserving unset fields', () {
      final updated = fileItem.copyWith(
        sizeBytes: 2048,
        name: 'updated.mp4',
      );
      expect(updated.id, equals(fileItem.id));
      expect(updated.name, equals('updated.mp4'));
      expect(updated.sizeBytes, equals(2048));
      expect(updated.mimeType, equals(fileItem.mimeType));
      expect(updated.modifiedAt, equals(fileItem.modifiedAt));
      expect(updated.thumbnailUrl, equals(fileItem.thumbnailUrl));
    });

    test('equality and hashCode verify value identity including deviceName', () {
      final clone = PoolFileItem.fromJson(fileItem.toJson());
      expect(clone, equals(fileItem));
      expect(clone.hashCode, equals(fileItem.hashCode));

      final modifiedItem = fileItem.copyWith(sizeBytes: 999);
      expect(modifiedItem, isNot(equals(fileItem)));

      final differentDeviceItem = fileItem.copyWith(deviceName: 'Living Room TV');
      expect(differentDeviceItem, isNot(equals(fileItem)));
      expect(differentDeviceItem.hashCode, isNot(equals(fileItem.hashCode)));

      final fileSet = {fileItem, differentDeviceItem};
      expect(fileSet.length, equals(2));
      expect(fileSet.contains(fileItem), isTrue);
      expect(fileSet.contains(differentDeviceItem), isTrue);
    });

    test('toString returns formatted debug summary', () {
      expect(fileItem.toString(), contains('PoolFileItem'));
      expect(fileItem.toString(), contains('vacation.mp4'));
      expect(fileItem.toString(), contains('Pixel 8 Pro'));
    });
  });

  group('PoolApiRoutes Route Paths and Interface', () {
    test('static route path constants are accurate', () {
      expect(PoolApiRoutes.pathPing, equals('/api/ping'));
      expect(PoolApiRoutes.pathIndex, equals('/api/index'));
      expect(PoolApiRoutes.pathThumb, equals('/api/thumb'));
      expect(PoolApiRoutes.pathStream, equals('/api/stream'));
      expect(PoolApiRoutes.pathDownloadFolder, equals('/api/download-folder'));
      expect(PoolApiRoutes.pathMutate, equals('/api/mutate'));
    });

    test('FakePoolApiServer implements all PoolApiRoutes contract methods', () async {
      const node = DeviceNode(
        id: 'node-1',
        name: 'Host Node',
        platformType: PlatformType.pc,
        ipAddress: '127.0.0.1',
      );
      final item = PoolFileItem(
        id: 'item-1',
        deviceId: 'node-1',
        deviceName: 'Host Node',
        name: 'sample.txt',
        relativePath: 'sample.txt',
        syncedRootFolder: 'Root',
        mimeType: 'text/plain',
        sizeBytes: 12,
        modifiedAt: DateTime.utc(2026, 1, 1),
      );

      final PoolApiRoutes server = FakePoolApiServer(node: node, items: [item]);

      // Verify ping
      final pingResult = await server.ping();
      expect(pingResult.id, equals('node-1'));
      expect(pingResult.isLocked, isFalse);

      // Verify index
      final indexResult = await server.index();
      expect(indexResult.length, equals(1));
      expect(indexResult.first.name, equals('sample.txt'));

      // Verify thumb
      final thumbBytes = await server.thumb('sample.txt');
      expect(thumbBytes, equals([1, 2, 3]));

      // Verify stream
      final streamObj = await server.stream('sample.txt', range: 'bytes=0-10');
      final streamBytes = await streamObj.first;
      expect(streamBytes, equals([10, 20, 30]));

      // Verify downloadFolder
      final downloadObj = await server.downloadFolder('Root');
      final folderBytes = await downloadObj.first;
      expect(folderBytes, equals([100, 200]));

      // Verify mutate
      final mutateResult = await server.mutate(
        action: 'rename',
        sourcePath: 'sample.txt',
        targetPath: 'sample_renamed.txt',
      );
      expect(mutateResult['success'], isTrue);
      expect(mutateResult['action'], equals('rename'));
      expect(mutateResult['sourcePath'], equals('sample.txt'));
      expect(mutateResult['targetPath'], equals('sample_renamed.txt'));
    });
  });
}
