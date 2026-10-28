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
    this.nullClockIsUnset = false,
  });

  final String name;

  /// JSON key of the clock in a synced row, e.g. `uploadFactsHlc`.
  final String clockKey;

  /// SQL column of the clock, e.g. `upload_facts_hlc`.
  final String clockColumn;

  /// The group's fact columns, JSON key to SQL column.
  final Map<String, String> columns;

  /// Whether a clock present but null means "never written" rather than
  /// "written under the row clock".
  ///
  /// Off for media, whose rows predate their fact clocks and wrote facts
  /// through the row clock, so a null clock honestly falls back to it, and a
  /// row-clock stamp seeds the group clock. On for a diver's list
  /// arrangements (issue #3748): a row whose arrangement clock is null never
  /// had its arrangement changed under a clock, so it must lose to any
  /// arrangement change a peer made, not borrow the clock of an unrelated
  /// settings save. Only a key the side does not send at all (an older peer)
  /// still falls back to the row clock.
  final bool nullClockIsUnset;
}

/// Which entities carry fact groups: media's device observations, and a
/// diver's list arrangements. An entity with none merges exactly as before.
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
      'remoteStoreId': 'remote_store_id',
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

  /// How the diver left each list (issue #3748). Not a device observation
  /// but the same need: sorting is one of the most frequent taps in the
  /// app, and stamping the settings row's clock for it would let a device
  /// holding stale settings republish them over a gradient-factor or units
  /// change made on another device. Under its own clock a sort orders only
  /// against other arrangement changes. The view modes and the group-trips
  /// toggle are in the group because the in-list toggles change them as
  /// often.
  static const SyncFactGroup diverSettingsListArrangement = SyncFactGroup(
    name: 'listArrangement',
    clockKey: 'listArrangementHlc',
    clockColumn: 'list_arrangement_hlc',
    columns: {
      'diveListSort': 'dive_list_sort',
      'divePlanListSort': 'dive_plan_list_sort',
      'tripListSort': 'trip_list_sort',
      'courseListSort': 'course_list_sort',
      'buddyListSort': 'buddy_list_sort',
      'diveCenterListSort': 'dive_center_list_sort',
      'siteListSort': 'site_list_sort',
      'certificationListSort': 'certification_list_sort',
      'equipmentListSort': 'equipment_list_sort',
      'siteListGroupBy': 'site_list_group_by',
      'certificationListGroupBy': 'certification_list_group_by',
      'equipmentArrangement': 'equipment_arrangement',
      'equipmentGroupByLocation': 'equipment_group_by_location',
      'diveListViewMode': 'dive_list_view_mode',
      'siteListViewMode': 'site_list_view_mode',
      'tripListViewMode': 'trip_list_view_mode',
      'equipmentListViewMode': 'equipment_list_view_mode',
      'buddyListViewMode': 'buddy_list_view_mode',
      'diveCenterListViewMode': 'dive_center_list_view_mode',
      'certificationListViewMode': 'certification_list_view_mode',
      'courseListViewMode': 'course_list_view_mode',
      'groupTripsInDiveList': 'group_trips_in_dive_list',
    },
    nullClockIsUnset: true,
  );

  static const Map<String, List<SyncFactGroup>> byEntity = {
    'media': [mediaUpload, mediaVerification],
    'diverSettings': [diverSettingsListArrangement],
  };

  static List<SyncFactGroup> of(String entityType) =>
      byEntity[entityType] ?? const [];

  /// The table and key column each entity's fact groups live on. A test
  /// pins it to SyncRepository.hlcTargets, which is test-visible only.
  static const Map<String, ({String table, String pk})> tables = {
    'media': (table: 'media', pk: 'id'),
    'diverSettings': (table: 'diver_settings', pk: 'id'),
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
  // Sent, and null: never written (see SyncFactGroup.nullClockIsUnset).
  if (g.nullClockIsUnset && side.containsKey(g.clockKey)) return null;
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
