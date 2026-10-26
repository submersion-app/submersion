import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

/// One source's stored provenance window, as it was before a shift.
typedef SourceTimesSnapshot = ({
  String id,
  String diveId,
  DateTime? entryTime,
  DateTime? exitTime,
});

/// Moves the entry/exit window of individual `dive_data_sources` rows, for
/// the clock repairs of issue #3655.
///
/// A source's window is its own computer's clock: consolidation copies it
/// across untouched and records the sample shift in `timeOffsetSeconds`
/// instead, so correcting a wrong clock moves only these two columns. The
/// samples are already on the dive's timeline and stay where they are.
///
/// Writes do not open a transaction or notify sync; the caller (the repair
/// executor, or Settings > Fix dive times) owns both. Only the source rows
/// are marked pending: a parent dive whose own row did not change is not
/// re-stamped (#1769).
class SourceClockRepository {
  SourceClockRepository({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;

  /// The windows of [sourceIds] that hold a time at all, for [shift] and
  /// [restore]. A source that is gone, or never had a window, is left out.
  Future<List<SourceTimesSnapshot>> snapshot(List<String> sourceIds) async {
    if (sourceIds.isEmpty) return const [];
    final t = _db.diveDataSources;
    return _windows(
      t.id.isIn(sourceIds) & (t.entryTime.isNotNull() | t.exitTime.isNotNull()),
    );
  }

  /// The window columns alone. A full-row select would read and inflate
  /// every row's rawData blob just to compare two timestamps.
  Future<List<SourceTimesSnapshot>> _windows(Expression<bool> where) async {
    final t = _db.diveDataSources;
    final rows =
        await (_db.selectOnly(t)
              ..addColumns([t.id, t.diveId, t.entryTime, t.exitTime])
              ..where(where))
            .get();
    return [
      for (final r in rows)
        (
          id: r.read(t.id)!,
          diveId: r.read(t.diveId)!,
          entryTime: r.read(t.entryTime),
          exitTime: r.read(t.exitTime),
        ),
    ];
  }

  /// Moves each window in [rows] by [offset].
  Future<void> shift(List<SourceTimesSnapshot> rows, Duration offset) async {
    if (offset == Duration.zero) return;
    await _write([
      for (final r in rows)
        (
          id: r.id,
          diveId: r.diveId,
          entryTime: r.entryTime?.add(offset),
          exitTime: r.exitTime?.add(offset),
        ),
    ]);
  }

  /// Puts back the windows a [snapshot] recorded (repair undo).
  Future<void> restore(List<SourceTimesSnapshot> snapshot) => _write(snapshot);

  Future<void> _write(List<SourceTimesSnapshot> rows) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      await (_db.update(
        _db.diveDataSources,
      )..where((t) => t.id.equals(r.id))).write(
        DiveDataSourcesCompanion(
          entryTime: Value(r.entryTime),
          exitTime: Value(r.exitTime),
        ),
      );
      await _sync.markRecordPending(
        entityType: 'diveDataSources',
        recordId: r.id,
        localUpdatedAt: now,
      );
    }
  }

  /// The primary source of each of [diveIds] that has one.
  Future<List<String>> primarySourceIds(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final rows =
        await (_db.selectOnly(_db.diveDataSources)
              ..addColumns([_db.diveDataSources.id])
              ..where(
                _db.diveDataSources.diveId.isIn(diveIds) &
                    _db.diveDataSources.isPrimary.equals(true),
              ))
            .get();
    return [for (final r in rows) r.read(_db.diveDataSources.id)!];
  }

  /// [sourceId] first, then every other secondary source from the same
  /// computer that a shift of [offset] would also bring onto its dive's
  /// primary: the same clock mistake, made on every dive the computer
  /// downloaded before its clock was fixed. Within [toleranceMinutes] of
  /// that, as the detector allows. Just [sourceId] when it names no
  /// registered computer, since nothing then says which sources share it.
  Future<List<String>> sourcesSharingClockOffset({
    required String sourceId,
    required Duration offset,
    required int toleranceMinutes,
  }) async {
    final t = _db.diveDataSources;
    final own =
        await (_db.selectOnly(t)
              ..addColumns([t.computerId])
              ..where(t.id.equals(sourceId)))
            .getSingleOrNull();
    final computerId = own?.read(t.computerId);
    if (computerId == null) return [sourceId];

    final candidates = await _windows(
      t.computerId.equals(computerId) &
          t.isPrimary.equals(false) &
          t.entryTime.isNotNull() &
          t.id.equals(sourceId).not(),
    );
    if (candidates.isEmpty) return [sourceId];

    final primaries = await _windows(
      t.diveId.isIn({for (final c in candidates) c.diveId}) &
          t.isPrimary.equals(true) &
          t.entryTime.isNotNull(),
    );
    final primaryEntryByDive = {
      for (final p in primaries) p.diveId: p.entryTime!,
    };

    // The secondary reads -offset relative to its primary.
    final targetMinutes = -offset.inMinutes;
    return [
      sourceId,
      for (final c in candidates)
        if (primaryEntryByDive[c.diveId] case final primaryEntry?)
          if ((c.entryTime!.difference(primaryEntry).inMinutes - targetMinutes)
                  .abs() <=
              toleranceMinutes)
            c.id,
    ];
  }
}
