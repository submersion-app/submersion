import 'package:submersion/core/services/nearby/nearby_watermarks.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

enum NearbyExportKind {
  /// The peer knows every writer this device holds: send what is newer.
  delta,

  /// The peer has never heard of some writer this device holds, so a delta
  /// since any one watermark could miss that writer's older rows.
  full,

  /// This device holds nothing.
  nothing,
}

/// Decides what one sync direction sends, and trims a delta to what the
/// peer lacks.
///
/// Rows without a clock never travel in a delta, as in cloud changesets:
/// they cross in the first full copy, and clockless children ride with
/// their parents.
abstract final class NearbyExportPlanner {
  static NearbyExportKind decide({
    required NearbyWatermarks mine,
    required NearbyWatermarks peers,
  }) {
    if (mine.isEmpty) return NearbyExportKind.nothing;
    final known = peers.highByWriter;
    for (final writer in mine.highByWriter.keys) {
      if (!known.containsKey(writer)) return NearbyExportKind.full;
    }
    return NearbyExportKind.delta;
  }

  /// The watermark to export a delta from: the lowest peer mark among the
  /// writers this device is ahead on, so an old writer with nothing new does
  /// not drag the export window back. Null when the peer is caught up.
  static String? deltaWatermark({
    required NearbyWatermarks mine,
    required NearbyWatermarks peers,
  }) {
    String? low;
    for (final entry in mine.highByWriter.entries) {
      final theirs = peers.highByWriter[entry.key];
      if (theirs == null || entry.value.compareTo(theirs) <= 0) continue;
      if (low == null || theirs.compareTo(low) < 0) low = theirs;
    }
    return low;
  }

  /// [payload] without the rows and tombstones the peer already has: those
  /// whose every clock is at or below the peer's mark for that clock's
  /// writer. A row with no clock, or from a writer the peer does not know,
  /// is kept.
  static SyncPayload filterByWriter(
    SyncPayload payload,
    NearbyWatermarks peers,
  ) {
    bool covered(Object? clock) {
      if (clock is! String) return false;
      final writer = NearbyWatermarks.writerOf(clock);
      final mark = writer == null ? null : peers.highByWriter[writer];
      return mark != null && clock.compareTo(mark) <= 0;
    }

    final json = payload.data.toJson();
    final data = <String, dynamic>{
      for (final entry in json.entries)
        entry.key: entry.value is List
            ? [
                for (final row in entry.value as List)
                  if (row is! Map<String, dynamic> ||
                      !_rowCovered(entry.key, row, covered))
                    row,
              ]
            : entry.value,
    };
    final filtered = SyncData.fromJson(data);
    return SyncPayload(
      version: payload.version,
      exportedAt: payload.exportedAt,
      deviceId: payload.deviceId,
      lastSyncTimestamp: payload.lastSyncTimestamp,
      checksum: SyncDataSerializer.checksumOf(filtered),
      data: filtered,
      deletions: {
        for (final entry in payload.deletions.entries)
          entry.key: [
            for (final d in entry.value)
              if (!covered(d.hlc)) d,
          ],
      },
      uploadNonce: payload.uploadNonce,
      epochId: payload.epochId,
      seq: payload.seq,
      baseSeq: payload.baseSeq,
      sinceHlc: payload.sinceHlc,
      toHlc: payload.toHlc,
    );
  }

  static bool _rowCovered(
    String entityType,
    Map<String, dynamic> row,
    bool Function(Object?) covered,
  ) {
    if (!covered(row['hlc'])) return false;
    for (final group in SyncFactGroups.of(entityType)) {
      final clock = row[group.clockKey];
      if (clock != null && !covered(clock)) return false;
    }
    return true;
  }
}
