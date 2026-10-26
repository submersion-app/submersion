import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

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
    final t = _db.diveDataSources;
    return [
      for (final chunk in seriesIdChunks(sourceIds))
        ...await _windows(
          t.id.isIn(chunk) & (t.entryTime.isNotNull() | t.exitTime.isNotNull()),
        ),
    ];
  }

  /// The window columns alone. A full-row select would read and inflate
  /// every row's rawData blob just to compare two timestamps.
  Future<List<SourceTimesSnapshot>> _windows(
    Expression<bool> where, {
    List<OrderingTerm> orderBy = const [],
  }) async {
    final t = _db.diveDataSources;
    final rows =
        await (_db.selectOnly(t)
              ..addColumns([t.id, t.diveId, t.entryTime, t.exitTime])
              ..where(where)
              ..orderBy(orderBy))
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

  /// The source each of [diveIds] reads as its primary, by dive: the one
  /// flagged primary, else its oldest. The same order the Sources panel
  /// shows and the clock detector compares against, so a dive whose rows
  /// carry no primary flag still has its reference source moved (#3655).
  Future<Map<String, SourceTimesSnapshot>> _effectivePrimaries(
    Iterable<String> diveIds,
  ) async {
    final t = _db.diveDataSources;
    final byDive = <String, SourceTimesSnapshot>{};
    for (final chunk in seriesIdChunks(diveIds.toSet().toList())) {
      final rows = await _windows(
        t.diveId.isIn(chunk),
        orderBy: [
          OrderingTerm.desc(t.isPrimary),
          OrderingTerm.asc(t.createdAt),
        ],
      );
      for (final r in rows) {
        byDive.putIfAbsent(r.diveId, () => r);
      }
    }
    return byDive;
  }

  /// The primary source of each of [diveIds] that has any source, as
  /// [_effectivePrimaries] picks it.
  Future<List<String>> primarySourceIds(List<String> diveIds) async => [
    for (final p in (await _effectivePrimaries(diveIds)).values) p.id,
  ];

  /// Whether [sourceId] names a registered computer now. A finding's own
  /// computerId is as of its last scan, and the computer may have been
  /// removed or linked since.
  Future<bool> namesComputer(String sourceId) async =>
      await _computerIdOf(sourceId) != null;

  Future<String?> _computerIdOf(String sourceId) async {
    final t = _db.diveDataSources;
    final row =
        await (_db.selectOnly(t)
              ..addColumns([t.computerId])
              ..where(t.id.equals(sourceId)))
            .getSingleOrNull();
    return row?.read(t.computerId);
  }

  /// [sourceId] first, then every other source from the same computer that
  /// a shift of [offset] would also bring onto its dive's primary: the same
  /// clock mistake, made on every dive the computer downloaded before its
  /// clock was fixed. Within [toleranceMinutes] of that, as the detector
  /// allows. Just [sourceId] when it names no registered computer, since
  /// nothing then says which sources share it.
  Future<List<String>> sourcesSharingClockOffset({
    required String sourceId,
    required Duration offset,
    required int toleranceMinutes,
  }) async {
    final computerId = await _computerIdOf(sourceId);
    if (computerId == null) return [sourceId];

    final t = _db.diveDataSources;
    final candidates = await _windows(
      t.computerId.equals(computerId) &
          t.entryTime.isNotNull() &
          t.id.equals(sourceId).not(),
    );
    if (candidates.isEmpty) return [sourceId];
    final primaries = await _effectivePrimaries(
      candidates.map((c) => c.diveId),
    );

    // The secondary reads -offset relative to its primary.
    final targetMinutes = -offset.inMinutes;
    return [
      sourceId,
      for (final c in candidates)
        if (primaries[c.diveId] case (
          id: final primaryId,
          entryTime: final primaryEntry?,
          diveId: _,
          exitTime: _,
        ))
          if (primaryId != c.id &&
              (c.entryTime!.difference(primaryEntry).inMinutes - targetMinutes)
                      .abs() <=
                  toleranceMinutes)
            c.id,
    ];
  }
}
