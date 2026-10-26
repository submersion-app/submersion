import 'package:drift/drift.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/source_clock_repository.dart';

/// Lightweight DTO for the bulk-fix preview (avoids requiring all Dive fields).
class DiveTimePreview {
  const DiveTimePreview({
    required this.id,
    required this.dateTime,
    this.diveNumber,
    this.siteName,
  });

  final String id;
  final DateTime dateTime;
  final int? diveNumber;
  final String? siteName;
}

class DiveTimeMigrationService {
  DiveTimeMigrationService(this._db);

  final AppDatabase _db;

  /// Compute a shifted epoch by the given number of hours.
  static int computeShiftedEpoch(int epochMs, int hours) {
    return epochMs + (hours * 3600 * 1000);
  }

  /// Get dives matching a date range for the bulk-fix preview.
  Future<List<DiveTimePreview>> getDivesForPreview({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final query = _db.select(_db.dives);
    if (rangeStart != null) {
      query.where(
        (t) => t.diveDateTime.isBiggerOrEqualValue(
          rangeStart.millisecondsSinceEpoch,
        ),
      );
    }
    if (rangeEnd != null) {
      query.where(
        (t) => t.diveDateTime.isSmallerOrEqualValue(
          rangeEnd.millisecondsSinceEpoch,
        ),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => DiveTimePreview(
            id: row.id,
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              row.diveDateTime,
              isUtc: true,
            ),
            diveNumber: row.diveNumber,
          ),
        )
        .toList();
  }

  /// Apply an hour offset to the specified dive IDs.
  /// Uses Drift's typed update API to avoid SQL injection.
  ///
  /// Each dive's primary source moves with it: it is the recording the
  /// logbook mirrors, and left behind, a later Set primary would copy its
  /// old window back over the fix (#3655). Every moved row is marked
  /// pending so the fix reaches the diver's other devices.
  Future<void> applyOffset({
    required List<String> diveIds,
    required int hours,
  }) async {
    if (diveIds.isEmpty || hours == 0) return;
    final offsetMs = hours * 3600 * 1000;
    final sync = SyncRepository(database: _db);
    final sources = SourceClockRepository(database: _db);

    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in diveIds) {
        final row = await (_db.select(
          _db.dives,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null) continue;

        await (_db.update(_db.dives)..where((t) => t.id.equals(id))).write(
          DivesCompanion(
            diveDateTime: Value(row.diveDateTime + offsetMs),
            entryTime: Value(
              row.entryTime != null ? row.entryTime! + offsetMs : null,
            ),
            exitTime: Value(
              row.exitTime != null ? row.exitTime! + offsetMs : null,
            ),
            updatedAt: Value(now),
          ),
        );
        await sync.markRecordPending(
          entityType: 'dives',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      await sources.shift(
        await sources.snapshot(await sources.primarySourceIds(diveIds)),
        Duration(hours: hours),
      );
    });
    SyncEventBus.notifyLocalChange();
  }
}
