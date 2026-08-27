import 'package:drift/drift.dart' show Value, Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/repair_predicates.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

typedef RepairUndo = Future<void> Function();

/// What a repair attempt actually did.
///
/// A repair that changes nothing must say so: marking the finding resolved
/// would only have it reopened by the very next scan, and writing an
/// unchanged profile stacks another edited-profile layer for no reason.
class RepairResult {
  const RepairResult.applied([this.undo]) : changed = true;
  const RepairResult.noChange() : changed = false, undo = null;

  /// Whether anything was written.
  final bool changed;

  /// Inverse of the write, when the operation has one.
  final RepairUndo? undo;
}

/// Executes data repairs with one uniform contract: write -> single notify ->
/// mark finding resolved -> queue a targeted rescan -> return the undo
/// closure (absent when the operation has no inverse). Operations that find
/// nothing to do return [RepairResult.noChange] and leave the finding open.
class QualityRepairExecutor {
  QualityRepairExecutor({
    DiveRepository? diveRepository,
    TankPressureRepository? tankPressureRepository,
    QualityFindingsRepository? findingsRepository,
    ProfileRepairService? profileRepairService,
  }) : _diveRepo = diveRepository ?? DiveRepository(),
       _tankRepo = tankPressureRepository ?? TankPressureRepository(),
       _findings = findingsRepository ?? QualityFindingsRepository(),
       _profiles = profileRepairService ?? ProfileRepairService();

  final DiveRepository _diveRepo;
  final TankPressureRepository _tankRepo;
  final QualityFindingsRepository _findings;
  final ProfileRepairService _profiles;
  AppDatabase get _db => DatabaseService.instance.database;

  Future<void> _finish(String findingId, Iterable<String> affected) async {
    await _findings.setStatus(findingId, QualityStatus.resolved);
    scheduleQualityScan(affected);
  }

  /// Dives sharing this dive's importId (for "shift the whole import").
  /// Falls back to just the dive when it has no importId.
  Future<List<String>> divesInSameImport(String diveId) async {
    final rows = await _db
        .customSelect(
          'SELECT b.id AS id FROM dives a JOIN dives b '
          'ON a.import_id IS NOT NULL AND b.import_id = a.import_id '
          'WHERE a.id = ?1',
          variables: [Variable.withString(diveId)],
        )
        .get();
    final ids = [for (final r in rows) r.read<String>('id')];
    return ids.isEmpty ? [diveId] : ids;
  }

  Future<RepairResult> shiftTimes({
    required List<String> diveIds,
    required Duration offset,
    required String findingId,
  }) async {
    final snapshot = await _diveRepo.getDiveTimesSnapshot(diveIds);
    await _db.transaction(() => _diveRepo.bulkShiftDiveTimes(diveIds, offset));
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, diveIds);
    return RepairResult.applied(() async {
      await _db.transaction(() => _diveRepo.restoreDiveTimes(snapshot));
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan(diveIds);
    });
  }

  /// [compute] is one of ProfileRepairService's pure functions.
  ///
  /// A computed series identical to the stored one means the repair found
  /// nothing it could fix: writing it would demote the originals and insert a
  /// byte-identical copy as the new primary, and resolving the finding would
  /// only have the next scan reopen it.
  Future<RepairResult> applyProfileRepair({
    required String diveId,
    required String findingId,
    required List<domain.DiveProfilePoint> Function(
      List<domain.DiveProfilePoint>,
    )
    compute,
  }) async {
    final current = await _profiles.currentPrimaryProfile(diveId);
    if (current.isEmpty) return const RepairResult.noChange();
    final repaired = compute(current);
    if (_sameSeries(current, repaired)) return const RepairResult.noChange();
    // saveEditedProfile notifies internally.
    await _profiles.applyEdited(diveId, repaired);
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await _profiles.undo(diveId); // restoreOriginalProfile notifies
      scheduleQualityScan([diveId]);
    });
  }

  /// Whole-sample equality: DiveProfilePoint is Equatable over all of its
  /// fields, so a repair that touches any channel -- not just depth and
  /// temperature -- still counts as a change.
  static bool _sameSeries(
    List<domain.DiveProfilePoint> a,
    List<domain.DiveProfilePoint> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<RepairResult> recomputeMetrics({
    required String diveId,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    if (dive == null) return const RepairResult.noChange();
    final prior = (maxDepth: dive.maxDepth, avgDepth: dive.avgDepth);
    await _db.transaction(() => _profiles.recomputeMetrics(diveId));
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await _db.transaction(
        () => _diveRepo.bulkUpdateFields(
          [diveId],
          DivesCompanion(
            maxDepth: Value(prior.maxDepth),
            avgDepth: Value(prior.avgDepth),
          ),
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    });
  }

  /// Reinterpret the dive's recorded water temperature on the scale it was
  /// really logged on. The sample-channel equivalent goes through
  /// [applyProfileRepair] with ProfileRepairService.convertTemperature; this
  /// one rewrites the single scalar column and nothing else.
  Future<RepairResult> convertWaterTemp({
    required String diveId,
    required bool kelvinScale,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    final prior = dive?.waterTemp;
    if (prior == null) return const RepairResult.noChange();
    // Re-test convergence against the CURRENT value rather than trusting the
    // finding's params. The dive may have been corrected by hand since the
    // scan, and converting an already-plausible reading would corrupt it.
    // Refusing also subsumes the degenerate -40 case, where Celsius and
    // Fahrenheit coincide and the conversion could never change anything.
    if (!RepairPredicates.convertedChannelIsPlausible([
      prior,
    ], kelvinScale: kelvinScale)) {
      return const RepairResult.noChange();
    }
    final converted = RepairPredicates.convertToCelsius(
      prior,
      kelvinScale: kelvinScale,
    );

    Future<void> write(double value) async {
      await _db.transaction(
        () => _diveRepo.bulkUpdateFields([
          diveId,
        ], DivesCompanion(waterTemp: Value(value))),
      );
      SyncEventBus.notifyLocalChange();
    }

    await write(converted);
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await write(prior);
      scheduleQualityScan([diveId]);
    });
  }

  Future<RepairResult> swapTankRecordPressures({
    required String diveId,
    required String tankId,
    required double newStartBar,
    required double newEndBar,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _diveRepo.updateTankRecordPressures(
        diveId: diveId,
        tankId: tankId,
        startPressure: newStartBar,
        endPressure: newEndBar,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await _db.transaction(
        () => _diveRepo.updateTankRecordPressures(
          diveId: diveId,
          tankId: tankId,
          startPressure: newEndBar,
          endPressure: newStartBar,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    });
  }

  /// Set ONE endpoint of a tank record from its sensor series (the
  /// endpoint-mismatch repair). Never touches the other endpoint.
  Future<RepairResult> setTankRecordEndpoint({
    required String diveId,
    required String tankId,
    required String endpoint, // 'start' | 'end'
    required double bar,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    final tank = dive?.tanks.where((t) => t.id == tankId).firstOrNull;
    if (tank == null) return const RepairResult.noChange();
    final prior = endpoint == 'start' ? tank.startPressure : tank.endPressure;
    Future<void> write(double? value) => _db.transaction(
      () => _diveRepo.updateTankRecordPressures(
        diveId: diveId,
        tankId: tankId,
        startPressure: endpoint == 'start' ? value : null,
        endPressure: endpoint == 'end' ? value : null,
      ),
    );
    await write(bar);
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    if (prior == null) return const RepairResult.applied();
    return RepairResult.applied(() async {
      await write(prior);
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    });
  }

  Future<RepairResult> swapPressureSeries({
    required String diveId,
    required String tankIdA,
    required String tankIdB,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _tankRepo.swapTankPressureSeries(
        diveId: diveId,
        tankIdA: tankIdA,
        tankIdB: tankIdB,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await _db.transaction(
        () => _tankRepo.swapTankPressureSeries(
          diveId: diveId,
          tankIdA: tankIdA,
          tankIdB: tankIdB,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    });
  }

  Future<RepairResult> reassignPressureSeries({
    required String diveId,
    required String fromTankId,
    required String toTankId,
    required String findingId,
  }) async {
    await _db.transaction(
      () => _tankRepo.reassignTankPressureSeries(
        diveId: diveId,
        fromTankId: fromTankId,
        toTankId: toTankId,
      ),
    );
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return RepairResult.applied(() async {
      await _db.transaction(
        () => _tankRepo.reassignTankPressureSeries(
          diveId: diveId,
          fromTankId: toTankId,
          toTankId: fromTankId,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    });
  }

  Future<RepairResult> setPrimarySource({
    required String diveId,
    required String sourceId,
    required String findingId,
  }) async {
    await _diveRepo.setPrimaryDataSource(
      diveId: diveId,
      computerReadingId: sourceId,
    );
    await _finish(findingId, [diveId]);
    // set-primary has its own UI affordance to set back
    return const RepairResult.applied();
  }
}
