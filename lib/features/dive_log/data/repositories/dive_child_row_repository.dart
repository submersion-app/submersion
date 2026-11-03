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
/// same block as the write, and stamps the dive, as the dive editor's does.
/// None opens a transaction or notifies: the caller owns both.
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
  /// [values] names an order: one past the highest, since a delete leaves a
  /// gap a count would land on. Returns the new tank's id.
  Future<String> addTank(String diveId, DiveTanksCompanion values) async {
    final id = _uuid.v4();
    final order = values.tankOrder.present
        ? values.tankOrder
        : Value(await _nextTankOrder(diveId));
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
  /// the profile events that name it. SQLite cascades the series and the
  /// switches without Drift seeing a write, so the series go through their
  /// repository, which tombstones each, and the switches' tombstones are
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
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.diveWeights)
        .insert(
          _normalized(values).copyWith(
            id: Value(id),
            diveId: Value(diveId),
            createdAt: Value(now),
          ),
        );
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

  /// Adds a custom field to [diveId] from [values], after the fields it has
  /// unless [values] names an order. The repository's own
  /// `replaceFieldsForDive` marks nothing for sync, so a field written one at
  /// a time goes through here, as the dive save's diff does. Returns its id.
  Future<String> addCustomField(
    String diveId,
    DiveCustomFieldsCompanion values,
  ) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final order = values.sortOrder.present
        ? values.sortOrder
        : Value(await _nextFieldOrder(diveId));
    await _db
        .into(_db.diveCustomFields)
        .insert(
          values.copyWith(
            id: Value(id),
            diveId: Value(diveId),
            sortOrder: order,
            createdAt: Value(now),
          ),
        );
    await _sync.markRecordPending(
      entityType: 'diveCustomFields',
      recordId: id,
      localUpdatedAt: now,
    );
    await _stampDive(diveId, now: now);
    return id;
  }

  /// Writes the columns [values] names on [fieldId]. False when it has gone.
  Future<bool> updateCustomField(
    String fieldId,
    DiveCustomFieldsCompanion values,
  ) async {
    final row = await _customField(fieldId);
    if (row == null) return false;
    await (_db.update(
      _db.diveCustomFields,
    )..where((f) => f.id.equals(fieldId))).write(values);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sync.markRecordPending(
      entityType: 'diveCustomFields',
      recordId: fieldId,
      localUpdatedAt: now,
    );
    await _stampDive(row.diveId, now: now);
    return true;
  }

  /// Deletes [fieldId]. False when it has gone.
  Future<bool> deleteCustomField(String fieldId) async {
    final row = await _customField(fieldId);
    if (row == null) return false;
    await (_db.delete(
      _db.diveCustomFields,
    )..where((f) => f.id.equals(fieldId))).go();
    await _sync.logDeletion(entityType: 'diveCustomFields', recordId: fieldId);
    await _stampDive(row.diveId);
    return true;
  }

  Future<DiveCustomField?> _customField(String id) => (_db.select(
    _db.diveCustomFields,
  )..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<int> _nextFieldOrder(String diveId) async {
    final highest = _db.diveCustomFields.sortOrder.max();
    final row =
        await (_db.selectOnly(_db.diveCustomFields)
              ..addColumns([highest])
              ..where(_db.diveCustomFields.diveId.equals(diveId)))
            .getSingle();
    final max = row.read(highest);
    return max == null ? 0 : max + 1;
  }

  /// A label as every weight write stores it.
  DiveWeightsCompanion _normalized(DiveWeightsCompanion values) =>
      values.label.present
      ? values.copyWith(label: Value(normalizeWeightLabel(values.label.value)))
      : values;

  Future<DiveTank?> _tank(String id) => (_db.select(
    _db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> _nextTankOrder(String diveId) async {
    final highest = _db.diveTanks.tankOrder.max();
    final row =
        await (_db.selectOnly(_db.diveTanks)
              ..addColumns([highest])
              ..where(_db.diveTanks.diveId.equals(diveId)))
            .getSingle();
    final max = row.read(highest);
    return max == null ? 0 : max + 1;
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
