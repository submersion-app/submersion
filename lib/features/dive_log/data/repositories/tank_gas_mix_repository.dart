import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
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
    final rows =
        await (_db.select(_db.diveTanks)..where(
              (t) =>
                  t.o2Percent.isSmallerThanValue(0) |
                  t.hePercent.isSmallerThanValue(0) |
                  t.o2Percent.isBiggerThanValue(100) |
                  t.hePercent.isBiggerThanValue(100) |
                  (t.o2Percent + t.hePercent).isBiggerThanValue(
                    100 + GasMix.sumTolerancePercent,
                  ),
            ))
            .get();
    return [for (final row in rows) _stored(row)];
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
  /// pending, so every device takes the write. Each dive is touched once.
  /// The caller owns the transaction and the change notification.
  Future<void> setGasMixes(List<StoredTankMix> mixes) async {
    if (mixes.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m in mixes) {
      await (_db.update(
        _db.diveTanks,
      )..where((t) => t.id.equals(m.tankId))).write(
        DiveTanksCompanion(
          o2Percent: Value(m.mix.o2),
          hePercent: Value(m.mix.he),
          hlc: Value(await _sync.issueRowClock()),
        ),
      );
      await _pending('diveTanks', m.tankId, now);
    }
    for (final diveId in {for (final m in mixes) m.diveId}) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _pending('dives', diveId, now);
    }
  }

  static StoredTankMix _stored(DiveTank row) => (
    diveId: row.diveId,
    tankId: row.id,
    mix: GasMix(o2: row.o2Percent, he: row.hePercent),
  );

  Future<void> _pending(String entityType, String id, int now) =>
      _sync.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
}
