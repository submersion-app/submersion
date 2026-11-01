import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// Persistence for saved repetitive series (issue #3565): a series row, and
/// each dive as an ordinary saved plan placed in it, so everything that reads
/// a plan keeps working. A plan with no series is a one-dive series; nothing
/// is backfilled, since minting series on each device would sync duplicates.
class DivePlanSeriesRepository {
  DivePlanSeriesRepository({DivePlanRepository? plans})
    : _plans = plans ?? DivePlanRepository();

  final DivePlanRepository _plans;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(DivePlanSeriesRepository);

  db.AppDatabase get _db => DatabaseService.instance.database;

  /// Stores [series] and its dives, and deletes any dive it no longer has.
  ///
  /// Returns the series as stored, which is not always the one passed in: a
  /// followed dive that no longer exists is dropped, and a tank id another
  /// plan's row holds is re-minted by [DivePlanRepository.savePlan], with the
  /// links between dives moved to the new id. Callers should adopt the result.
  Future<StoredSeries> saveSeries(StoredSeries series) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      late StoredSeries stored;
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.divePlanSeries,
        )..where((s) => s.id.equals(series.id))).getSingleOrNull();
        final followed = await _existingDive(series.followedDiveId);

        await _db
            .into(_db.divePlanSeries)
            .insertOnConflictUpdate(
              db.DivePlanSeriesCompanion(
                id: Value(series.id),
                diverId: Value(series.diverId),
                name: Value(series.name),
                followedDiveId: Value(followed),
                createdAt: Value(existing?.createdAt ?? now),
                updatedAt: Value(now),
              ),
            );

        final keptIds = {for (final dive in series.dives) dive.plan.id};
        final previousRows = await (_db.select(
          _db.divePlans,
        )..where((p) => p.seriesId.equals(series.id))).get();
        for (final row in previousRows) {
          if (!keptIds.contains(row.id)) await _plans.deletePlan(row.id);
        }

        final dives = <StoredSeriesDive>[];
        var previousIds = const <String, String>{};
        for (var i = 0; i < series.dives.length; i++) {
          final dive = series.dives[i];
          final plan = await _plans.savePlan(
            dive.plan,
            summary: dive.summaryRuntimeSeconds == null
                ? null
                : PlanSummaryData(
                    maxDepth: dive.summaryMaxDepth ?? 0,
                    runtimeSeconds: dive.summaryRuntimeSeconds!,
                    ttsSeconds: dive.summaryTtsSeconds,
                  ),
          );
          final ids = {
            for (var t = 0; t < plan.tanks.length; t++)
              dive.plan.tanks[t].id: plan.tanks[t].id,
          };
          final sources = {
            for (final e in dive.sourceTankIds.entries)
              ?ids[e.key]: previousIds[e.value] ?? e.value,
          };
          final pinned = {for (final id in dive.pinnedTankIds) ?ids[id]};

          await (_db.update(
            _db.divePlans,
          )..where((p) => p.id.equals(plan.id))).write(
            db.DivePlansCompanion(
              seriesId: Value(series.id),
              seriesIndex: Value(i),
              diverId: series.diverId == null
                  ? const Value.absent()
                  : Value(series.diverId),
              diveName: Value(dive.name),
              fixedStart: Value(dive.fixedStart),
              settingOverrides: Value(_encode(dive.settingOverrides)),
            ),
          );
          for (final tank in plan.tanks) {
            await (_db.update(
              _db.divePlanTanks,
            )..where((t) => t.id.equals(tank.id))).write(
              db.DivePlanTanksCompanion(
                sourceTankId: Value(sources[tank.id]),
                startPressurePinned: Value(pinned.contains(tank.id)),
              ),
            );
          }
          dives.add(
            dive.copyWith(
              plan: plan,
              sourceTankIds: sources,
              pinnedTankIds: pinned,
            ),
          );
          previousIds = ids;
        }
        stored = StoredSeries(
          id: series.id,
          name: series.name,
          diverId: series.diverId,
          followedDiveId: followed,
          dives: dives,
        );
      });

      await _syncRepository.markRecordPending(
        entityType: 'divePlanSeries',
        recordId: series.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return stored;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save series ${series.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The series the plan [planId] belongs to, or null when it has none.
  Future<String?> seriesIdForPlan(String planId) async {
    final row = await (_db.select(
      _db.divePlans,
    )..where((p) => p.id.equals(planId))).getSingleOrNull();
    return row?.seriesId;
  }

  /// The series [id] with its dives in order, or null when it does not exist.
  Future<StoredSeries?> getSeries(String id) async {
    final row = await (_db.select(
      _db.divePlanSeries,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return null;

    final planRows =
        await (_db.select(_db.divePlans)
              ..where((p) => p.seriesId.equals(id))
              ..orderBy([(p) => OrderingTerm.asc(p.seriesIndex)]))
            .get();
    final dives = <StoredSeriesDive>[];
    for (final planRow in planRows) {
      final plan = await _plans.getPlan(planRow.id);
      if (plan == null) continue;
      final tankRows = await (_db.select(
        _db.divePlanTanks,
      )..where((t) => t.planId.equals(planRow.id))).get();
      dives.add(
        StoredSeriesDive(
          plan: plan,
          name: planRow.diveName,
          fixedStart: planRow.fixedStart,
          settingOverrides: _decode(planRow.settingOverrides),
          sourceTankIds: {
            for (final tank in tankRows) tank.id: ?tank.sourceTankId,
          },
          pinnedTankIds: {
            for (final tank in tankRows)
              if (tank.startPressurePinned) tank.id,
          },
          summaryMaxDepth: planRow.summaryMaxDepth,
          summaryRuntimeSeconds: planRow.summaryRuntimeSeconds,
          summaryTtsSeconds: planRow.summaryTtsSeconds,
        ),
      );
    }
    return StoredSeries(
      id: row.id,
      name: row.name,
      diverId: row.diverId,
      followedDiveId: row.followedDiveId,
      dives: dives,
    );
  }

  /// Deletes the series [id] and every dive in it, with their tombstones.
  Future<void> deleteSeries(String id) async {
    try {
      await _db.transaction(() async {
        final rows = await (_db.select(
          _db.divePlans,
        )..where((p) => p.seriesId.equals(id))).get();
        for (final row in rows) {
          await _plans.deletePlan(row.id);
        }
        await (_db.delete(
          _db.divePlanSeries,
        )..where((s) => s.id.equals(id))).go();
      });
      await _syncRepository.logDeletion(
        entityType: 'divePlanSeries',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete series $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// [id] when it still names a dive: the column has no ON DELETE action, so
  /// writing a dead id would fail the whole save.
  Future<String?> _existingDive(String? id) async {
    if (id == null) return null;
    final row = await (_db.select(
      _db.dives,
    )..where((d) => d.id.equals(id))).getSingleOrNull();
    return row?.id;
  }

  String? _encode(Set<PlanSettingGroup> groups) =>
      groups.isEmpty ? null : groups.map((g) => g.name).join(',');

  /// Names this build does not know, from a newer one, are left out.
  Set<PlanSettingGroup> _decode(String? value) {
    if (value == null || value.isEmpty) return const {};
    final known = PlanSettingGroup.values.asNameMap();
    return {for (final name in value.split(',')) ?known[name]};
  }
}
