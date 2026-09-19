/// A set of device-stamped columns that travel under their own clock rather
/// than the row's (media sync program spec 5.1). A fact is an observation a
/// device makes (an upload finished, a file was found missing), not a user
/// edit, so it must neither win the row for a stale user field nor lose to
/// one. Each group merges last-writer-wins by its own clock, and a missing
/// clock falls back to the row clock.
class SyncFactGroup {
  const SyncFactGroup({
    required this.name,
    required this.clockKey,
    required this.clockColumn,
    required this.columns,
  });

  final String name;

  /// JSON key of the clock in a synced row, e.g. `uploadFactsHlc`.
  final String clockKey;

  /// SQL column of the clock, e.g. `upload_facts_hlc`.
  final String clockColumn;

  /// The group's fact columns, JSON key to SQL column.
  final Map<String, String> columns;
}

/// Which entities carry fact groups. Only media does today; an entity with
/// none merges exactly as before.
abstract final class SyncFactGroups {
  static const SyncFactGroup mediaUpload = SyncFactGroup(
    name: 'upload',
    clockKey: 'uploadFactsHlc',
    clockColumn: 'upload_facts_hlc',
    columns: {
      'contentHash': 'content_hash',
      'contentSizeBytes': 'content_size_bytes',
      'remoteUploadedAt': 'remote_uploaded_at',
      'remoteThumbUploadedAt': 'remote_thumb_uploaded_at',
      'remoteCompressedUploadedAt': 'remote_compressed_uploaded_at',
      'compressedLevel': 'compressed_level',
      'compressedSizeBytes': 'compressed_size_bytes',
    },
  );

  static const SyncFactGroup mediaVerification = SyncFactGroup(
    name: 'verification',
    clockKey: 'verifyFactsHlc',
    clockColumn: 'verify_facts_hlc',
    columns: {
      'isOrphaned': 'is_orphaned',
      'lastVerifiedAt': 'last_verified_at',
    },
  );

  static const Map<String, List<SyncFactGroup>> byEntity = {
    'media': [mediaUpload, mediaVerification],
  };

  static List<SyncFactGroup> of(String entityType) =>
      byEntity[entityType] ?? const [];
}
