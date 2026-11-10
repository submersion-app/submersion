import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_child_row_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

/// Merges a dive's duplicate rows of one cylinder into the row that stays
/// (issue #4393). Modelled on TankRoleRepairRepository.useAsBailout, which
/// merges an as-imported cylinder into a re-roled one.
///
/// None of it opens a transaction or notifies: the caller owns both, and the
/// change log operation that makes the merge revertible.
class DuplicateCylinderRepository {
  DuplicateCylinderRepository({AppDatabase? database})
    : _database = database,
      _sync = SyncRepository(database: database),
      _series = TankPressureSeriesRepository(database: database),
      _childRows = DiveChildRowRepository(database: database);

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
  final SyncRepository _sync;
  final TankPressureSeriesRepository _series;
  final DiveChildRowRepository _childRows;

  /// Merges [duplicateIds] into [survivorId] on [diveId]:
  ///
  /// 1. The survivor takes each detail it lacks (volume, working pressure,
  ///    name, preset, material, transmitter serial, gear, regulator, extra
  ///    regulator, passport and trip cylinder links, record start and end
  ///    pressures) from the first duplicate that has it, [mix] when given, and every duplicate's computer among the
  ///    computers that shared it, so a later Split of that source still finds
  ///    a cylinder to take.
  /// 2. When the survivor has no pressure series, the first duplicate that has
  ///    one hands it over with its start and end pressures (never its
  ///    sourceTankIndex, which belongs to the duplicate's computer); both
  ///    read the same transmitter, so any other duplicate series is
  ///    redundant.
  /// 3. Gas switches and profile events naming a duplicate name the survivor.
  /// 4. Each duplicate is deleted with its remaining series, tombstoned.
  ///
  /// False when the survivor or every duplicate has gone (a stale finding).
  Future<bool> mergeInto({
    required String diveId,
    required String survivorId,
    required List<String> duplicateIds,
    ({double o2, double he})? mix,
    required int now,
  }) async {
    final survivor = await _tank(diveId, survivorId);
    final duplicates = [
      for (final id in duplicateIds)
        if (id != survivorId) ?await _tank(diveId, id),
    ];
    if (survivor == null || duplicates.isEmpty) return false;

    T? firstOf<T>(T? own, T? Function(DiveTank) pick) {
      if (own != null) return own;
      for (final d in duplicates) {
        final value = pick(d);
        if (value != null) return value;
      }
      return null;
    }

    final shared = <String>{
      ...?decodeSharedComputerIds(survivor.sharedComputerIds),
      for (final d in duplicates) ...[
        ?d.computerId,
        ...?decodeSharedComputerIds(d.sharedComputerIds),
      ],
    }..remove(survivor.computerId);

    var update = DiveTanksCompanion(
      volume: Value(firstOf(survivor.volume, (d) => d.volume)),
      workingPressure: Value(
        firstOf(survivor.workingPressure, (d) => d.workingPressure),
      ),
      tankName: Value(firstOf(survivor.tankName, (d) => d.tankName)),
      presetName: Value(firstOf(survivor.presetName, (d) => d.presetName)),
      equipmentId: Value(firstOf(survivor.equipmentId, (d) => d.equipmentId)),
      regulatorEquipmentId: Value(
        firstOf(survivor.regulatorEquipmentId, (d) => d.regulatorEquipmentId),
      ),
      transmitterSerial: Value(
        firstOf(survivor.transmitterSerial, (d) => d.transmitterSerial),
      ),
      extraRegulatorIds: Value(
        firstOf(survivor.extraRegulatorIds, (d) => d.extraRegulatorIds),
      ),
      tankMaterial: Value(
        firstOf(survivor.tankMaterial, (d) => d.tankMaterial),
      ),
      passportId: Value(firstOf(survivor.passportId, (d) => d.passportId)),
      twinPassportId: Value(
        firstOf(survivor.twinPassportId, (d) => d.twinPassportId),
      ),
      tripCylinderId: Value(
        firstOf(survivor.tripCylinderId, (d) => d.tripCylinderId),
      ),
      startPressure: Value(
        firstOf(survivor.startPressure, (d) => d.startPressure),
      ),
      endPressure: Value(firstOf(survivor.endPressure, (d) => d.endPressure)),
      sharedComputerIds: Value(encodeSharedComputerIds(shared)),
      o2Percent: mix == null ? const Value.absent() : Value(mix.o2),
      hePercent: mix == null ? const Value.absent() : Value(mix.he),
    );

    if (!await _hasSeries(diveId, survivorId)) {
      for (final d in duplicates) {
        if (!await _hasSeries(diveId, d.id)) continue;
        await _series.reassignTank(diveId, d.id, survivorId, now: now);
        // The survivor keeps its own sourceTankIndex: it is the parsed-tank
        // identity for the survivor's computer, not the duplicate's.
        // A series' own record pressures win; with none, the survivor keeps
        // what it had rather than being cleared.
        update = update.copyWith(
          startPressure: Value(d.startPressure ?? survivor.startPressure),
          endPressure: Value(d.endPressure ?? survivor.endPressure),
        );
        break;
      }
    }

    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(survivorId)))
        .write(update.copyWith(hlc: Value(await _sync.issueRowClock())));
    await _pending('diveTanks', survivorId, now);

    final ids = [for (final d in duplicates) d.id];
    final switches = await (_db.select(
      _db.gasSwitches,
    )..where((s) => s.tankId.isIn(ids))).get();
    for (final sw in switches) {
      await (_db.update(
        _db.gasSwitches,
      )..where((s) => s.id.equals(sw.id))).write(
        GasSwitchesCompanion(
          tankId: Value(survivorId),
          hlc: Value(await _sync.issueRowClock()),
        ),
      );
      await _pending('gasSwitches', sw.id, now);
    }
    final events = await (_db.select(
      _db.diveProfileEvents,
    )..where((e) => e.tankId.isIn(ids))).get();
    for (final event in events) {
      await (_db.update(
        _db.diveProfileEvents,
      )..where((e) => e.id.equals(event.id))).write(
        DiveProfileEventsCompanion(
          tankId: Value(survivorId),
          hlc: Value(await _sync.issueRowClock()),
        ),
      );
      await _pending('diveProfileEvents', event.id, now);
    }

    for (final id in ids) {
      await _childRows.deleteTank(id);
    }
    return true;
  }

  Future<DiveTank?> _tank(String diveId, String id) => (_db.select(
    _db.diveTanks,
  )..where((t) => t.id.equals(id) & t.diveId.equals(diveId))).getSingleOrNull();

  Future<bool> _hasSeries(String diveId, String tankId) async {
    final row =
        await (_db.select(_db.tankPressureSeries)
              ..where((s) => s.diveId.equals(diveId) & s.tankId.equals(tankId))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> _pending(String entityType, String id, int now) =>
      _sync.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
}
