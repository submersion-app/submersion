import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// One cylinder's stored mix, located by its dive.
typedef StoredTankMix = ({String diveId, String tankId, GasMix mix});

/// Reads and rewrites cylinder mixes for the repair of mixes older imports
/// stored 100 times too high (issue #4714).
class TankGasMixRepository {
  TankGasMixRepository({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;

  /// Every cylinder whose mix no gas can have ([GasMix.isPossible]).
  Future<List<StoredTankMix>> impossibleMixes() async {
    final rows = await (_db.select(_db.diveTanks)..where(_impossible)).get();
    return [for (final row in rows) _stored(row)];
  }

  /// The dives [impossibleMixes] would name, read by id alone, for the
  /// quality scan's prefilter: one rule for both, so they cannot drift.
  Future<Set<String>> divesWithImpossibleMixes() async {
    final t = _db.diveTanks;
    final query = _db.selectOnly(t, distinct: true)
      ..addColumns([t.diveId])
      ..where(_impossible(t));
    return {for (final row in await query.get()) row.read(t.diveId)!};
  }

  /// [GasMix.isPossible] negated, in SQL. Negating is safe here, where the
  /// Dart rule could not be: SQLite stores a NaN only as NULL, which these
  /// columns refuse, and an infinite share breaks a bound.
  static Expression<bool> _impossible($DiveTanksTable t) {
    const tolerance = GasMix.tolerancePercent;
    return t.o2Percent.isSmallerThanValue(-tolerance) |
        t.hePercent.isSmallerThanValue(-tolerance) |
        t.o2Percent.isBiggerThanValue(100 + tolerance) |
        t.hePercent.isBiggerThanValue(100 + tolerance) |
        (t.o2Percent + t.hePercent).isBiggerThanValue(100 + tolerance);
  }

  /// [tankId]'s mix, or null when it is not a cylinder of [diveId].
  Future<StoredTankMix?> tankMix({
    required String diveId,
    required String tankId,
  }) async {
    final row =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.id.equals(tankId) & t.diveId.equals(diveId)))
            .getSingleOrNull();
    return row == null ? null : _stored(row);
  }

  /// Writes each cylinder's mix under a new clock and marks it and its dive
  /// pending, so every device takes the write. One update per distinct mix
  /// and one set-based mark per table: a logbook stored 100 times too high
  /// holds hundreds of cylinders but only a handful of gases. The caller
  /// owns the transaction and the change notification.
  Future<void> setGasMixes(List<StoredTankMix> mixes) async {
    if (mixes.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final tanksByMix = <GasMix, List<String>>{};
    for (final m in mixes) {
      (tanksByMix[m.mix] ??= []).add(m.tankId);
    }
    for (final MapEntry(key: mix, value: tankIds) in tanksByMix.entries) {
      for (final chunk in seriesIdChunks(tankIds)) {
        // child-clock: markRecordsPending below stamps every row's clock.
        await (_db.update(_db.diveTanks)..where((t) => t.id.isIn(chunk))).write(
          DiveTanksCompanion(
            o2Percent: Value(mix.o2),
            hePercent: Value(mix.he),
          ),
        );
      }
    }
    final diveIds = {for (final m in mixes) m.diveId}.toList();
    for (final chunk in seriesIdChunks(diveIds)) {
      await (_db.update(_db.dives)..where((t) => t.id.isIn(chunk))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
    }
    await _sync.markRecordsPending(
      entityType: 'diveTanks',
      recordIds: [for (final m in mixes) m.tankId],
      localUpdatedAt: now,
    );
    await _sync.markRecordsPending(
      entityType: 'dives',
      recordIds: diveIds,
      localUpdatedAt: now,
    );
  }

  static StoredTankMix _stored(DiveTank row) => (
    diveId: row.diveId,
    tankId: row.id,
    mix: GasMix(o2: row.o2Percent, he: row.hePercent),
  );
}
