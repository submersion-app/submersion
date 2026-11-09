import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/primary_source_promotion.dart';
import 'package:submersion/features/dive_log/data/services/source_row_ownership.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';

/// What a source removal did, for its Undo.
class SourceRemoval {
  const SourceRemoval({required this.operationId});

  /// The removal's change log entry, which a revert undoes whole. Null with
  /// no database to log to.
  final String? operationId;
}

/// Removes one data source from a dive with everything it owns: its profile
/// series, pressure series, events, gas switches and the tanks only it uses
/// (issue #4393). The same rows Split moves to a new dive (see
/// [SourceOwnership]), deleted instead. The logbook entry stays.
///
/// When the primary leaves, the earliest remaining source is promoted and
/// the dive starts over on it, as Split does. The removal runs under its own
/// change log operation labelled [ChangeLogLabels.removeSource], which also
/// records the series edits a promotion makes, so one revert restores the
/// dive whole. Callers must not wrap it in another scope: [ChangeLogScope.bulk]
/// joins a running one and the label would be lost.
class DiveSourceRemovalService {
  final _sync = SyncRepository();
  final _profileSeries = ProfileSeriesRepository();
  final _tankSeries = TankPressureSeriesRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Throws [ArgumentError] when the source is not on the dive or is its
  /// only source, and [UnreadableSeriesException] when a series of the dive
  /// cannot be decoded (its tank could not be told apart safely).
  Future<SourceRemoval> remove({
    required String diveId,
    required String sourceId,
  }) async {
    String? operationId;
    await ChangeLogScope.bulk(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.removeSource,
      body: () async {
        operationId = ChangeLogScope.currentOperationId;
        await _remove(diveId: diveId, sourceId: sourceId);
      },
    );
    return SourceRemoval(operationId: operationId);
  }

  Future<void> _remove({
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
      throw ArgumentError('cannot remove the only source of dive $diveId');
    }
    // As in Split: tank_pressure_series cascades on tank_id, so a series that
    // will not decode is invisible to the reference check and would go with
    // its tank, untombstoned.
    final unreadable = [
      ...await _profileSeries.unreadableSeriesIds([diveId]),
      ...await _tankSeries.unreadableSeriesIds([diveId]),
    ];
    if (unreadable.isNotEmpty) throw UnreadableSeriesException(unreadable);

    final ownership = SourceOwnership(source);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      final diveRow = await (_db.select(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();
      // Everything is read before the source row goes: source_id is ON
      // DELETE SET NULL on series and tanks, and the rules read it.
      final allProfileSeries = await _profileSeries.getSeriesForDive(diveId);
      final liveEditIds = await _profileSeries.liveEditIds(diveId);
      final allPressureSeries = await _tankSeries.getSeriesForDive(diveId);
      final allTanks = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();
      final allEvents = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      final switchRows = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();

      final leavingProfiles = allProfileSeries
          .where(ownership.ownsProfile)
          .toList();
      final leavingPressures = allPressureSeries
          .where(ownership.ownsPressure)
          .toList();
      final leavingEvents = allEvents
          .where((r) => ownership.ownedByComputer(r.computerId))
          .toList();

      final deletedTankIds = <String>[];
      for (final tank in allTanks.where(ownership.ownsTank)) {
        final stillNeeded = ownership.tankStillNeeded(
          tank,
          pressures: allPressureSeries,
          events: allEvents,
          switches: switchRows,
        );
        if (stillNeeded) {
          await ownership.handTankToHeir(
            _db,
            _sync,
            tank: tank,
            sources: sources,
            now: now,
          );
        } else {
          deletedTankIds.add(tank.id);
        }
      }
      for (final tank in allTanks.where(ownership.sharesTank)) {
        await ownership.stopSharingTank(_db, _sync, tank: tank, now: now);
      }

      // The source's own gas switches go with it, as Split moves them, plus
      // any switch on a tank that is leaving (the FK would cascade it
      // untombstoned otherwise).
      final leavingSwitches = [
        for (final r in switchRows)
          if (ownership.ownedByComputer(r.computerId) ||
              deletedTankIds.contains(r.tankId))
            r.id,
      ];
      if (leavingSwitches.isNotEmpty) {
        await (_db.delete(
          _db.gasSwitches,
        )..where((t) => t.id.isIn(leavingSwitches))).go();
        await _sync.logDeletions(
          entityType: 'gasSwitches',
          recordIds: leavingSwitches,
        );
      }
      // A pressure series on a deleted tank goes too, whoever recorded it:
      // tankStillNeeded kept every tank another computer's series sits on.
      await _tankSeries.deleteByIds([
        for (final s in allPressureSeries)
          if (leavingPressures.contains(s) || deletedTankIds.contains(s.tankId))
            s.id,
      ]);
      await _profileSeries.deleteByIds([for (final s in leavingProfiles) s.id]);
      if (leavingEvents.isNotEmpty) {
        await (_db.delete(
          _db.diveProfileEvents,
        )..where((t) => t.id.isIn([for (final r in leavingEvents) r.id]))).go();
        // One scope tombstone for the computer's events (#1926), plus the
        // diver's own events, which no scope reaches (#4109).
        await _sync.logScopedDeletion(
          EventScopeTombstone(diveId: diveId, computerId: source.computerId!),
        );
        final userEvents = [
          for (final r in leavingEvents)
            if (r.source == EventSource.user.name) r.id,
        ];
        if (userEvents.isNotEmpty) {
          await _sync.logDeletions(
            entityType: 'diveProfileEvents',
            recordIds: userEvents,
          );
        }
      }
      if (deletedTankIds.isNotEmpty) {
        await _sync.logDeletions(
          entityType: 'diveTanks',
          recordIds: deletedTankIds,
        );
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.isIn(deletedTankIds))).go();
      }

      await (_db.delete(
        _db.diveDataSources,
      )..where((t) => t.id.equals(source.id))).go();
      await _sync.logDeletion(
        entityType: 'diveDataSources',
        recordId: source.id,
      );

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
            (s) => !leavingProfiles.contains(s),
          ),
          leavingProfileIds: {for (final s in leavingProfiles) s.id},
          now: now,
        );
      }
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
  }
}
