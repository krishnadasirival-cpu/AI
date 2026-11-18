import 'dart:typed_data';

/// Default LAN TCP port used by the P2P file pool server.
const int defaultLanPort = 45454;

/// HTTP Header key used for PIN authorization between peer nodes.
const String poolPinTokenHeader = 'X-Pool-Pin-Token';

/// Platform category indicating form factor and UI profile.
enum PlatformType {
  phone,
  tv,
  pc;

  /// Serializes the enum to lowercase string representation.
  String toJson() => name;

  /// Deserializes a string value to [PlatformType], defaulting to [phone].
  static PlatformType fromJson(String value) {
    return PlatformType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => PlatformType.phone,
    );
  }
}

/// Represents an individual device participating in the local file pool.
class DeviceNode {
  final String id;
  final String name;
  final PlatformType platformType;
  final String ipAddress;
  final int port;
  final bool isOnline;
  final bool isLocked;

  const DeviceNode({
    required this.id,
    required this.name,
    required this.platformType,
    required this.ipAddress,
    this.port = defaultLanPort,
    this.isOnline = true,
    this.isLocked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platformType': platformType.name,
    'ipAddress': ipAddress,
    'port': port,
    'isOnline': isOnline,
    'isLocked': isLocked,
  };

  factory DeviceNode.fromJson(Map<String, dynamic> json) {
    return DeviceNode(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platformType: PlatformType.fromJson(json['platformType'] as String? ?? ''),
      ipAddress: json['ipAddress'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? defaultLanPort,
      isOnline: json['isOnline'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
    );
  }

  DeviceNode copyWith({
    String? id,
    String? name,
    PlatformType? platformType,
    String? ipAddress,
    int? port,
    bool? isOnline,
    bool? isLocked,
  }) {
    return DeviceNode(
      id: id ?? this.id,
      name: name ?? this.name,
      platformType: platformType ?? this.platformType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      isOnline: isOnline ?? this.isOnline,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          platformType == other.platformType &&
          ipAddress == other.ipAddress &&
          port == other.port &&
          isOnline == other.isOnline &&
          isLocked == other.isLocked;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    platformType,
    ipAddress,
    port,
    isOnline,
    isLocked,
  );

  @override
  String toString() =>
      'DeviceNode(id: $id, name: $name, platform: ${platformType.name}, host: $ipAddress:$port, online: $isOnline, locked: $isLocked)';
}

/// Represents an indexable file or folder shared within the pool.
class PoolFileItem {
  final String id;
  final String deviceId;
  final String deviceName;
  final String name;
  final String relativePath;
  final String syncedRootFolder;
  final String mimeType;
  final int sizeBytes;
  final DateTime modifiedAt;
  final bool isDirectory;
  final String? thumbnailUrl;
  final String? streamUrl;

  const PoolFileItem({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.name,
    required this.relativePath,
    required this.syncedRootFolder,
    required this.mimeType,
    required this.sizeBytes,
    required this.modifiedAt,
    this.isDirectory = false,
    this.thumbnailUrl,
    this.streamUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'name': name,
    'relativePath': relativePath,
    'syncedRootFolder': syncedRootFolder,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'modifiedAt': modifiedAt.toIso8601String(),
    'isDirectory': isDirectory,
    'thumbnailUrl': thumbnailUrl,
    'streamUrl': streamUrl,
  };

  factory PoolFileItem.fromJson(Map<String, dynamic> json) {
    return PoolFileItem(
      id: json['id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      name: json['name'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
      syncedRootFolder: json['syncedRootFolder'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      modifiedAt: _parseModifiedAt(json['modifiedAt']),
      isDirectory: json['isDirectory'] as bool? ?? false,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      streamUrl: json['streamUrl'] as String?,
    );
  }

  static DateTime _parseModifiedAt(dynamic raw) {
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  PoolFileItem copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? name,
    String? relativePath,
    String? syncedRootFolder,
    String? mimeType,
    int? sizeBytes,
    DateTime? modifiedAt,
    bool? isDirectory,
    String? thumbnailUrl,
    String? streamUrl,
  }) {
    return PoolFileItem(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      syncedRootFolder: syncedRootFolder ?? this.syncedRootFolder,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isDirectory: isDirectory ?? this.isDirectory,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PoolFileItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceId == other.deviceId &&
          deviceName == other.deviceName &&
          name == other.name &&
          relativePath == other.relativePath &&
          syncedRootFolder == other.syncedRootFolder &&
          mimeType == other.mimeType &&
          sizeBytes == other.sizeBytes &&
          modifiedAt == other.modifiedAt &&
          isDirectory == other.isDirectory &&
          thumbnailUrl == other.thumbnailUrl &&
          streamUrl == other.streamUrl;

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    deviceName,
    name,
    relativePath,
    syncedRootFolder,
    mimeType,
    sizeBytes,
    modifiedAt,
    isDirectory,
    thumbnailUrl,
    streamUrl,
  );

  @override
  String toString() =>
      'PoolFileItem(id: $id, name: $name, size: $sizeBytes, isDir: $isDirectory, host: $deviceName)';
}

/// Abstract interface declaring the REST API endpoints and contract signatures
/// for both Shelf HTTP routing and client-side communication.
abstract interface class PoolApiRoutes {
  static const String pathPing = '/api/ping';
  static const String pathIndex = '/api/index';
  static const String pathThumb = '/api/thumb';
  static const String pathStream = '/api/stream';
  static const String pathDownloadFolder = '/api/download-folder';
  static const String pathMutate = '/api/mutate';

  /// GET /api/ping
  /// Returns the host's current [DeviceNode] JSON representation,
  /// including live [DeviceNode.isLocked] status.
  Future<DeviceNode> ping();

  /// GET /api/index
  /// Returns a list of [PoolFileItem] published by user-selected folders on the host.
  Future<List<PoolFileItem>> index();

  /// GET /api/thumb?path=<encoded_path>
  /// Retrieves a lightweight (target ~15KB) WebP thumbnail for the file at [path].
  Future<Uint8List> thumb(String path);

  /// GET /api/stream?path=<encoded_path>
  /// Streams file content at [path], supporting HTTP 206 Byte-Range streaming
  /// with optional [range] header (e.g. 'bytes=0-1048576').
  Future<Stream<List<int>>> stream(String path, {String? range});

  /// GET /api/download-folder?path=<encoded_path>
  /// Streams a TAR/ZIP archive or multi-file stream of the folder at [path].
  Future<Stream<List<int>>> downloadFolder(String path);

  /// POST /api/mutate
  /// Performs file operations: action ('rename', 'delete', 'move'),
  /// [sourcePath], and optional [targetPath].
  /// Deleted files are safely relocated to '.pool_trash' instead of permanent deletion.
  Future<Map<String, dynamic>> mutate({
    required String action,
    required String sourcePath,
    String? targetPath,
  });
}
