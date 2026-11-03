import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
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
  final _uuid = const Uuid();

  db.AppDatabase get _db => DatabaseService.instance.database;

  /// Stores [series] and its dives, and deletes any dive it no longer has.
  ///
  /// Returns the series as stored, which is not always the one passed in: a
  /// followed dive that no longer exists is dropped, and a tank id another
  /// plan's row holds is re-minted by [DivePlanRepository.savePlan], with the
  /// links between dives moved to the new id. Callers should adopt the result.
  ///
  /// The diver is set when the series is first saved and kept from then on:
  /// saved plans are open to every profile, so a later save by another one
  /// does not take the series over.
  ///
  /// Saving never writes a dive's link to the log: each dive keeps the link
  /// its row holds, and a new dive has none. Only the link actions change a
  /// link, and the series in memory can hold a stale one for a dive that was
  /// linked or unlinked while another dive was in the editor.
  Future<StoredSeries> saveSeries(StoredSeries series) =>
      _writeSeries(series, keepLinks: false);

  /// Writes back a series [deleteSeries] removed, as [getSeries] read it
  /// before, for Undo. Unlike [saveSeries] each dive keeps the link to the
  /// log it was read with, since its row is gone; a dive deleted since is
  /// dropped from it rather than failing the restore.
  Future<StoredSeries> restoreSeries(StoredSeries series) =>
      _writeSeries(series, keepLinks: true);

  Future<StoredSeries> _writeSeries(
    StoredSeries series, {
    required bool keepLinks,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      late StoredSeries stored;
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.divePlanSeries,
        )..where((s) => s.id.equals(series.id))).getSingleOrNull();
        final followed = await _existingDive(series.followedDiveId);
        final owner = existing?.diverId ?? series.diverId;

        await _db
            .into(_db.divePlanSeries)
            .insertOnConflictUpdate(
              db.DivePlanSeriesCompanion(
                id: Value(series.id),
                diverId: Value(owner),
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
          final link = keepLinks
              ? dive.plan.linkedDiveId
              : await _storedLink(dive.plan.id);
          final plan = await _plans.savePlan(
            dive.plan.copyWith(
              linkedDiveId: link,
              clearLinkedDiveId: link == null,
            ),
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
              diverId: owner == null ? const Value.absent() : Value(owner),
              diveName: Value(dive.name),
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
          diverId: owner,
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
              // Then by id: two devices can each add a dive at the same
              // place before syncing, and the order must not flip between
              // opens (the saved plans list breaks the tie the same way).
              ..orderBy([
                (p) => OrderingTerm.asc(p.seriesIndex),
                (p) => OrderingTerm.asc(p.id),
              ]))
            .get();
    // Every dive's tanks in one read, for the columns a plan does not carry.
    final tanksByPlan = <String, List<db.DivePlanTank>>{};
    final allTankRows = await (_db.select(
      _db.divePlanTanks,
    )..where((t) => t.planId.isIn([for (final p in planRows) p.id]))).get();
    for (final tank in allTankRows) {
      tanksByPlan.putIfAbsent(tank.planId, () => []).add(tank);
    }
    final dives = <StoredSeriesDive>[];
    for (final planRow in planRows) {
      final plan = await _plans.getPlan(planRow.id);
      if (plan == null) continue;
      final tankRows = tanksByPlan[planRow.id] ?? const <db.DivePlanTank>[];
      dives.add(
        StoredSeriesDive(
          plan: plan,
          name: planRow.diveName,
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

  /// Copies the series [id] under a new name, with new ids throughout, and
  /// the links between its dives moved to them. Returns the copy, or null when
  /// the series does not exist.
  ///
  /// One transaction: each dive is copied as a plan before the series row
  /// exists, so a failure part way must not leave those copies behind as
  /// plans of their own.
  Future<StoredSeries?> duplicateSeries(String id) async {
    final source = await getSeries(id);
    if (source == null) return null;
    final name = '${source.name} (copy)';

    return _db.transaction(() async {
      final dives = <StoredSeriesDive>[];
      var previousIds = const <String, String>{};
      for (final dive in source.dives) {
        final copy = await _plans.duplicatePlan(dive.plan.id);
        if (copy == null) continue;
        final ids = {
          for (var t = 0; t < copy.tanks.length; t++)
            dive.plan.tanks[t].id: copy.tanks[t].id,
        };
        dives.add(
          dive.copyWith(
            plan: copy.copyWith(name: name),
            sourceTankIds: {
              for (final e in dive.sourceTankIds.entries)
                ?ids[e.key]: previousIds[e.value] ?? e.value,
            },
            pinnedTankIds: {
              for (final tankId in dive.pinnedTankIds) ?ids[tankId],
            },
          ),
        );
        previousIds = ids;
      }
      return saveSeries(
        StoredSeries(
          id: _uuid.v4(),
          name: name,
          diverId: source.diverId,
          followedDiveId: source.followedDiveId,
          dives: dives,
        ),
      );
    });
  }

  /// Names the series [id]. Every dive holds the name too, which is what
  /// anything reading a dive as a plan shows.
  Future<void> renameSeries(String id, String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await _db.transaction(() async {
        await (_db.update(
          _db.divePlanSeries,
        )..where((s) => s.id.equals(id))).write(
          db.DivePlanSeriesCompanion(name: Value(name), updatedAt: Value(now)),
        );
        await (_db.update(
          _db.divePlans,
        )..where((p) => p.seriesId.equals(id))).write(
          db.DivePlansCompanion(name: Value(name), updatedAt: Value(now)),
        );
      });
      await _syncRepository.markRecordPending(
        entityType: 'divePlanSeries',
        recordId: id,
        localUpdatedAt: now,
      );
      final rows = await (_db.select(
        _db.divePlans,
      )..where((p) => p.seriesId.equals(id))).get();
      for (final row in rows) {
        await _syncRepository.markRecordPending(
          entityType: 'divePlans',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to rename series $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Turns the series [id] back into the ordinary plan [keepPlanId]: frees
  /// that plan, and deletes the series row and every other dive still in it
  /// (dives removed in the editor since the last save), with their
  /// tombstones. The caller saves the kept plan itself afterwards.
  Future<void> dissolveSeries(String id, {required String keepPlanId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      var kept = false;
      await _db.transaction(() async {
        final rows = await (_db.select(
          _db.divePlans,
        )..where((p) => p.seriesId.equals(id))).get();
        for (final row in rows) {
          if (row.id == keepPlanId) {
            kept = true;
          } else {
            await _plans.deletePlan(row.id);
          }
        }
        await (_db.update(
          _db.divePlans,
        )..where((p) => p.id.equals(keepPlanId))).write(
          db.DivePlansCompanion(
            seriesId: const Value(null),
            seriesIndex: const Value(null),
            diveName: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await (_db.delete(
          _db.divePlanSeries,
        )..where((s) => s.id.equals(id))).go();
      });
      if (kept) {
        await _syncRepository.markRecordPending(
          entityType: 'divePlans',
          recordId: keepPlanId,
          localUpdatedAt: now,
        );
      }
      await _syncRepository.logDeletion(
        entityType: 'divePlanSeries',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to dissolve series $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

  /// The dive the plan [planId]'s row is linked to; null for a plan with no
  /// row yet or no link.
  Future<String?> _storedLink(String planId) async {
    final row = await (_db.select(
      _db.divePlans,
    )..where((p) => p.id.equals(planId))).getSingleOrNull();
    return row?.linkedDiveId;
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
}
