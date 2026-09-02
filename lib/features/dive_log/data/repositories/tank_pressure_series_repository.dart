import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// Every read and write of `tank_pressure_series`. See
/// `ProfileSeriesRepository` for the conventions; this is its two-field
/// sibling keyed by (dive, tank, computer).
class TankPressureSeriesRepository {
  TankPressureSeriesRepository({
    SyncRepository? syncRepository,
    AppDatabase? database,
  }) : _syncRepository = syncRepository ?? SyncRepository(database: database),
       _database = database;

  static const String entityType = 'tankPressureSeries';

  static const TankPressureSeriesCodec _codec = TankPressureSeriesCodec();

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TankPressureSeriesRepository);

  /// Inserts one series and marks it pending. [samples] must be non-empty;
  /// any order, the repository sorts by timestamp (stable) and drops exact
  /// duplicates. Returns the id.
  Future<String> insertSeries({
    required String diveId,
    required String tankId,
    String? computerId,
    required List<TankPressureSample> samples,
    String? id,
    int? now,
  }) async {
    final encoded = _codec.encode(
      dedupeExactPressureSamples(_sortedByTimestamp(samples)),
    );
    final rowId = id ?? _uuid.v4();
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    // One transaction, like every other mutator here: a row that commits
    // without its sync bookkeeping carries no HLC, and the strict watermark
    // comparison then hides it from every incremental export.
    await _db.transaction(() async {
      await _db
          .into(_db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: rowId,
              diveId: diveId,
              tankId: tankId,
              computerId: Value(computerId),
              sampleCount: encoded.summary.sampleCount,
              startTimestamp: encoded.summary.startTimestamp,
              endTimestamp: encoded.summary.endTimestamp,
              codecVersion: encoded.codecVersion,
              samples: encoded.bytes,
              createdAt: nowMs,
              updatedAt: nowMs,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: rowId,
        localUpdatedAt: nowMs,
      );
    });
    SyncEventBus.notifyLocalChange();
    return rowId;
  }

  /// Timestamp order, ties in input order. Every writer hands over whatever
  /// order it has; the codec and every reader assume ascending timestamps.
  static List<TankPressureSample> _sortedByTimestamp(
    List<TankPressureSample> samples,
  ) {
    final indexed = [
      for (var i = 0; i < samples.length; i++) (samples[i].timestamp, i),
    ];
    indexed.sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
    });
    return [for (final e in indexed) samples[e.$2]];
  }

  /// Every series of [diveId], by tank then start then id.
  Future<List<domain.TankPressureSeries>> getSeriesForDive(
    String diveId,
  ) async {
    final rows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tankId),
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) ?_decodeOrNull(row)];
  }

  Future<List<domain.TankPressureSeries>> getSeriesForTank(
    String diveId,
    String tankId,
  ) async {
    final rows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId) & t.tankId.equals(tankId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) ?_decodeOrNull(row)];
  }

  /// Whether [diveId] has any tank pressure series. A count, no decode.
  Future<bool> hasSeriesForDive(String diveId) async {
    final query = _db.selectOnly(_db.tankPressureSeries)
      ..addColumns([_db.tankPressureSeries.id.count()])
      ..where(_db.tankPressureSeries.diveId.equals(diveId));
    final row = await query.getSingle();
    return (row.read(_db.tankPressureSeries.id.count()) ?? 0) > 0;
  }

  /// The tank twin of `ProfileSeriesRepository.unreadableSeriesIds`: the
  /// ids of [diveIds]'s pressure series whose blob does not decode.
  Future<List<String>> unreadableSeriesIds(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    return [
      for (final row in await getRowsForDives(diveIds))
        if (_decodeOrNull(row) == null) row.id,
    ];
  }

  /// Raw rows of every series of [diveIds], undecoded, for snapshots that
  /// restore them verbatim through [restoreSeriesRow].
  ///
  /// [diveIds] is queried in chunks of at most [kSeriesIdChunkSize], concatenated
  /// and sorted by `(diveId, tankId, startTimestamp, id)`, which is the
  /// order a single unchunked query with that `ORDER BY` would have
  /// returned. See `ProfileSeriesRepository._rowsForDives` for why: binding
  /// one SQL variable per dive id can exceed the engine's bound-variable
  /// ceiling on a whole library's filtered dive ids.
  Future<List<TankPressureSeriesRow>> getRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    final rows = <TankPressureSeriesRow>[];
    for (final chunk in seriesIdChunks(diveIds)) {
      rows.addAll(
        await (_db.select(
          _db.tankPressureSeries,
        )..where((t) => t.diveId.isIn(chunk))).get(),
      );
    }
    rows.sort(_byDiveTankStartId);
    return rows;
  }

  static int _byDiveTankStartId(
    TankPressureSeriesRow a,
    TankPressureSeriesRow b,
  ) {
    final byDive = a.diveId.compareTo(b.diveId);
    if (byDive != 0) return byDive;
    final byTank = a.tankId.compareTo(b.tankId);
    if (byTank != 0) return byTank;
    final byStart = a.startTimestamp.compareTo(b.startTimestamp);
    if (byStart != 0) return byStart;
    return a.id.compareTo(b.id);
  }

  /// Points every series of [fromTankId] on [diveId] at [toTankId] (the
  /// wrong-cylinder repair). Returns the number of series moved.
  Future<int> reassignTank(
    String diveId,
    String fromTankId,
    String toTankId, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(fromTankId),
    );
    if (ids.isEmpty) return 0;
    await _retarget(ids, toTankId, nowMs);
    return ids.length;
  }

  /// Exchanges the tank ids of the two series sets (the swapped-cylinders
  /// repair). Both sets are read before either is written.
  Future<void> swapTanks(
    String diveId,
    String tankIdA,
    String tankIdB, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final aIds = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdA),
    );
    final bIds = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdB),
    );
    await _db.transaction(() async {
      if (aIds.isNotEmpty) await _retarget(aIds, tankIdB, nowMs);
      if (bIds.isNotEmpty) await _retarget(bIds, tankIdA, nowMs);
    });
  }

  /// Stamps [computerId] on the null-computer series of [diveId]
  /// (consolidation gives the target's unattributed pressures to its primary
  /// computer). Returns the number of series stamped.
  Future<int> stampComputerWhereNull(
    String diveId,
    String computerId, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) => t.diveId.equals(diveId) & t.computerId.isNull(),
    );
    if (ids.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(
        _db.tankPressureSeries,
      )..where((t) => t.id.isIn(ids))).write(
        TankPressureSeriesCompanion(
          computerId: Value(computerId),
          updatedAt: Value(nowMs),
        ),
      );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
    return ids.length;
  }

  Future<List<String>> deleteForDive(String diveId) =>
      _delete((t) => t.diveId.equals(diveId));

  Future<List<String>> deleteForTank(String diveId, String tankId) =>
      _delete((t) => t.diveId.equals(diveId) & t.tankId.equals(tankId));

  /// Deletes the series [computerId] contributed; a null [computerId]
  /// matches the null-computer (manual or primary-source) rows only.
  Future<List<String>> deleteOwnedByComputer(
    String diveId,
    String? computerId,
  ) => _delete(
    (t) =>
        t.diveId.equals(diveId) &
        (computerId == null
            ? t.computerId.isNull()
            : t.computerId.equals(computerId)),
  );

  /// Deletes exactly [ids], one tombstone each. Empty input is a no-op.
  Future<List<String>> deleteByIds(List<String> ids) =>
      ids.isEmpty ? Future.value(const []) : _delete((t) => t.id.isIn(ids));

  /// Nulls `computer_id` on every series of [computerId] and restamps each
  /// (the FK's ON DELETE SET NULL would change the rows without an hlc bump,
  /// so peers would never learn). Returns the number of series touched.
  Future<int> clearComputer(String computerId, {int? now}) =>
      _setComputer(null, (t) => t.computerId.equals(computerId), now: now);

  /// Diver reassignment: a computer that now belongs to [diverId] must not
  /// stay attributed on dives the diver does not own.
  Future<int> clearComputersOfDiverForForeignDives(
    String diverId, {
    int? now,
  }) => _setComputer(
    null,
    (t) =>
        t.computerId.isInQuery(
          _db.selectOnly(_db.diveComputers)
            ..addColumns([_db.diveComputers.id])
            ..where(_db.diveComputers.diverId.equals(diverId)),
        ) &
        t.diveId.isNotInQuery(
          _db.selectOnly(_db.dives)
            ..addColumns([_db.dives.id])
            ..where(_db.dives.diverId.equals(diverId)),
        ),
    now: now,
  );

  Future<int> _setComputer(
    String? computerId,
    Expression<bool> Function($TankPressureSeriesTable t) where, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(where);
    if (ids.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(
        _db.tankPressureSeries,
      )..where((t) => t.id.isIn(ids))).write(
        TankPressureSeriesCompanion(
          computerId: Value(computerId),
          updatedAt: Value(nowMs),
        ),
      );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
    return ids.length;
  }

  /// Re-inserts [row] verbatim, `created_at`, `updated_at` and `hlc`
  /// included: consolidation undo puts back the row it captured rather than
  /// re-encoding it. When [markPending] the row is queued for sync, which
  /// restamps its hlc so the restore wins last-writer-wins on every peer.
  Future<void> restoreSeriesRow(
    TankPressureSeriesRow row, {
    bool markPending = true,
    int? now,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.tankPressureSeries)
          .insertOnConflictUpdate(row.toCompanion(false));
      // The delete that preceded a restore logged a tombstone; left in place
      // it would ride the next changeset beside the upsert and delete the
      // restored row on every peer.
      await _syncRepository.removeDeletion(
        entityType: entityType,
        recordId: row.id,
      );
      if (markPending) {
        await _syncRepository.markRecordPending(
          entityType: entityType,
          recordId: row.id,
          localUpdatedAt: now ?? DateTime.now().millisecondsSinceEpoch,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<List<String>> _delete(
    Expression<bool> Function($TankPressureSeriesTable t) where,
  ) async {
    final ids = await _ids(where);
    if (ids.isEmpty) return ids;
    // The tombstones and the delete are one logical write. A failure between
    // them would leave tombstones for rows that are still live here, and the
    // next sync would delete them on every peer.
    await _db.transaction(() async {
      for (final id in ids) {
        await _syncRepository.logDeletion(entityType: entityType, recordId: id);
      }
      // Chunked like the writers: one bound variable per id, and these
      // predicates reach beyond a single dive.
      for (final chunk in seriesIdChunks(ids)) {
        await (_db.delete(
          _db.tankPressureSeries,
        )..where((t) => t.id.isIn(chunk))).go();
      }
    });
    SyncEventBus.notifyLocalChange();
    return ids;
  }

  Future<void> _retarget(List<String> ids, String tankId, int nowMs) async {
    await _db.transaction(() async {
      await (_db.update(
        _db.tankPressureSeries,
      )..where((t) => t.id.isIn(ids))).write(
        TankPressureSeriesCompanion(
          tankId: Value(tankId),
          updatedAt: Value(nowMs),
        ),
      );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
  }

  Future<List<String>> _ids(
    Expression<bool> Function($TankPressureSeriesTable t) where,
  ) async {
    final rows =
        await (_db.selectOnly(_db.tankPressureSeries)
              ..addColumns([_db.tankPressureSeries.id])
              ..where(where(_db.tankPressureSeries)))
            .get();
    return [for (final r in rows) r.read(_db.tankPressureSeries.id)!];
  }

  Future<void> _markPending(String id, int nowMs) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: nowMs,
      );

  /// The tank twin of `ProfileSeriesRepository._decodeOrNull`: one
  /// unreadable blob skips its own series rather than failing every read
  /// that touches the dive.
  domain.TankPressureSeries? _decodeOrNull(TankPressureSeriesRow row) {
    final List<TankPressureSample> samples;
    try {
      samples = _codec.decode(row.samples);
    } on ProfileSeriesCodecException catch (e) {
      _log.warning('Skipping unreadable tankPressureSeries ${row.id}: $e');
      return null;
    }
    return domain.TankPressureSeries(
      id: row.id,
      diveId: row.diveId,
      tankId: row.tankId,
      computerId: row.computerId,
      summary: TankPressureSeriesSummary(
        sampleCount: row.sampleCount,
        startTimestamp: row.startTimestamp,
        endTimestamp: row.endTimestamp,
      ),
      samples: samples,
      codecVersion: row.codecVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      hlc: row.hlc,
    );
  }
}
