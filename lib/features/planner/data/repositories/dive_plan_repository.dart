import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// Denormalized summary numbers written on save so the saved-plans list
/// renders without running the engine per row.
class PlanSummaryData {
  final double maxDepth;
  final int runtimeSeconds;
  final int? ttsSeconds;

  const PlanSummaryData({
    required this.maxDepth,
    required this.runtimeSeconds,
    this.ttsSeconds,
  });
}

/// Persistence for saved dive plans (plan + tanks + segments), with full
/// sync participation: every write marks records pending with a fresh HLC,
/// every delete writes a per-row tombstone.
class DivePlanRepository {
  db.AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DivePlanRepository);

  /// Fires on any change to the three plan tables.
  Stream<void> watchPlanChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.divePlans,
      _db.divePlanTanks,
      _db.divePlanSegments,
    ]),
  );

  /// Upserts the plan and its children; children removed since the last save
  /// are deleted WITH per-row tombstones (parent-surviving child deletes
  /// must tombstone individually or other devices resurrect them).
  Future<void> savePlan(
    domain.DivePlan plan, {
    PlanSummaryData? summary,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final removedTankIds = <String>[];
    final removedSegmentIds = <String>[];

    try {
      await _db.transaction(() async {
        final existingTankIds =
            (await (_db.select(
                  _db.divePlanTanks,
                )..where((t) => t.planId.equals(plan.id))).get())
                .map((r) => r.id)
                .toSet();
        final existingSegmentIds =
            (await (_db.select(
                  _db.divePlanSegments,
                )..where((t) => t.planId.equals(plan.id))).get())
                .map((r) => r.id)
                .toSet();

        await _db
            .into(_db.divePlans)
            .insertOnConflictUpdate(_planCompanion(plan, now, summary));

        for (var i = 0; i < plan.tanks.length; i++) {
          await _db
              .into(_db.divePlanTanks)
              .insertOnConflictUpdate(
                _tankCompanion(plan.tanks[i], plan.id, i, now),
              );
        }
        for (var i = 0; i < plan.segments.length; i++) {
          await _db
              .into(_db.divePlanSegments)
              .insertOnConflictUpdate(
                _segmentCompanion(plan.segments[i], plan.id, i, now),
              );
        }

        final keptTankIds = plan.tanks.map((t) => t.id).toSet();
        final keptSegmentIds = plan.segments.map((s) => s.id).toSet();
        removedSegmentIds.addAll(existingSegmentIds.difference(keptSegmentIds));
        removedTankIds.addAll(existingTankIds.difference(keptTankIds));

        // Segments before tanks: segments FK-reference tanks.
        for (final id in removedSegmentIds) {
          await (_db.delete(
            _db.divePlanSegments,
          )..where((t) => t.id.equals(id))).go();
        }
        for (final id in removedTankIds) {
          await (_db.delete(
            _db.divePlanTanks,
          )..where((t) => t.id.equals(id))).go();
        }
      });

      // Sync bookkeeping AFTER the transaction commits so a rollback leaves
      // no stray pending markers or tombstones.
      await _syncRepository.markRecordPending(
        entityType: 'divePlans',
        recordId: plan.id,
        localUpdatedAt: now,
      );
      for (final tank in plan.tanks) {
        await _syncRepository.markRecordPending(
          entityType: 'divePlanTanks',
          recordId: tank.id,
          localUpdatedAt: now,
        );
      }
      for (final segment in plan.segments) {
        await _syncRepository.markRecordPending(
          entityType: 'divePlanSegments',
          recordId: segment.id,
          localUpdatedAt: now,
        );
      }
      for (final id in removedSegmentIds) {
        await _syncRepository.logDeletion(
          entityType: 'divePlanSegments',
          recordId: id,
        );
      }
      for (final id in removedTankIds) {
        await _syncRepository.logDeletion(
          entityType: 'divePlanTanks',
          recordId: id,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save plan ${plan.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.DivePlan?> getPlan(String id) async {
    try {
      final row = await (_db.select(
        _db.divePlans,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return null;

      final tankRows =
          await (_db.select(_db.divePlanTanks)
                ..where((t) => t.planId.equals(id))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();
      final segmentRows =
          await (_db.select(_db.divePlanSegments)
                ..where((t) => t.planId.equals(id))
                ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
              .get();

      return _mapPlan(row, tankRows, segmentRows);
    } catch (e, stackTrace) {
      _log.error('Failed to load plan $id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// The plan converted into [diveId] via convert-to-dive, or null.
  /// Backs the plan-vs-actual overlay on the dive detail chart.
  Future<domain.DivePlan?> getPlanByLinkedDiveId(String diveId) async {
    try {
      // Newest first: a duplicated plan can share the link, take the latest.
      final rows =
          await (_db.select(_db.divePlans)
                ..where((t) => t.linkedDiveId.equals(diveId))
                ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
                ..limit(1))
              .get();
      if (rows.isEmpty) return null;
      return getPlan(rows.first.id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load plan linked to dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<domain.DivePlanSummary>> getAllPlanSummaries() async {
    final rows = await (_db.select(
      _db.divePlans,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    return rows
        .map(
          (r) => domain.DivePlanSummary(
            id: r.id,
            name: r.name,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
            maxDepth: r.summaryMaxDepth,
            runtimeSeconds: r.summaryRuntimeSeconds,
            ttsSeconds: r.summaryTtsSeconds,
            mode: domain.PlanMode.values.byName(r.mode),
          ),
        )
        .toList();
  }

  Future<void> deletePlan(String id) async {
    try {
      final tankIds = (await (_db.select(
        _db.divePlanTanks,
      )..where((t) => t.planId.equals(id))).get()).map((r) => r.id).toList();
      final segmentIds = (await (_db.select(
        _db.divePlanSegments,
      )..where((t) => t.planId.equals(id))).get()).map((r) => r.id).toList();

      await _db.transaction(() async {
        await (_db.delete(
          _db.divePlanSegments,
        )..where((t) => t.planId.equals(id))).go();
        await (_db.delete(
          _db.divePlanTanks,
        )..where((t) => t.planId.equals(id))).go();
        await (_db.delete(_db.divePlans)..where((t) => t.id.equals(id))).go();
      });

      for (final segmentId in segmentIds) {
        await _syncRepository.logDeletion(
          entityType: 'divePlanSegments',
          recordId: segmentId,
        );
      }
      for (final tankId in tankIds) {
        await _syncRepository.logDeletion(
          entityType: 'divePlanTanks',
          recordId: tankId,
        );
      }
      await _syncRepository.logDeletion(entityType: 'divePlans', recordId: id);
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to delete plan $id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Copies a plan (new ids everywhere, segments' tank references remapped to
  /// the new tank ids, name suffixed). Returns the new plan, or null when the
  /// source does not exist.
  Future<domain.DivePlan?> duplicatePlan(String id) async {
    final source = await getPlan(id);
    if (source == null) return null;

    final now = DateTime.now();
    final tankIdMap = {for (final t in source.tanks) t.id: _uuid.v4()};
    final newTanks = source.tanks
        .map((t) => t.copyWith(id: tankIdMap[t.id]))
        .toList();
    final newSegments = source.segments
        .map(
          (s) => s.copyWith(
            id: _uuid.v4(),
            tankId: tankIdMap[s.tankId] ?? s.tankId,
            switchToTankId: s.switchToTankId != null
                ? tankIdMap[s.switchToTankId]
                : null,
            clearSwitchToTankId: s.switchToTankId == null,
          ),
        )
        .toList();

    final copy = source.copyWith(
      id: _uuid.v4(),
      name: '${source.name} (copy)',
      createdAt: now,
      updatedAt: now,
      tanks: newTanks,
      segments: newSegments,
      clearLinkedDiveId: true,
    );
    final sourceRow = await (_db.select(
      _db.divePlans,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    await savePlan(
      copy,
      summary: sourceRow?.summaryMaxDepth != null
          ? PlanSummaryData(
              maxDepth: sourceRow!.summaryMaxDepth!,
              runtimeSeconds: sourceRow.summaryRuntimeSeconds ?? 0,
              ttsSeconds: sourceRow.summaryTtsSeconds,
            )
          : null,
    );
    return copy;
  }

  // ---- mapping ----

  db.DivePlansCompanion _planCompanion(
    domain.DivePlan plan,
    int now,
    PlanSummaryData? summary,
  ) {
    return db.DivePlansCompanion(
      id: Value(plan.id),
      name: Value(plan.name),
      notes: Value(plan.notes),
      mode: Value(plan.mode.name),
      siteId: Value(plan.siteId),
      sourceDiveId: Value(plan.sourceDiveId),
      linkedDiveId: Value(plan.linkedDiveId),
      altitude: Value(plan.altitude),
      waterType: Value(plan.waterType?.name),
      gfLow: Value(plan.gfLow),
      gfHigh: Value(plan.gfHigh),
      descentRate: Value(plan.descentRate),
      ascentRate: Value(plan.ascentRate),
      lastStopDepth: Value(plan.lastStopDepth),
      gasSwitchStopSeconds: Value(plan.gasSwitchStopSeconds),
      airBreakO2Seconds: Value(plan.airBreaks?.o2Seconds),
      airBreakBreakSeconds: Value(plan.airBreaks?.breakSeconds),
      sacBottom: Value(plan.sacBottom),
      sacDeco: Value(plan.sacDeco),
      sacStressed: Value(plan.sacStressed),
      reservePressure: Value(plan.reservePressure),
      surfaceIntervalSeconds: Value(plan.surfaceInterval?.inSeconds),
      setpointLow: Value(plan.setpointLow),
      setpointHigh: Value(plan.setpointHigh),
      setpointSwitchDepth: Value(plan.setpointSwitchDepth),
      deviationDepthDelta: Value(plan.deviationDepthDelta),
      deviationTimeMinutes: Value(plan.deviationTimeMinutes),
      turnPressureRule: Value(plan.turnPressureRule?.name),
      turnPressureFraction: Value(plan.turnPressureFraction),
      summaryMaxDepth: summary != null
          ? Value(summary.maxDepth)
          : const Value.absent(),
      summaryRuntimeSeconds: summary != null
          ? Value(summary.runtimeSeconds)
          : const Value.absent(),
      summaryTtsSeconds: summary != null
          ? Value(summary.ttsSeconds)
          : const Value.absent(),
      createdAt: Value(plan.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(now),
    );
  }

  db.DivePlanTanksCompanion _tankCompanion(
    DiveTank tank,
    String planId,
    int sortOrder,
    int now,
  ) {
    return db.DivePlanTanksCompanion(
      id: Value(tank.id),
      planId: Value(planId),
      name: Value(tank.name),
      volume: Value(tank.volume),
      workingPressure: Value(tank.workingPressure),
      startPressure: Value(tank.startPressure),
      gasO2: Value(tank.gasMix.o2),
      gasHe: Value(tank.gasMix.he),
      role: Value(tank.role.name),
      material: Value(tank.material?.name),
      presetName: Value(tank.presetName),
      sortOrder: Value(sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  db.DivePlanSegmentsCompanion _segmentCompanion(
    PlanSegment segment,
    String planId,
    int sortOrder,
    int now,
  ) {
    return db.DivePlanSegmentsCompanion(
      id: Value(segment.id),
      planId: Value(planId),
      type: Value(segment.type.name),
      startDepth: Value(segment.startDepth),
      endDepth: Value(segment.endDepth),
      durationSeconds: Value(segment.durationSeconds),
      tankId: Value(segment.tankId),
      gasO2: Value(segment.gasMix.o2),
      gasHe: Value(segment.gasMix.he),
      rate: Value(segment.rate),
      switchToTankId: Value(segment.switchToTankId),
      sortOrder: Value(sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  domain.DivePlan _mapPlan(
    db.DivePlan row,
    List<db.DivePlanTank> tankRows,
    List<db.DivePlanSegment> segmentRows,
  ) {
    return domain.DivePlan(
      id: row.id,
      name: row.name,
      notes: row.notes,
      siteId: row.siteId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      mode: domain.PlanMode.values.byName(row.mode),
      altitude: row.altitude,
      waterType: row.waterType != null
          ? WaterType.values.byName(row.waterType!)
          : null,
      gfLow: row.gfLow,
      gfHigh: row.gfHigh,
      descentRate: row.descentRate,
      ascentRate: row.ascentRate,
      lastStopDepth: row.lastStopDepth,
      gasSwitchStopSeconds: row.gasSwitchStopSeconds,
      airBreaks:
          row.airBreakO2Seconds != null && row.airBreakBreakSeconds != null
          ? AirBreakPolicy(
              o2Seconds: row.airBreakO2Seconds!,
              breakSeconds: row.airBreakBreakSeconds!,
            )
          : null,
      sacBottom: row.sacBottom,
      sacDeco: row.sacDeco,
      sacStressed: row.sacStressed,
      reservePressure: row.reservePressure,
      surfaceInterval: row.surfaceIntervalSeconds != null
          ? Duration(seconds: row.surfaceIntervalSeconds!)
          : null,
      sourceDiveId: row.sourceDiveId,
      linkedDiveId: row.linkedDiveId,
      setpointLow: row.setpointLow,
      setpointHigh: row.setpointHigh,
      setpointSwitchDepth: row.setpointSwitchDepth,
      deviationDepthDelta: row.deviationDepthDelta,
      deviationTimeMinutes: row.deviationTimeMinutes,
      turnPressureRule: row.turnPressureRule != null
          ? domain.TurnPressureRule.values.byName(row.turnPressureRule!)
          : null,
      turnPressureFraction: row.turnPressureFraction,
      tanks: tankRows
          .map(
            (t) => DiveTank(
              id: t.id,
              name: t.name,
              volume: t.volume,
              workingPressure: t.workingPressure,
              startPressure: t.startPressure,
              gasMix: GasMix(o2: t.gasO2, he: t.gasHe),
              role: TankRole.values.byName(t.role),
              material: t.material != null
                  ? TankMaterial.values.byName(t.material!)
                  : null,
              order: t.sortOrder,
              presetName: t.presetName,
            ),
          )
          .toList(),
      segments: segmentRows
          .map(
            (s) => PlanSegment(
              id: s.id,
              type: SegmentType.values.byName(s.type),
              startDepth: s.startDepth,
              endDepth: s.endDepth,
              durationSeconds: s.durationSeconds,
              tankId: s.tankId,
              gasMix: GasMix(o2: s.gasO2, he: s.gasHe),
              rate: s.rate,
              switchToTankId: s.switchToTankId,
              order: s.sortOrder,
            ),
          )
          .toList(),
    );
  }
}
