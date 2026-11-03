import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

/// Writes one tank or weight row of a dive, leaving the dive's other rows as
/// they were. The bulk operations replace a whole list under fresh ids, which
/// drops every tank's pressure series and gas switches, and a dive save
/// rewrites the dive from an entity, so a change to one row goes through here.
/// Each write marks its own row pending, which moves the row's clock, in the
/// same block as the write, and stamps the dive, as the dive editor's does. None opens a transaction or notifies: the caller owns both.
class DiveChildRowRepository {
  DiveChildRowRepository({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database),
      _series = TankPressureSeriesRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;
  final TankPressureSeriesRepository _series;
  static const _uuid = Uuid();

  /// Adds a tank to [diveId] from [values], after the tanks it has unless
  /// [values] names an order. Returns the new tank's id.
  Future<String> addTank(String diveId, DiveTanksCompanion values) async {
    final id = _uuid.v4();
    final order = values.tankOrder.present
        ? values.tankOrder
        : Value(await _count(_db.diveTanks, _db.diveTanks.diveId, diveId));
    await _db
        .into(_db.diveTanks)
        .insert(
          values.copyWith(
            id: Value(id),
            diveId: Value(diveId),
            tankOrder: order,
          ),
        );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
    await _stampDive(diveId, now: now);
    return id;
  }

  /// Writes the columns [values] names on [tankId]. A role set here is the
  /// diver's, whatever a transmitter's name said (issue #2595). False when the
  /// tank has gone.
  Future<bool> updateTank(String tankId, DiveTanksCompanion values) async {
    final row = await _tank(tankId);
    if (row == null) return false;
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankId))).write(
      values.tankRole.present
          ? values.copyWith(roleSource: const Value(null))
          : values,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sync.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankId,
      localUpdatedAt: now,
    );
    await _stampDive(row.diveId, now: now);
    return true;
  }

  /// Deletes [tankId] with its pressure series and gas switches, and clears
  /// the profile events that name it. SQLite
  /// cascades both without Drift seeing a write, so the series go through
  /// their repository, which tombstones each, and the switches' tombstones are
  /// logged here, as a dive save does (issue #32). False when the tank has
  /// gone.
  Future<bool> deleteTank(String tankId) async {
    final row = await _tank(tankId);
    if (row == null) return false;
    await _series.deleteForTank(row.diveId, tankId);
    final switches = await (_db.select(
      _db.gasSwitches,
    )..where((s) => s.tankId.equals(tankId))).get();
    await (_db.delete(_db.diveTanks)..where((t) => t.id.equals(tankId))).go();
    // A profile event names its gas by tank with no foreign key, so nothing
    // clears the link but this.
    final now = DateTime.now().millisecondsSinceEpoch;
    final events = await (_db.select(
      _db.diveProfileEvents,
    )..where((e) => e.tankId.equals(tankId))).get();
    for (final event in events) {
      await (_db.update(_db.diveProfileEvents)
            ..where((e) => e.id.equals(event.id)))
          .write(const DiveProfileEventsCompanion(tankId: Value(null)));
      await _sync.markRecordPending(
        entityType: 'diveProfileEvents',
        recordId: event.id,
        localUpdatedAt: now,
      );
    }
    await _sync.logDeletion(entityType: 'diveTanks', recordId: tankId);
    await _sync.logDeletions(
      entityType: 'gasSwitches',
      recordIds: [for (final s in switches) s.id],
    );
    await _stampDive(row.diveId, now: now);
    return true;
  }

  /// Adds a weight to [diveId] from [values]. Returns the new weight's id.
  Future<String> addWeight(String diveId, DiveWeightsCompanion values) async {
    final id = _uuid.v4();
    await _db
        .into(_db.diveWeights)
        .insert(
          _normalized(values).copyWith(
            id: Value(id),
            diveId: Value(diveId),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sync.markRecordPending(
      entityType: 'diveWeights',
      recordId: id,
      localUpdatedAt: now,
    );
    await _stampDive(diveId, now: now);
    return id;
  }

  /// Writes the columns [values] names on [weightId]. False when it has gone.
  Future<bool> updateWeight(
    String weightId,
    DiveWeightsCompanion values,
  ) async {
    final row = await (_db.select(
      _db.diveWeights,
    )..where((w) => w.id.equals(weightId))).getSingleOrNull();
    if (row == null) return false;
    await (_db.update(
      _db.diveWeights,
    )..where((w) => w.id.equals(weightId))).write(_normalized(values));
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sync.markRecordPending(
      entityType: 'diveWeights',
      recordId: weightId,
      localUpdatedAt: now,
    );
    await _stampDive(row.diveId, now: now);
    return true;
  }

  /// Deletes [weightId]. False when it has gone.
  Future<bool> deleteWeight(String weightId) async {
    final row = await (_db.select(
      _db.diveWeights,
    )..where((w) => w.id.equals(weightId))).getSingleOrNull();
    if (row == null) return false;
    await (_db.delete(
      _db.diveWeights,
    )..where((w) => w.id.equals(weightId))).go();
    await _sync.logDeletion(entityType: 'diveWeights', recordId: weightId);
    await _stampDive(row.diveId);
    return true;
  }

  /// A label as every weight write stores it.
  DiveWeightsCompanion _normalized(DiveWeightsCompanion values) =>
      values.label.present
      ? values.copyWith(label: Value(normalizeWeightLabel(values.label.value)))
      : values;

  Future<DiveTank?> _tank(String id) => (_db.select(
    _db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> _count(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> column,
    String value,
  ) async {
    final count = column.count();
    final row =
        await (_db.selectOnly(table)
              ..addColumns([count])
              ..where(column.equals(value)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _stampDive(String diveId, {int? now}) async {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.dives)..where((d) => d.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(at)),
    );
    await _sync.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: at,
    );
  }
}
