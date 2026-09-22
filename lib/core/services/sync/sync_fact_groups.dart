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

  /// The table and key column each entity's fact groups live on. A test
  /// pins it to SyncRepository.hlcTargets, which is test-visible only.
  static const Map<String, ({String table, String pk})> tables = {
    'media': (table: 'media', pk: 'id'),
  };
}

/// The resolved row and the groups the peer won.
///
/// A fact column neither side carries is ABSENT from [row], never null, so
/// a caller writing the groups back can tell "no value" from "cleared".
typedef FactResolution = ({
  Map<String, dynamic> row,
  List<SyncFactGroup> fromRemote,
});

/// A side's clock for [g]: its own group clock, else its row clock (rows
/// from an older app version, or from before the v224 rung, stamped facts
/// through the row clock).
String? _effectiveClock(Map<String, dynamic>? side, SyncFactGroup g) {
  if (side == null) return null;
  final own = side[g.clockKey];
  if (own is String && own.isNotEmpty) return own;
  final row = side['hlc'];
  return row is String && row.isNotEmpty ? row : null;
}

/// Applies each fact group's winner onto [base], the row that won the user
/// fields (media sync program spec 5.1).
///
/// The peer wins a group only on a strictly newer effective clock (a tie is
/// the same write, so local is kept); canonical HLC strings order with
/// String.compareTo, as the export watermark does. With both clocks missing
/// the group follows [base], which is how the row merged before fact clocks.
/// The winner supplies every column of the group, explicit nulls included,
/// and its effective clock becomes the group clock, so a legacy peer's row
/// clock is remembered as the fact clock.
FactResolution mergeFactGroups({
  required String entityType,
  required Map<String, dynamic> base,
  required Map<String, dynamic>? local,
  required Map<String, dynamic> remote,
}) {
  final groups = SyncFactGroups.of(entityType);
  if (groups.isEmpty) return (row: base, fromRemote: const []);
  var row = base;
  final fromRemote = <SyncFactGroup>[];
  for (final g in groups) {
    final localClock = _effectiveClock(local, g);
    final remoteClock = _effectiveClock(remote, g);
    final Map<String, dynamic> winner;
    final String? clock;
    if (local == null ||
        (remoteClock != null &&
            (localClock == null || remoteClock.compareTo(localClock) > 0))) {
      winner = remote;
      clock = remoteClock;
      fromRemote.add(g);
    } else if (localClock == null && remoteClock == null) {
      winner = base;
      clock = null;
    } else {
      winner = local;
      clock = localClock;
    }
    // An OMITTED column is not a clear. A peer on an older build sends no
    // key for a column it does not know, and writing null for it would
    // erase a fact this device legitimately holds; an explicit null IS a
    // clear and must travel. Same distinction the row overlay makes.
    row = {
      ...row,
      for (final key in g.columns.keys)
        if (winner.containsKey(key))
          key: winner[key]
        else if (local != null && local.containsKey(key))
          key: local[key],
      g.clockKey: clock,
    };
  }
  return (row: row, fromRemote: fromRemote);
}
