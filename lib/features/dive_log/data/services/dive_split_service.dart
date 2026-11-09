import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/primary_source_promotion.dart';
import 'package:submersion/features/dive_log/data/services/source_ownership.dart';
import 'package:submersion/features/dive_log/domain/services/source_bottom_time.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';

/// Splits one data source's computer data out of a dive into a new dive —
/// the inverse of DiveConsolidationService. The source's profile rows,
/// events, tank pressures, tanks (and those tanks' gas switches) move to a
/// freshly created dive; the logbook entry (site, notes, buddies, tags,
/// equipment, media) stays on the original dive.
///
/// Consolidation slid the source onto the dive's timeline and recorded by how
/// much in `timeOffsetSeconds`. Everything that moves goes back to the
/// source's own clock (issue #3916), so a timestamp means the same moment
/// measured from the new dive's start as it did before the two were
/// consolidated. When the primary is the one that leaves, the dive itself
/// starts over on the source promoted in its place.
///
/// Mirrors the consolidation service's sync discipline: one transaction,
/// per-row tombstones for every moved row (the original dive survives, so
/// peers would otherwise keep upsert copies forever), markRecordPending for
/// new rows, one SyncEventBus notify.
class DiveSplitService {
  DiveSplitService(this._diveRepo);

  // Retained for parity with DiveConsolidationService's constructor shape
  // and for future stat-recompute hooks; the split itself works on raw rows.
  // ignore: unused_field
  final DiveRepository _diveRepo;

  final _uuid = const Uuid();
  final _sync = SyncRepository();
  final _profileSeries = ProfileSeriesRepository();
  final _tankSeries = TankPressureSeriesRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Splits [sourceId]'s data out of [diveId] into a new dive and returns
  /// the new dive's id. Throws [ArgumentError] when the source does not
  /// belong to the dive or is the dive's only source. All-or-nothing: one
  /// transaction, full rollback on any failure.
  Future<String> split({required String diveId, required String sourceId}) =>
      ChangeLogScope.bulk(
        DatabaseService.instance.databaseOrNull,
        label: ChangeLogLabels.splitDive,
        body: () => _splitInner(diveId: diveId, sourceId: sourceId),
      );

  Future<String> _splitInner({
    required String diveId,
    required String sourceId,
  }) async {
    final sources =
        await (_db.select(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) {
      throw ArgumentError('source $sourceId does not belong to dive $diveId');
    }
    if (sources.length < 2) {
      throw ArgumentError('cannot split the only source of dive $diveId');
    }

    // Every series of this dive has to decode before anything moves. Split
    // deletes the tanks it moves, and tank_pressure_series cascades on
    // tank_id, so a series the reads answer with null (an unreadable blob)
    // is invisible to the reference check below, gets its tank moved out
    // from under it, and is cascade-deleted with no tombstone: gone here
    // and kept forever by every peer. Merge and consolidate open with the
    // same guard.
    final unreadable = [
      ...await _profileSeries.unreadableSeriesIds([diveId]),
      ...await _tankSeries.unreadableSeriesIds([diveId]),
    ];
    if (unreadable.isNotEmpty) throw UnreadableSeriesException(unreadable);

    final diveRow = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();

    final newDiveId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    // How far along this dive's timeline the source's own clock starts.
    final sourceOffset = source.timeOffsetSeconds ?? 0;

    // What the source owns: see SourceOwnership. A pressure series that names
    // the source moves with it whatever its computer, cloning the tank it
    // sits on (issue #2440).
    final ownership = SourceOwnership(source);
    final ownedByComputer = ownership.ownedByComputer;

    await _db.transaction(() async {
      // Read INSIDE the transaction, and before step 13's deletes: the
      // legacy path read its rows inside too, and a read outside is a torn
      // one, deciding what moves from a snapshot another writer can change
      // before the moves are applied. Before the deletes because
      // dive_profile_series.source_id is ON DELETE SET NULL, so reading
      // after would lose the FK ownership signal this rule needs.
      final allProfileSeries = await _profileSeries.getSeriesForDive(diveId);
      // Also before the deletes: they take the demoted generation an edit is
      // recognised by.
      final liveEditIds = await _profileSeries.liveEditIds(diveId);
      final allPressureSeries = await _tankSeries.getSeriesForDive(diveId);
      final movingProfiles = allProfileSeries
          .where(ownership.ownsProfile)
          .toList();
      final movingPressures = allPressureSeries
          .where(ownership.ownsPressure)
          .toList();
      // Read here too, before step 2 deletes the source row:
      // dive_tanks.source_id is ON DELETE SET NULL (v251), so reading after
      // would lose the ownership signal the tank rule below reads.
      final allTanks = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();

      // 1. New dive: copy the original row, attribute it to the source's
      // computer, override summary fields with the source's snapshot, and
      // leave the logbook entry (site, notes, number) behind.
      final newDiveTiming = snapshotSourceTiming(
        [source],
        source,
        diveRow,
        sourceOffset,
      );
      await _db
          .into(_db.dives)
          .insert(
            diveRow
                .toCompanion(false)
                .copyWith(
                  id: Value(newDiveId),
                  // Dive.dateTime derives from diveDateTime; date the new
                  // dive by its own source's entry time so it sorts where
                  // that computer actually recorded it. A source with no
                  // entry time still goes back to its own clock below, so
                  // it starts as far along the old dive as that clock did.
                  diveDateTime: Value(
                    newDiveTiming.entryMs ??
                        diveRow.diveDateTime + sourceOffset * 1000,
                  ),
                  diveNumber: const Value(null),
                  siteId: const Value(null),
                  notes: const Value(''),
                  computerId: Value(source.computerId),
                  diveComputerModel: Value(source.computerModel),
                  diveComputerSerial: Value(source.computerSerial),
                  maxDepth: Value(source.maxDepth ?? diveRow.maxDepth),
                  avgDepth: Value(source.avgDepth ?? diveRow.avgDepth),
                  // Derived from the series that move with the source; its
                  // duration is the runtime it measured, never a bottom time.
                  bottomTime: Value(
                    sourceBottomTimeSeconds(
                          movingProfiles,
                          sourceId: source.id,
                          computerId: source.computerId,
                          runtimeSeconds: newDiveTiming.runtimeSeconds,
                        ) ??
                        diveRow.bottomTime,
                  ),
                  // The source's own, or the copied row would keep the
                  // original dive's across the source's span (issue #3899).
                  runtime: Value(
                    newDiveTiming.runtimeSeconds ?? diveRow.runtime,
                  ),
                  waterTemp: Value(source.waterTemp ?? diveRow.waterTemp),
                  entryTime: Value(newDiveTiming.entryMs),
                  exitTime: Value(newDiveTiming.exitMs),
                  surfaceIntervalSeconds: Value(
                    source.surfaceInterval ?? diveRow.surfaceIntervalSeconds,
                  ),
                  cnsEnd: Value(source.cns ?? diveRow.cnsEnd),
                  decoAlgorithm: Value(
                    source.decoAlgorithm ?? diveRow.decoAlgorithm,
                  ),
                  gradientFactorLow: Value(
                    source.gradientFactorLow ?? diveRow.gradientFactorLow,
                  ),
                  gradientFactorHigh: Value(
                    source.gradientFactorHigh ?? diveRow.gradientFactorHigh,
                  ),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
          );
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: newDiveId,
        localUpdatedAt: now,
      );
      // The diver's own roles travel with the copied row (issue #1221): the
      // scalar came across in the copy, the rest of the set lives in the
      // junction.
      final roleLinks = DiveRoleLinkRepository();
      await roleLinks.writeDiverRoles(
        newDiveId,
        (await roleLinks.diverRoleIdsForDives([diveRow.id]))[diveRow.id] ??
            const [],
        now: now,
      );

      // 2. The source row becomes the new dive's primary source, on that
      // dive's time base: steps 5 to 7b take its offset off what it moves.
      final newSourceId = _uuid.v4();
      await _db
          .into(_db.diveDataSources)
          .insert(
            source
                .toCompanion(false)
                .copyWith(
                  id: Value(newSourceId),
                  diveId: Value(newDiveId),
                  isPrimary: const Value(true),
                  timeOffsetSeconds: const Value(0),
                ),
          );
      await (_db.delete(
        _db.diveDataSources,
      )..where((t) => t.id.equals(source.id))).go();
      await _sync.logDeletion(
        entityType: 'diveDataSources',
        recordId: source.id,
      );

      // 3. Tanks (clone-on-demand, inherited from the retired
      // unlinkComputer path). A tank owned by the departing source moves
      // only when nothing remaining still references it: another
      // computer's (or unattributed) pressure rows, events or gas switches,
      // or another computer that shares the cylinder. The departing
      // computer's own switches move with it (step 7b). A still-referenced
      // tank stays
      // behind with its attribution cleared, and a clone on the new dive
      // carries the departing computer's rows. Departing pressure rows on
      // a tank the source never owned get the same clone-on-demand
      // treatment.
      final allEvents = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      final switchRows = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();

      final eventRows = allEvents
          .where((r) => ownedByComputer(r.computerId))
          .toList();

      final tankIdMap = <String, String>{};
      final movedTankIds = <String>[];
      for (final tank in allTanks.where(ownership.ownsTank)) {
        final hasRemainingRefs = ownership.tankStillNeeded(
          tank,
          pressures: allPressureSeries,
          events: allEvents,
          switches: switchRows,
        );

        final freshId = _uuid.v4();
        tankIdMap[tank.id] = freshId;
        await _db
            .into(_db.diveTanks)
            .insert(
              tank
                  .toCompanion(false)
                  .copyWith(
                    id: Value(freshId),
                    diveId: Value(newDiveId),
                    sourceId: Value(newSourceId),
                    // The new dive has this one computer only.
                    sharedComputerIds: const Value(null),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: freshId,
          localUpdatedAt: now,
        );

        if (hasRemainingRefs) {
          await ownership.handTankToHeir(
            _db,
            _sync,
            tank: tank,
            sources: sources,
            now: now,
          );
        } else {
          movedTankIds.add(tank.id);
        }
      }

      // The departing computer's own copy, on the new dive, of a cylinder
      // it used but did not own.
      Future<void> cloneForDepartingComputer(DiveTank tank) async {
        final freshId = _uuid.v4();
        tankIdMap[tank.id] = freshId;
        await _db
            .into(_db.diveTanks)
            .insert(
              tank
                  .toCompanion(false)
                  .copyWith(
                    id: Value(freshId),
                    diveId: Value(newDiveId),
                    computerId: Value(source.computerId),
                    sourceId: Value(newSourceId),
                    sharedComputerIds: const Value(null),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: freshId,
          localUpdatedAt: now,
        );
      }

      // Shared tanks the departing computer recorded pressures on but
      // never owned: clone them so the moved rows have a home.
      for (final s in movingPressures) {
        if (tankIdMap.containsKey(s.tankId)) continue;
        final tank = allTanks.where((t) => t.id == s.tankId).firstOrNull;
        if (tank == null) continue;
        await cloneForDepartingComputer(tank);
      }

      // Cylinders the departing computer shared with another (tanks a
      // consolidation merged): it breathed them too, so the new dive gets
      // its own copy and the original stops listing it.
      for (final tank in allTanks.where(ownership.sharesTank)) {
        if (!tankIdMap.containsKey(tank.id)) {
          await cloneForDepartingComputer(tank);
        }
        await ownership.stopSharingTank(_db, _sync, tank: tank, now: now);
      }

      // 5. Profile series. A primary source with a computer takes its whole
      // family: its computer's series AND the null-computer series (the
      // schema's null-means-primary convention covers user-edited profiles
      // and pre-consolidation samples), preserving each series' isPrimary
      // flag so edited-vs-original semantics survive the split. Secondary
      // sources take their computer's series, promoted to primary on the
      // new dive. A computer-less source moves only non-primary null
      // series (user-edited primary series stay with the original dive).
      // Every branch is additionally gated on the series not being spoken
      // for by a DIFFERENT source (issue #1149). The computerId rules
      // cannot separate two file-imported sources (both sides are null),
      // so on a dive carrying two of them the null-family branch swept up
      // the other source's samples and carried them onto the new dive,
      // taking them off the dive being split from entirely. A series whose
      // sourceId names another source is never this source's to move;
      // series with no sourceId still fall through to the legacy rules
      // above (see [profileBelongsToSource]).
      for (final s in movingProfiles) {
        await _profileSeries.insertSeries(
          diveId: newDiveId,
          computerId: s.computerId,
          sourceId: newSourceId,
          isPrimary: source.isPrimary ? s.isPrimary : true,
          activatedAt: Value(s.activatedAt),
          samples: [for (final p in s.samples) p.shiftedBy(-sourceOffset)],
          now: now,
        );
      }

      // The row above took the source's own depths. An edit that moved with
      // it is what the new dive shows, so its depths are the dive's (issue
      // #3931).
      final movedEditDepths = await _profileSeries.liveEditDepthSummary(
        newDiveId,
      );
      if (movedEditDepths != null) {
        await (_db.update(
          _db.dives,
        )..where((t) => t.id.equals(newDiveId))).write(
          DivesCompanion(
            maxDepth: Value(movedEditDepths.maxDepth),
            avgDepth: Value(movedEditDepths.avgDepth),
          ),
        );
      }

      // 6. Tank pressure series, re-pointed at the moved or cloned tanks.
      for (final s in movingPressures) {
        await _tankSeries.insertSeries(
          diveId: newDiveId,
          tankId: tankIdMap[s.tankId] ?? s.tankId,
          computerId: s.computerId,
          sourceId: newSourceId,
          samples: [for (final p in s.samples) p.shiftedBy(-sourceOffset)],
          now: now,
        );
      }

      // 7. Profile events.
      for (final row in eventRows) {
        final freshId = _uuid.v4();
        await _db
            .into(_db.diveProfileEvents)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(freshId),
                    diveId: Value(newDiveId),
                    timestamp: Value(row.timestamp - sourceOffset),
                    tankId: Value(
                      row.tankId == null
                          ? null
                          : tankIdMap[row.tankId] ?? row.tankId,
                    ),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: freshId,
          localUpdatedAt: now,
        );
      }

      // 7b. Gas switches the departing computer logged (v258, #2582) go
      // with its gas plan, onto its copy of the tank. Unattributed switches
      // belong to the dive and stay, as every switch did before v258.
      final movingSwitches = [
        for (final r in switchRows)
          if (ownedByComputer(r.computerId) && tankIdMap.containsKey(r.tankId))
            r,
      ];
      for (final row in movingSwitches) {
        final freshId = _uuid.v4();
        await _db
            .into(_db.gasSwitches)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(freshId),
                    diveId: Value(newDiveId),
                    tankId: Value(tankIdMap[row.tankId]!),
                    timestamp: Value(row.timestamp - sourceOffset),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: freshId,
          localUpdatedAt: now,
        );
      }

      // 8. Delete the originals, children before parents, and tombstone
      // them (the original dive survives; without explicit tombstones peers
      // that already pulled these rows keep them forever): the moved events
      // by one scope tombstone, the rest per row. Only the departing
      // computer's own gas switches move, and only unreferenced tanks were
      // moved.
      if (movingSwitches.isNotEmpty) {
        final ids = [for (final r in movingSwitches) r.id];
        await (_db.delete(_db.gasSwitches)..where((t) => t.id.isIn(ids))).go();
        await _sync.logDeletions(entityType: 'gasSwitches', recordIds: ids);
      }
      await _tankSeries.deleteByIds([for (final s in movingPressures) s.id]);
      await _profileSeries.deleteByIds([for (final s in movingProfiles) s.id]);
      if (eventRows.isNotEmpty) {
        await (_db.delete(
          _db.diveProfileEvents,
        )..where((t) => t.id.isIn([for (final r in eventRows) r.id]))).go();
        // One tombstone for every event this source's computer recorded on
        // the dive, instead of one per event (#1926). eventRows is exactly
        // that set (ownedByComputer), so the scope removes on a peer what
        // was removed here. ownedByComputer never matches a null computer,
        // so the id is set whenever an event moved; asserting it keeps a
        // broken invariant from widening the scope to every event on the
        // dive.
        await _sync.logScopedDeletion(
          EventScopeTombstone(diveId: diveId, computerId: source.computerId!),
        );
        // A scope never reaches the diver's own events (#4109), and one an
        // older consolidation stamped with this computer moved with the rest.
        final movedUserEvents = [
          for (final r in eventRows)
            if (r.source == EventSource.user.name) r.id,
        ];
        if (movedUserEvents.isNotEmpty) {
          await _sync.logDeletions(
            entityType: 'diveProfileEvents',
            recordIds: movedUserEvents,
          );
        }
      }
      if (movedTankIds.isNotEmpty) {
        await _sync.logDeletions(
          entityType: 'diveTanks',
          recordIds: movedTankIds,
        );
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.isIn(movedTankIds))).go();
      }

      // 9. If the split source was the primary, promote the remaining
      // source with the earliest creation timestamp and refresh the
      // original dive's attribution and summary from it.
      var diveUpdate = DivesCompanion(updatedAt: Value(now));
      if (source.isPrimary) {
        diveUpdate = await promoteAfterPrimaryLeaves(
          db: _db,
          sync: _sync,
          profileSeries: _profileSeries,
          tankSeries: _tankSeries,
          diveId: diveId,
          leaving: source,
          sources: sources,
          diveRow: diveRow,
          liveEditIds: liveEditIds,
          remainingProfileSeries: allProfileSeries.where(
            (s) => !movingProfiles.contains(s),
          ),
          leavingProfileIds: {for (final s in movingProfiles) s.id},
          now: now,
        );
      }

      // 10. Touch the original dive so sync carries the split.
      await (_db.update(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).write(diveUpdate);
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    });

    SyncEventBus.notifyLocalChange();
    return newDiveId;
  }
}
