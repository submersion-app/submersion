import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';

/// Result of a successful consolidation: the target dive id plus the
/// pre-consolidation snapshot needed to undo it.
class DiveConsolidationOutcome {
  const DiveConsolidationOutcome({
    required this.targetDiveId,
    required this.snapshot,
  });
  final String targetDiveId;
  final DiveMergeSnapshot snapshot;
}

/// Folds one or more secondary dive-computer downloads into an existing
/// target dive as additional computer sources (multi-computer
/// consolidation). Mirrors the DiveMergeService shape: snapshot -> one
/// transaction -> one SyncEventBus notify.
///
/// Unlike DiveMergeService.apply, the target dive is MODIFIED in place (its
/// row is never re-created), and the secondaries are folded into it and
/// tombstoned. A consolidation can be applied repeatedly onto the same
/// target -- each pass unions in another computer's data sources rather
/// than nesting.
class DiveConsolidationService {
  DiveConsolidationService(this._diveRepo);

  final DiveRepository _diveRepo;

  final _uuid = const Uuid();
  final _builder = const DiveConsolidationBuilder();
  final _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Folds [secondaryDiveIds] into [targetDiveId] as additional computer
  /// sources. Throws [ArgumentError] (with the ConsolidationInvalidReason in
  /// the message) when the selection cannot be consolidated. All-or-nothing:
  /// nothing is written to the DB if validation fails.
  Future<DiveConsolidationOutcome> apply({
    required String targetDiveId,
    required List<String> secondaryDiveIds,
  }) async {
    final allIds = [targetDiveId, ...secondaryDiveIds];
    final dives = await _diveRepo.getDivesByIds(allIds);

    // classify() silently falls back to the earliest dive if primaryDiveId
    // matches nothing in the loaded selection, so the service must validate
    // the target id itself before handing off to the builder.
    if (!dives.any((d) => d.id == targetDiveId)) {
      throw ArgumentError('targetDiveId not in selection');
    }

    final plan = _builder.build(dives, primaryDiveId: targetDiveId);
    final snapshot = await DiveMergeSnapshot.capture(_db, allIds, targetDiveId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final nowDt = DateTime.now();

    // Raw rows for columns the domain entity does not carry.
    final targetRow = snapshot.diveRows.firstWhere((r) => r.id == targetDiveId);
    // Service-level same-computer guard on the FK itself (the builder can
    // only see serials).
    for (final id in secondaryDiveIds) {
      final row = snapshot.diveRows.firstWhere((r) => r.id == id);
      if (row.computerId != null && row.computerId == targetRow.computerId) {
        throw ArgumentError('sameComputer: $id shares ${row.computerId}');
      }
    }

    await _db.transaction(() async {
      await _diveRepo.backfillPrimaryDataSource(targetDiveId);

      // First consolidation: stamp the target's own children with the
      // primary computer so null stays reserved for manual entries.
      if (targetRow.computerId != null) {
        await (_db.update(_db.diveTanks)..where(
              (t) => t.diveId.equals(targetDiveId) & t.computerId.isNull(),
            ))
            .write(DiveTanksCompanion(computerId: Value(targetRow.computerId)));
        await (_db.update(_db.tankPressureProfiles)..where(
              (t) => t.diveId.equals(targetDiveId) & t.computerId.isNull(),
            ))
            .write(
              TankPressureProfilesCompanion(
                computerId: Value(targetRow.computerId),
              ),
            );
        await (_db.update(_db.diveProfileEvents)..where(
              (t) => t.diveId.equals(targetDiveId) & t.computerId.isNull(),
            ))
            .write(
              DiveProfileEventsCompanion(
                computerId: Value(targetRow.computerId),
              ),
            );
      }

      var nextTankOrder =
          snapshot.tankRows
              .where((r) => r.diveId == targetDiveId)
              .fold<int>(-1, (m, r) => r.tankOrder > m ? r.tankOrder : m) +
          1;
      final tankIdMap = <String, String>{}; // old secondary id -> id on target

      // Junction/child tables the snapshot also captures but a fold
      // previously left behind for bulkDeleteDives' cascade to drop (#449
      // review finding 1): tags, buddies, equipment, dive types, and
      // sightings union by their referenced id -- target wins, secondary
      // fills gaps. Weights copy over only when the target has none,
      // mirroring #449's avoid-double-counting-lead rule. Custom fields
      // union by key. Tracked here (outside the per-secondary loop) so a
      // second secondary in the same call, or one that duplicates the
      // first secondary's tag/buddy/etc, never double-inserts.
      final targetTagIds = <String>{
        for (final r in snapshot.tagRows.where((r) => r.diveId == targetDiveId))
          r.tagId,
      };
      final targetBuddyIds = <String>{
        for (final r in snapshot.buddyRows.where(
          (r) => r.diveId == targetDiveId,
        ))
          r.buddyId,
      };
      final targetEquipmentIds = <String>{
        for (final r in snapshot.equipmentRows.where(
          (r) => r.diveId == targetDiveId,
        ))
          r.equipmentId,
      };
      final targetDiveTypeIds = <String>{
        for (final r in snapshot.diveTypeRows.where(
          (r) => r.diveId == targetDiveId,
        ))
          r.diveTypeId,
      };
      final targetSpeciesIds = <String>{
        for (final r in snapshot.sightingRows.where(
          (r) => r.diveId == targetDiveId,
        ))
          r.speciesId,
      };
      final targetCustomFieldKeys = <String>{
        for (final r in snapshot.customFieldRows.where(
          (r) => r.diveId == targetDiveId,
        ))
          r.fieldKey,
      };
      var targetHasWeights = snapshot.weightRows.any(
        (r) => r.diveId == targetDiveId,
      );

      for (final secondary in plan.secondaries) {
        final secRow = snapshot.diveRows.firstWhere(
          (r) => r.id == secondary.id,
        );
        final offset = plan.offsetsSeconds[secondary.id] ?? 0;

        // Data sources: re-point existing rows; synthesize when none.
        final secSources = snapshot.dataSourceRows
            .where((r) => r.diveId == secondary.id)
            .toList();
        if (secSources.isEmpty) {
          // Synthesize from the dives row -- same companion mergeDives
          // builds today (dive_repository_impl.dart:4616-4652), attributed
          // to the secondary's own computer.
          await _db
              .into(_db.diveDataSources)
              .insert(
                DiveDataSourcesCompanion(
                  id: Value(_uuid.v4()),
                  diveId: Value(targetDiveId),
                  computerId: Value(secRow.computerId),
                  isPrimary: const Value(false),
                  computerModel: Value(secRow.diveComputerModel),
                  computerSerial: Value(secRow.diveComputerSerial),
                  maxDepth: Value(secRow.maxDepth),
                  avgDepth: Value(secRow.avgDepth),
                  duration: Value(secRow.bottomTime),
                  waterTemp: Value(secRow.waterTemp),
                  entryTime: Value(
                    secRow.entryTime != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            secRow.entryTime!,
                            isUtc: true,
                          )
                        : null,
                  ),
                  exitTime: Value(
                    secRow.exitTime != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            secRow.exitTime!,
                            isUtc: true,
                          )
                        : null,
                  ),
                  surfaceInterval: Value(secRow.surfaceIntervalSeconds),
                  cns: Value(secRow.cnsEnd),
                  decoAlgorithm: Value(secRow.decoAlgorithm),
                  gradientFactorLow: Value(secRow.gradientFactorLow),
                  gradientFactorHigh: Value(secRow.gradientFactorHigh),
                  importedAt: Value(nowDt),
                  createdAt: Value(nowDt),
                ),
              );
        } else {
          for (final row in secSources) {
            await _db
                .into(_db.diveDataSources)
                .insert(
                  row
                      .toCompanion(false)
                      .copyWith(
                        id: Value(_uuid.v4()),
                        diveId: Value(targetDiveId),
                        isPrimary: const Value(false),
                      ),
                );
          }
        }

        // Tanks: merged ones map, kept ones copy with attribution.
        final secTanks =
            snapshot.tankRows.where((r) => r.diveId == secondary.id).toList()
              ..sort((a, b) => a.tankOrder.compareTo(b.tankOrder));
        for (final tank in secTanks) {
          final mergeInto = plan.tankMerges[tank.id];
          if (mergeInto != null) {
            tankIdMap[tank.id] = mergeInto;
          } else {
            final freshId = _uuid.v4();
            tankIdMap[tank.id] = freshId;
            await _db
                .into(_db.diveTanks)
                .insert(
                  tank
                      .toCompanion(false)
                      .copyWith(
                        id: Value(freshId),
                        diveId: Value(targetDiveId),
                        computerId: Value(secRow.computerId),
                        tankOrder: Value(nextTankOrder++),
                      ),
                );
            await _sync.markRecordPending(
              entityType: 'diveTanks',
              recordId: freshId,
              localUpdatedAt: now,
            );
          }
        }

        // Profiles: copy every column, re-based, attributed, never primary.
        await _db.batch((batch) {
          for (final row in snapshot.profileRows.where(
            (r) => r.diveId == secondary.id,
          )) {
            batch.insert(
              _db.diveProfiles,
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(targetDiveId),
                    timestamp: Value(row.timestamp + offset),
                    computerId: Value(row.computerId ?? secRow.computerId),
                    isPrimary: const Value(false),
                  ),
            );
          }
          // Tank pressures: re-based, remapped, attributed.
          for (final row in snapshot.tankPressureRows.where(
            (r) => r.diveId == secondary.id,
          )) {
            final mappedTank = tankIdMap[row.tankId];
            if (mappedTank == null) continue;
            batch.insert(
              _db.tankPressureProfiles,
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(targetDiveId),
                    tankId: Value(mappedTank),
                    timestamp: Value(row.timestamp + offset),
                    computerId: Value(secRow.computerId),
                  ),
            );
          }
        });

        // Existing profile events, re-based, tank text-refs remapped, PLUS
        // computerId attribution (DiveMergeService.apply step 5 has no
        // computerId column to carry).
        for (final row in snapshot.eventRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          final eventId = _uuid.v4();
          await _db
              .into(_db.diveProfileEvents)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(eventId),
                      diveId: Value(targetDiveId),
                      timestamp: Value(row.timestamp + offset),
                      tankId: Value(
                        row.tankId == null
                            ? null
                            : tankIdMap[row.tankId] ?? row.tankId,
                      ),
                      computerId: Value(secRow.computerId),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveProfileEvents',
            recordId: eventId,
            localUpdatedAt: now,
          );
        }

        // Gas switches, re-based + tank FK remapped (drop unmappable).
        for (final row in snapshot.gasSwitchRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          final newTankId = tankIdMap[row.tankId];
          if (newTankId == null) continue;
          final switchId = _uuid.v4();
          await _db
              .into(_db.gasSwitches)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(switchId),
                      diveId: Value(targetDiveId),
                      tankId: Value(newTankId),
                      timestamp: Value(row.timestamp + offset),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'gasSwitches',
            recordId: switchId,
            localUpdatedAt: now,
          );
        }

        // Media re-pointed to the target BEFORE the secondary is deleted
        // (FK is setNull).
        for (final entry in snapshot.mediaDiveIds.entries.where(
          (e) => e.value == secondary.id,
        )) {
          await (_db.update(
            _db.media,
          )..where((t) => t.id.equals(entry.key))).write(
            MediaCompanion(diveId: Value(targetDiveId), updatedAt: Value(now)),
          );
          await _sync.markRecordPending(
            entityType: 'media',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }

        // Tags: union by tagId, target wins.
        for (final row in snapshot.tagRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetTagIds.add(row.tagId)) continue;
          final rowId = _uuid.v4();
          await _db
              .into(_db.diveTags)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(rowId),
                      diveId: Value(targetDiveId),
                      createdAt: Value(now),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveTags',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }

        // Buddies: union by buddyId, target wins.
        for (final row in snapshot.buddyRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetBuddyIds.add(row.buddyId)) continue;
          final rowId = _uuid.v4();
          await _db
              .into(_db.diveBuddies)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(rowId),
                      diveId: Value(targetDiveId),
                      createdAt: Value(now),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveBuddies',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }

        // Equipment: union by equipmentId. Composite-key junction (no
        // surrogate id) -- diveId+equipmentId is the identity, and
        // '$diveId|$equipmentId' is the recordId convention used elsewhere
        // for this table (see dive_repository_impl.dart bulkAddEquipment).
        for (final row in snapshot.equipmentRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetEquipmentIds.add(row.equipmentId)) continue;
          await _db
              .into(_db.diveEquipment)
              .insert(
                DiveEquipmentCompanion(
                  diveId: Value(targetDiveId),
                  equipmentId: Value(row.equipmentId),
                ),
              );
          await _sync.markRecordPending(
            entityType: 'diveEquipment',
            recordId: '$targetDiveId|${row.equipmentId}',
            localUpdatedAt: now,
          );
        }

        // Dive types: union by diveTypeId, target wins.
        for (final row in snapshot.diveTypeRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetDiveTypeIds.add(row.diveTypeId)) continue;
          final rowId = _uuid.v4();
          await _db
              .into(_db.diveDiveTypes)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(rowId),
                      diveId: Value(targetDiveId),
                      createdAt: Value(now),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveDiveTypes',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }

        // Sightings: union by speciesId -- the same species seen by both
        // computers is one sighting; keep the target's row, add
        // secondary-only species.
        for (final row in snapshot.sightingRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetSpeciesIds.add(row.speciesId)) continue;
          final rowId = _uuid.v4();
          await _db
              .into(_db.sightings)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(id: Value(rowId), diveId: Value(targetDiveId)),
              );
          await _sync.markRecordPending(
            entityType: 'sightings',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }

        // Weights: copy the secondary's ONLY if the target has none yet
        // (#449's avoid-double-counting-lead rule -- otherwise two
        // computers on the same diver would double the reported weight).
        if (!targetHasWeights) {
          for (final row in snapshot.weightRows.where(
            (r) => r.diveId == secondary.id,
          )) {
            final rowId = _uuid.v4();
            await _db
                .into(_db.diveWeights)
                .insert(
                  row
                      .toCompanion(false)
                      .copyWith(
                        id: Value(rowId),
                        diveId: Value(targetDiveId),
                        createdAt: Value(now),
                      ),
                );
            await _sync.markRecordPending(
              entityType: 'diveWeights',
              recordId: rowId,
              localUpdatedAt: now,
            );
            targetHasWeights = true;
          }
        }

        // Custom fields: union by key, target wins.
        for (final row in snapshot.customFieldRows.where(
          (r) => r.diveId == secondary.id,
        )) {
          if (!targetCustomFieldKeys.add(row.fieldKey)) continue;
          final rowId = _uuid.v4();
          await _db
              .into(_db.diveCustomFields)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(id: Value(rowId), diveId: Value(targetDiveId)),
              );
          await _sync.markRecordPending(
            entityType: 'diveCustomFields',
            recordId: rowId,
            localUpdatedAt: now,
          );
        }
      }

      // Entry/exit GPS fixes live as scalar columns on the dives row, not as
      // re-parented child rows, so a secondary's coordinates would be lost
      // when it is tombstoned below. Adopt them onto the target when the
      // target has none of its own -- target wins, the same "fill the gap"
      // rule already applied to weights above and to DiveMergeBuilder's
      // _firstNonNull(entryLocation) on the sequential-combine path. Without
      // this, consolidating a dive whose only surface fix came from a
      // secondary computer drops the coordinates and the detail-page map --
      // gated on entry/exit/site location -- disappears (#542).
      final entryFill = plan.primary.entryLocation == null
          ? plan.secondaries
                .map((s) => s.entryLocation)
                .firstWhere((l) => l != null, orElse: () => null)
          : null;
      final exitFill = plan.primary.exitLocation == null
          ? plan.secondaries
                .map((s) => s.exitLocation)
                .firstWhere((l) => l != null, orElse: () => null)
          : null;

      // Touch the target so sync carries the consolidation.
      await (_db.update(
        _db.dives,
      )..where((t) => t.id.equals(targetDiveId))).write(
        DivesCompanion(
          updatedAt: Value(now),
          entryLatitude: entryFill != null
              ? Value(entryFill.latitude)
              : const Value.absent(),
          entryLongitude: entryFill != null
              ? Value(entryFill.longitude)
              : const Value.absent(),
          exitLatitude: exitFill != null
              ? Value(exitFill.latitude)
              : const Value.absent(),
          exitLongitude: exitFill != null
              ? Value(exitFill.longitude)
              : const Value.absent(),
        ),
      );
      await _sync.markRecordPending(
        entityType: 'dives',
        recordId: targetDiveId,
        localUpdatedAt: now,
      );

      // Delete secondaries through the tombstone-logging path (this is the
      // fix for mergeDives' raw delete, which never logged deletions and
      // let sync resurrect the folded dive).
      await _diveRepo.bulkDeleteDives(secondaryDiveIds.toList());
    });

    SyncEventBus.notifyLocalChange();
    return DiveConsolidationOutcome(
      targetDiveId: targetDiveId,
      snapshot: snapshot,
    );
  }

  /// Restores the pre-consolidation state byte-for-byte: the target dive's
  /// original rows plus the secondaries, exactly as captured by [snapshot].
  ///
  /// Identical to DiveMergeService.undo except the target dive is never
  /// deleted -- it was modified in place, not created, so its original row
  /// is restored by the verbatim insertOrReplace re-inserts below rather
  /// than by re-creating it.
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Remove the target dive's current children explicitly (the mix of
      // its own stamped-in-place rows and the freshly re-parented secondary
      // rows), then re-insert the pre-consolidation snapshot verbatim below.
      // Child tables declare ON DELETE CASCADE, but that only fires when the
      // connection has `PRAGMA foreign_keys = ON`; deleting explicitly keeps
      // undo correct even where it is off, and avoids leaving orphaned
      // consolidation-output rows for the verbatim re-inserts below to
      // collide with.
      final mergedId = snapshot.mergedDiveId;

      // Tombstone the consolidation-created child rows (ids NOT in the
      // snapshot) before deleting them. The target dive survives the undo,
      // so peers that already pulled the consolidation will never cascade
      // these rows away -- child-table sync merges are upserts, and without
      // explicit tombstones a peer keeps the consolidation-output copies
      // forever (caught by consolidation_sync_roundtrip_test.dart). Rows
      // that ARE in the snapshot are re-inserted verbatim below and need no
      // tombstone -- their upsert on the peer carries the restored state.
      final snapshotIds = <String, Set<String>>{
        'diveProfiles': {for (final r in snapshot.profileRows) r.id},
        'diveTanks': {for (final r in snapshot.tankRows) r.id},
        'diveProfileEvents': {for (final r in snapshot.eventRows) r.id},
        'gasSwitches': {for (final r in snapshot.gasSwitchRows) r.id},
        'tankPressureProfiles': {
          for (final r in snapshot.tankPressureRows) r.id,
        },
        'diveDataSources': {for (final r in snapshot.dataSourceRows) r.id},
        'diveTags': {for (final r in snapshot.tagRows) r.id},
        'diveBuddies': {for (final r in snapshot.buddyRows) r.id},
        'diveEquipment': {
          for (final r in snapshot.equipmentRows)
            '${r.diveId}|${r.equipmentId}',
        },
        'diveDiveTypes': {for (final r in snapshot.diveTypeRows) r.id},
        'sightings': {for (final r in snapshot.sightingRows) r.id},
        'diveWeights': {for (final r in snapshot.weightRows) r.id},
        'diveCustomFields': {for (final r in snapshot.customFieldRows) r.id},
      };
      final currentChildIds = <String, List<String>>{
        'diveProfiles': [
          for (final r in await (_db.select(
            _db.diveProfiles,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveTanks': [
          for (final r in await (_db.select(
            _db.diveTanks,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveProfileEvents': [
          for (final r in await (_db.select(
            _db.diveProfileEvents,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'gasSwitches': [
          for (final r in await (_db.select(
            _db.gasSwitches,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'tankPressureProfiles': [
          for (final r in await (_db.select(
            _db.tankPressureProfiles,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveDataSources': [
          for (final r in await (_db.select(
            _db.diveDataSources,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveTags': [
          for (final r in await (_db.select(
            _db.diveTags,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveBuddies': [
          for (final r in await (_db.select(
            _db.diveBuddies,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveEquipment': [
          for (final r in await (_db.select(
            _db.diveEquipment,
          )..where((t) => t.diveId.equals(mergedId))).get())
            '${r.diveId}|${r.equipmentId}',
        ],
        'diveDiveTypes': [
          for (final r in await (_db.select(
            _db.diveDiveTypes,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'sightings': [
          for (final r in await (_db.select(
            _db.sightings,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveWeights': [
          for (final r in await (_db.select(
            _db.diveWeights,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
        'diveCustomFields': [
          for (final r in await (_db.select(
            _db.diveCustomFields,
          )..where((t) => t.diveId.equals(mergedId))).get())
            r.id,
        ],
      };
      for (final entry in currentChildIds.entries) {
        final keep = snapshotIds[entry.key] ?? const <String>{};
        for (final id in entry.value) {
          if (keep.contains(id)) continue;
          await _sync.logDeletion(entityType: entry.key, recordId: id);
        }
      }

      await _db.batch((batch) {
        batch.deleteWhere(_db.diveProfiles, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.diveTanks, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.diveWeights, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(
          _db.diveCustomFields,
          (t) => t.diveId.equals(mergedId),
        );
        batch.deleteWhere(_db.diveEquipment, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.diveDiveTypes, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.diveTags, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.diveBuddies, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(_db.sightings, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(
          _db.diveProfileEvents,
          (t) => t.diveId.equals(mergedId),
        );
        batch.deleteWhere(_db.gasSwitches, (t) => t.diveId.equals(mergedId));
        batch.deleteWhere(
          _db.tankPressureProfiles,
          (t) => t.diveId.equals(mergedId),
        );
        batch.deleteWhere(
          _db.diveDataSources,
          (t) => t.diveId.equals(mergedId),
        );
        batch.deleteWhere(_db.tideRecords, (t) => t.diveId.equals(mergedId));
      });

      // Re-insert dives with ORIGINAL ids; newer HLC beats the tombstones.
      //
      // insertOrReplace (not a plain insert) throughout this method: child
      // tables use ON DELETE CASCADE, which only fires when the DB
      // connection has `PRAGMA foreign_keys = ON` (always true in the
      // running app; some test harnesses disable it). Falling back to plain
      // insert would then collide with rows the cascade never actually
      // removed.
      for (final row in snapshot.diveRows) {
        await _db
            .into(_db.dives)
            .insert(
              row.toCompanion(false).copyWith(updatedAt: Value(now)),
              mode: InsertMode.insertOrReplace,
            );
        await _sync.markRecordPending(
          entityType: 'dives',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }

      // Tanks BEFORE the batch below: tankPressureProfiles.tankId (and
      // gasSwitches.tankId further down) are FKs into diveTanks, and FK
      // enforcement is immediate under `PRAGMA foreign_keys = ON`, so the
      // parent tank rows must exist before any row that references them.
      for (final r in snapshot.tankRows) {
        await _db
            .into(_db.diveTanks)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }

      // Child rows verbatim (original ids never collide with consolidation
      // output: consolidated children all had fresh ids).
      await _db.batch((batch) {
        for (final r in snapshot.profileRows) {
          batch.insert(
            _db.diveProfiles,
            r.toCompanion(false),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final r in snapshot.tankPressureRows) {
          batch.insert(
            _db.tankPressureProfiles,
            r.toCompanion(false),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final r in snapshot.dataSourceRows) {
          batch.insert(
            _db.diveDataSources,
            r.toCompanion(false),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final r in snapshot.tideRows) {
          batch.insert(
            _db.tideRecords,
            r.toCompanion(false),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final r in snapshot.equipmentRows) {
          batch.insert(
            _db.diveEquipment,
            r.toCompanion(false),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      for (final r in snapshot.weightRows) {
        await _db
            .into(_db.diveWeights)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveWeights',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.customFieldRows) {
        await _db
            .into(_db.diveCustomFields)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveCustomFields',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.diveTypeRows) {
        await _db
            .into(_db.diveDiveTypes)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveDiveTypes',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.tagRows) {
        await _db
            .into(_db.diveTags)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveTags',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.buddyRows) {
        await _db
            .into(_db.diveBuddies)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveBuddies',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.sightingRows) {
        await _db
            .into(_db.sightings)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'sightings',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.eventRows) {
        await _db
            .into(_db.diveProfileEvents)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.gasSwitchRows) {
        await _db
            .into(_db.gasSwitches)
            .insert(r.toCompanion(false), mode: InsertMode.insertOrReplace);
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }

      // Restore media pointers.
      for (final entry in snapshot.mediaDiveIds.entries) {
        await (_db.update(
          _db.media,
        )..where((t) => t.id.equals(entry.key))).write(
          MediaCompanion(diveId: Value(entry.value), updatedAt: Value(now)),
        );
        await _sync.markRecordPending(
          entityType: 'media',
          recordId: entry.key,
          localUpdatedAt: now,
        );
      }
    });

    SyncEventBus.notifyLocalChange();
  }
}
