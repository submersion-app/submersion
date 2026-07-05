import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Splits one data source's computer data out of a dive into a new dive —
/// the inverse of DiveConsolidationService. The source's profile rows,
/// events, tank pressures, tanks (and those tanks' gas switches) move to a
/// freshly created dive; the logbook entry (site, notes, buddies, tags,
/// equipment, media) stays on the original dive.
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

  AppDatabase get _db => DatabaseService.instance.database;

  /// Splits [sourceId]'s data out of [diveId] into a new dive and returns
  /// the new dive's id. Throws [ArgumentError] when the source does not
  /// belong to the dive or is the dive's only source. All-or-nothing: one
  /// transaction, full rollback on any failure.
  Future<String> split({
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

    final diveRow = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingle();

    final newDiveId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Rows move by computer attribution. A computer-less source cannot be
    // attributed at the row level, so only non-primary null-computerId
    // profile rows follow it (never user-edited isPrimary rows) and no
    // tanks, pressures, or events move — the retired unlinkComputer's
    // convention.
    Expression<bool> ownedBySource(GeneratedColumn<String> computerId) =>
        source.computerId == null
        ? computerId.isNull()
        : computerId.equals(source.computerId!);

    await _db.transaction(() async {
      // 1. New dive: copy the original row, attribute it to the source's
      // computer, override summary fields with the source's snapshot, and
      // leave the logbook entry (site, notes, number) behind.
      await _db
          .into(_db.dives)
          .insert(
            diveRow
                .toCompanion(false)
                .copyWith(
                  id: Value(newDiveId),
                  // Dive.dateTime derives from diveDateTime; date the new
                  // dive by its own source's entry time so it sorts where
                  // that computer actually recorded it.
                  diveDateTime: Value(
                    source.entryTime?.millisecondsSinceEpoch ??
                        diveRow.diveDateTime,
                  ),
                  diveNumber: const Value(null),
                  siteId: const Value(null),
                  notes: const Value(''),
                  computerId: Value(source.computerId),
                  diveComputerModel: Value(source.computerModel),
                  diveComputerSerial: Value(source.computerSerial),
                  maxDepth: Value(source.maxDepth ?? diveRow.maxDepth),
                  avgDepth: Value(source.avgDepth ?? diveRow.avgDepth),
                  bottomTime: Value(source.duration ?? diveRow.bottomTime),
                  waterTemp: Value(source.waterTemp ?? diveRow.waterTemp),
                  entryTime: Value(
                    source.entryTime?.millisecondsSinceEpoch ??
                        diveRow.entryTime,
                  ),
                  exitTime: Value(
                    source.exitTime?.millisecondsSinceEpoch ?? diveRow.exitTime,
                  ),
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

      // 2. The source row becomes the new dive's primary source.
      await _db
          .into(_db.diveDataSources)
          .insert(
            source
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(newDiveId),
                  isPrimary: const Value(true),
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
      // computer's (or unattributed) pressure rows or events, or any gas
      // switch — switches carry no computer attribution and always stay
      // with the original dive's gas plan. A still-referenced tank stays
      // behind with its attribution cleared, and a clone on the new dive
      // carries the departing computer's rows. Departing pressure rows on
      // a tank the source never owned get the same clone-on-demand
      // treatment.
      final allTanks = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();
      final allPressures = await (_db.select(
        _db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      final allEvents = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      final switchRows = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();

      bool owned(String? computerId) =>
          source.computerId != null && computerId == source.computerId;

      final pressureRows = allPressures
          .where((r) => owned(r.computerId))
          .toList();
      final eventRows = allEvents.where((r) => owned(r.computerId)).toList();

      final tankIdMap = <String, String>{};
      final movedTankIds = <String>[];
      for (final tank in allTanks.where((t) => owned(t.computerId))) {
        final hasRemainingRefs =
            allPressures.any(
              (r) => r.tankId == tank.id && !owned(r.computerId),
            ) ||
            allEvents.any((r) => r.tankId == tank.id && !owned(r.computerId)) ||
            switchRows.any((r) => r.tankId == tank.id);

        final freshId = _uuid.v4();
        tankIdMap[tank.id] = freshId;
        await _db
            .into(_db.diveTanks)
            .insert(
              tank
                  .toCompanion(false)
                  .copyWith(id: Value(freshId), diveId: Value(newDiveId)),
            );
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: freshId,
          localUpdatedAt: now,
        );

        if (hasRemainingRefs) {
          await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tank.id)))
              .write(const DiveTanksCompanion(computerId: Value(null)));
          await _sync.markRecordPending(
            entityType: 'diveTanks',
            recordId: tank.id,
            localUpdatedAt: now,
          );
        } else {
          movedTankIds.add(tank.id);
        }
      }

      // Shared tanks the departing computer recorded pressures on but
      // never owned: clone them so the moved rows have a home.
      for (final row in pressureRows) {
        if (tankIdMap.containsKey(row.tankId)) continue;
        final tank = allTanks.where((t) => t.id == row.tankId).firstOrNull;
        if (tank == null) continue;
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
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: freshId,
          localUpdatedAt: now,
        );
      }

      // 5. Profile rows. A primary source with a computer takes its whole
      // family: its computer's rows AND the null-computerId rows (the
      // schema's null-means-primary convention covers user-edited profiles
      // and pre-consolidation samples), preserving each row's isPrimary
      // flag so edited-vs-original semantics survive the split. Secondary
      // sources take their computer's rows, promoted to primary on the new
      // dive. A computer-less source moves only non-primary null rows
      // (user-edited primary rows stay with the original dive).
      final profileRows =
          await (_db.select(_db.diveProfiles)..where(
                (t) => source.computerId == null
                    ? t.diveId.equals(diveId) &
                          t.computerId.isNull() &
                          t.isPrimary.equals(false)
                    : source.isPrimary
                    ? t.diveId.equals(diveId) &
                          (ownedBySource(t.computerId) | t.computerId.isNull())
                    : t.diveId.equals(diveId) & ownedBySource(t.computerId),
              ))
              .get();
      await _db.batch((batch) {
        for (final row in profileRows) {
          batch.insert(
            _db.diveProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(newDiveId),
                  isPrimary: source.isPrimary
                      ? Value(row.isPrimary)
                      : const Value(true),
                ),
          );
        }
      });

      // 6. Tank pressures, re-pointed at the moved or cloned tanks.
      await _db.batch((batch) {
        for (final row in pressureRows) {
          batch.insert(
            _db.tankPressureProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(newDiveId),
                  tankId: Value(tankIdMap[row.tankId] ?? row.tankId),
                ),
          );
        }
      });

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

      // 8. Delete the originals, children before parents, tombstoning each
      // row (the original dive survives; without explicit tombstones peers
      // that already pulled these rows keep them forever). Gas switches
      // never move, and only unreferenced tanks were moved.
      for (final row in pressureRows) {
        await _sync.logDeletion(
          entityType: 'tankPressureProfiles',
          recordId: row.id,
        );
      }
      if (pressureRows.isNotEmpty) {
        await (_db.delete(
          _db.tankPressureProfiles,
        )..where((t) => t.id.isIn([for (final r in pressureRows) r.id]))).go();
      }
      for (final row in eventRows) {
        await _sync.logDeletion(
          entityType: 'diveProfileEvents',
          recordId: row.id,
        );
      }
      if (eventRows.isNotEmpty) {
        await (_db.delete(
          _db.diveProfileEvents,
        )..where((t) => t.id.isIn([for (final r in eventRows) r.id]))).go();
      }
      for (final row in profileRows) {
        await _sync.logDeletion(entityType: 'diveProfiles', recordId: row.id);
      }
      if (profileRows.isNotEmpty) {
        await (_db.delete(
          _db.diveProfiles,
        )..where((t) => t.id.isIn([for (final r in profileRows) r.id]))).go();
      }
      for (final id in movedTankIds) {
        await _sync.logDeletion(entityType: 'diveTanks', recordId: id);
      }
      if (movedTankIds.isNotEmpty) {
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.isIn(movedTankIds))).go();
      }

      // 9. If the split source was the primary, promote the remaining
      // source with the earliest creation timestamp and refresh the
      // original dive's attribution and summary from it.
      var diveUpdate = DivesCompanion(updatedAt: Value(now));
      if (source.isPrimary) {
        final promoted = sources.firstWhere((s) => s.id != source.id);
        await (_db.update(_db.diveDataSources)
              ..where((t) => t.id.equals(promoted.id)))
            .write(const DiveDataSourcesCompanion(isPrimary: Value(true)));
        await _sync.markRecordPending(
          entityType: 'diveDataSources',
          recordId: promoted.id,
          localUpdatedAt: now,
        );

        // Promote the remaining source's profile rows so getDiveProfile
        // (which filters isPrimary) still returns a profile — unless
        // primary rows (e.g. a user-edited profile) already remain.
        final remainingPrimary =
            await (_db.select(_db.diveProfiles)
                  ..where(
                    (t) => t.diveId.equals(diveId) & t.isPrimary.equals(true),
                  )
                  ..limit(1))
                .get();
        if (remainingPrimary.isEmpty && promoted.computerId != null) {
          await (_db.update(_db.diveProfiles)..where(
                (t) =>
                    t.diveId.equals(diveId) &
                    t.computerId.equals(promoted.computerId!),
              ))
              .write(const DiveProfilesCompanion(isPrimary: Value(true)));
        }

        diveUpdate = diveUpdate.copyWith(
          computerId: Value(promoted.computerId),
          diveComputerModel: Value(promoted.computerModel),
          diveComputerSerial: Value(promoted.computerSerial),
          maxDepth: Value(promoted.maxDepth ?? diveRow.maxDepth),
          avgDepth: Value(promoted.avgDepth ?? diveRow.avgDepth),
          bottomTime: Value(promoted.duration ?? diveRow.bottomTime),
          waterTemp: Value(promoted.waterTemp ?? diveRow.waterTemp),
          entryTime: Value(
            promoted.entryTime?.millisecondsSinceEpoch ?? diveRow.entryTime,
          ),
          exitTime: Value(
            promoted.exitTime?.millisecondsSinceEpoch ?? diveRow.exitTime,
          ),
          surfaceIntervalSeconds: Value(
            promoted.surfaceInterval ?? diveRow.surfaceIntervalSeconds,
          ),
          cnsEnd: Value(promoted.cns ?? diveRow.cnsEnd),
          decoAlgorithm: Value(promoted.decoAlgorithm ?? diveRow.decoAlgorithm),
          gradientFactorLow: Value(
            promoted.gradientFactorLow ?? diveRow.gradientFactorLow,
          ),
          gradientFactorHigh: Value(
            promoted.gradientFactorHigh ?? diveRow.gradientFactorHigh,
          ),
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
