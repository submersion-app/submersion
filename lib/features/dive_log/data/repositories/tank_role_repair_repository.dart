import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/services/as_imported_gas_cylinder.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';

/// What [TankRoleRepairRepository.useAsBailout] changed, for undo.
typedef UseAsBailoutUndo = ({
  /// The rows as they were: the re-roled tank, and a merged cylinder.
  List<DiveTank> tankRows,

  /// Switches moved off the merged cylinder, as they were.
  List<GasSwitche> retargetedSwitches,
});

/// Makes a name-derived CCR transmitter tank the bailout (issue #3307).
class TankRoleRepairRepository {
  TankRoleRepairRepository({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database),
      _pressures = TankPressureRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;
  final TankPressureRepository _pressures;

  /// Re-roles [tankId] to [ocTankId]'s open-circuit role (bailout when that
  /// cylinder is gone; see [openCircuitTargetRole]), clears its role source
  /// and takes [ocTankId]'s mix. When [ocTankId] is an as-imported gas cylinder of the
  /// same computer, it is merged in: its switches move to [tankId] first
  /// (deleting a tank cascades to its switches), then it is deleted and
  /// tombstoned. Null when [tankId] is gone or its role is not name-derived.
  /// The caller owns the transaction and the change notification.
  Future<({bool merged, TankRole role, UseAsBailoutUndo undo})?> useAsBailout({
    required String diveId,
    required String tankId,
    required String ocTankId,
  }) async {
    final tank = await _tank(diveId, tankId);
    if (tank == null || tank.roleSource == null) return null;
    final oc = await _tank(diveId, ocTankId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final role = openCircuitTargetRole(oc?.tankRole);

    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankId))).write(
      DiveTanksCompanion(
        tankRole: Value(role.name),
        roleSource: const Value(null),
        o2Percent: oc == null ? const Value.absent() : Value(oc.o2Percent),
        hePercent: oc == null ? const Value.absent() : Value(oc.hePercent),
        hlc: Value(await _sync.issueRowClock()),
      ),
    );
    await _pending('diveTanks', tankId, now);

    final merge =
        oc != null &&
        oc.computerId == tank.computerId &&
        isAsImportedGasCylinder(
          _asDomain(oc),
          hasPressureSeries: await _pressures.hasTankSeries(diveId, ocTankId),
        );
    var moved = const <GasSwitche>[];
    if (merge) {
      moved = await (_db.select(
        _db.gasSwitches,
      )..where((s) => s.tankId.equals(ocTankId))).get();
      for (final sw in moved) {
        await (_db.update(
          _db.gasSwitches,
        )..where((s) => s.id.equals(sw.id))).write(
          GasSwitchesCompanion(
            tankId: Value(tankId),
            hlc: Value(await _sync.issueRowClock()),
          ),
        );
        await _pending('gasSwitches', sw.id, now);
      }
      await (_db.delete(
        _db.diveTanks,
      )..where((t) => t.id.equals(ocTankId))).go();
      await _sync.logDeletion(entityType: 'diveTanks', recordId: ocTankId);
    }
    await _touchDive(diveId, now);

    return (
      merged: merge,
      role: role,
      undo: (tankRows: [tank, if (merge) oc], retargetedSwitches: moved),
    );
  }

  /// Puts back what [useAsBailout] changed: a merged cylinder returns first,
  /// so its switches have a tank to point at again.
  Future<void> undoUseAsBailout(UseAsBailoutUndo undo) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in undo.tankRows) {
      await _db.into(_db.diveTanks).insertOnConflictUpdate(row);
      // A merged cylinder's tombstone would delete it again on every other
      // device once it syncs.
      await _sync.removeDeletion(entityType: 'diveTanks', recordId: row.id);
      await _pending('diveTanks', row.id, now);
    }
    for (final sw in undo.retargetedSwitches) {
      await (_db.update(
        _db.gasSwitches,
      )..where((s) => s.id.equals(sw.id))).write(
        GasSwitchesCompanion(
          tankId: Value(sw.tankId),
          hlc: Value(await _sync.issueRowClock()),
        ),
      );
      await _pending('gasSwitches', sw.id, now);
    }
    final dives = {for (final r in undo.tankRows) r.diveId};
    for (final diveId in dives) {
      await _touchDive(diveId, now);
    }
  }

  Future<DiveTank?> _tank(String diveId, String id) => (_db.select(
    _db.diveTanks,
  )..where((t) => t.id.equals(id) & t.diveId.equals(diveId))).getSingleOrNull();

  static domain.DiveTank _asDomain(DiveTank row) => domain.DiveTank(
    id: row.id,
    name: row.tankName,
    volume: row.volume,
    presetName: row.presetName,
    order: row.tankOrder,
    computerId: row.computerId,
    transmitterSerial: row.transmitterSerial,
    equipmentId: row.equipmentId,
    sourceTankIndex: row.sourceTankIndex,
  );

  Future<void> _pending(String entityType, String id, int now) =>
      _sync.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );

  Future<void> _touchDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _pending('dives', diveId, now);
  }
}
