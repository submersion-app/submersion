import 'package:drift/drift.dart' show Value, Variable;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

typedef RepairUndo = Future<void> Function();

/// Executes data repairs with one uniform contract: write -> single notify ->
/// mark finding resolved -> queue a targeted rescan -> return an undo
/// closure (null when the operation has no inverse).
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

  Future<RepairUndo?> shiftTimes({
    required List<String> diveIds,
    required Duration offset,
    required String findingId,
  }) async {
    final snapshot = await _diveRepo.getDiveTimesSnapshot(diveIds);
    await _db.transaction(() => _diveRepo.bulkShiftDiveTimes(diveIds, offset));
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, diveIds);
    return () async {
      await _db.transaction(() => _diveRepo.restoreDiveTimes(snapshot));
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan(diveIds);
    };
  }

  /// [compute] is one of ProfileRepairService's pure functions.
  Future<RepairUndo?> applyProfileRepair({
    required String diveId,
    required String findingId,
    required List<domain.DiveProfilePoint> Function(
      List<domain.DiveProfilePoint>,
    )
    compute,
  }) async {
    final current = await _profiles.currentPrimaryProfile(diveId);
    if (current.isEmpty) return null;
    // saveEditedProfile notifies internally.
    await _profiles.applyEdited(diveId, compute(current));
    await _finish(findingId, [diveId]);
    return () async {
      await _profiles.undo(diveId); // restoreOriginalProfile notifies
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> recomputeMetrics({
    required String diveId,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    if (dive == null) return null;
    final prior = (maxDepth: dive.maxDepth, avgDepth: dive.avgDepth);
    await _db.transaction(() => _profiles.recomputeMetrics(diveId));
    SyncEventBus.notifyLocalChange();
    await _finish(findingId, [diveId]);
    return () async {
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
    };
  }

  Future<RepairUndo?> swapTankRecordPressures({
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
    return () async {
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
    };
  }

  /// Set ONE endpoint of a tank record from its sensor series (the
  /// endpoint-mismatch repair). Never touches the other endpoint.
  Future<RepairUndo?> setTankRecordEndpoint({
    required String diveId,
    required String tankId,
    required String endpoint, // 'start' | 'end'
    required double bar,
    required String findingId,
  }) async {
    final dive = await _diveRepo.getDiveById(diveId);
    final tank = dive?.tanks.where((t) => t.id == tankId).firstOrNull;
    if (tank == null) return null;
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
    if (prior == null) return null;
    return () async {
      await write(prior);
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> swapPressureSeries({
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
    return () async {
      await _db.transaction(
        () => _tankRepo.swapTankPressureSeries(
          diveId: diveId,
          tankIdA: tankIdA,
          tankIdB: tankIdB,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> reassignPressureSeries({
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
    return () async {
      await _db.transaction(
        () => _tankRepo.reassignTankPressureSeries(
          diveId: diveId,
          fromTankId: toTankId,
          toTankId: fromTankId,
        ),
      );
      SyncEventBus.notifyLocalChange();
      scheduleQualityScan([diveId]);
    };
  }

  Future<RepairUndo?> setPrimarySource({
    required String diveId,
    required String sourceId,
    required String findingId,
  }) async {
    await _diveRepo.setPrimaryDataSource(
      diveId: diveId,
      computerReadingId: sourceId,
    );
    await _finish(findingId, [diveId]);
    return null; // set-primary has its own UI affordance to set back
  }
}
