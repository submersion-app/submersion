/// The library epoch protocol for restore Replace mode.
///
/// A "replace" restore mints a new epoch id. The cloud marker file is the
/// authoritative statement of the current library generation; every sync
/// payload carries the epoch it was written under, so files from an older
/// generation are identifiable and inert no matter when they surface.
library;

/// Cloud filename of the epoch marker.
///
/// MUST NOT contain CloudStorageProviderMixin.syncFileStem
/// ('submersion_sync'): sync-file discovery lists files by substring match
/// on that stem and would treat the marker as a peer device's sync file.
const String libraryEpochFileName = 'submersion_library_epoch.json';

/// Cloud marker contents: which epoch is current, who replaced the library,
/// and when. Doubles as the audit record shown in the peer adopt prompt.
class LibraryEpochMarker {
  final String epochId;

  /// Unix milliseconds of the replace.
  final int replacedAt;
  final String deviceId;
  final String? deviceName;
  final String? appVersion;

  const LibraryEpochMarker({
    required this.epochId,
    required this.replacedAt,
    required this.deviceId,
    this.deviceName,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
    'epochId': epochId,
    'replacedAt': replacedAt,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'appVersion': appVersion,
  };

  factory LibraryEpochMarker.fromJson(Map<String, dynamic> json) {
    final epochId = json['epochId'];
    if (epochId is! String || epochId.isEmpty) {
      throw const FormatException('Library epoch marker has no epochId');
    }
    return LibraryEpochMarker(
      epochId: epochId,
      replacedAt: (json['replacedAt'] as num?)?.toInt() ?? 0,
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }
}
