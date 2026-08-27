/// The "library moved" protocol for backend switches.
///
/// When a device switches its sync backend (e.g. S3 -> iCloud), the library
/// is not migrated: the old backend keeps an untouched, now-orphaned copy.
/// A second device still pointed at the old backend would keep syncing into
/// that copy forever, with no error and no sign that the rest of the fleet
/// has moved on -- an invisible split-brain.
///
/// To break that silence, the switching device writes this marker to the OLD
/// backend on its way out. A straggler device reads it on its next sync,
/// pauses, and tells its user where the library went. It is purely
/// advisory: it never deletes data and never forces a switch.
library;

/// Cloud filename of the moved marker.
///
/// MUST NOT contain CloudStorageProviderMixin.syncFileStem
/// ('submersion_sync'): sync-file discovery lists files by substring match on
/// that stem and would otherwise treat the marker as a peer device's sync
/// file. Mirrors the constraint on [libraryEpochFileName].
const String libraryMovedFileName = 'submersion_library_moved.json';

/// Cloud marker contents: which backend the library moved TO, who moved it,
/// and when. Doubles as the audit record shown in the straggler's banner.
class LibraryMovedMarker {
  /// Unix milliseconds of the switch.
  final int movedAt;

  /// providerId of the backend the library moved to (e.g. 'icloud').
  final String toProviderId;

  /// Human-readable name of the destination backend (e.g. 'iCloud').
  final String? toProviderName;

  final String deviceId;
  final String? deviceName;
  final String? appVersion;

  const LibraryMovedMarker({
    required this.movedAt,
    required this.toProviderId,
    this.toProviderName,
    required this.deviceId,
    this.deviceName,
    this.appVersion,
  });

  /// Human-readable origin for banners: device name, else device id, else '?'.
  /// Never blank -- [fromJson] tolerates an empty deviceId.
  String get displayName {
    final name = deviceName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final id = deviceId.trim();
    return id.isNotEmpty ? id : '?';
  }

  /// Destination backend for display: name when present, else the id.
  String get toProviderDisplay {
    final name = toProviderName?.trim() ?? '';
    return name.isNotEmpty ? name : toProviderId;
  }

  Map<String, dynamic> toJson() => {
    'movedAt': movedAt,
    'toProviderId': toProviderId,
    'toProviderName': toProviderName,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'appVersion': appVersion,
  };

  factory LibraryMovedMarker.fromJson(Map<String, dynamic> json) {
    final toProviderId = json['toProviderId'];
    if (toProviderId is! String || toProviderId.isEmpty) {
      throw const FormatException('Library moved marker has no destination');
    }
    return LibraryMovedMarker(
      movedAt: (json['movedAt'] as num?)?.toInt() ?? 0,
      toProviderId: toProviderId,
      toProviderName: json['toProviderName'] as String?,
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String?,
      appVersion: json['appVersion'] as String?,
    );
  }
}
