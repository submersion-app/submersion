import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

/// Result of a successful merge: the new dive plus the pre-merge snapshot
/// needed to undo it.
class DiveMergeOutcome {
  const DiveMergeOutcome({required this.mergedDive, required this.snapshot});
  final domain.Dive mergedDive;
  final DiveMergeSnapshot snapshot;
}

/// Applies and undoes sequential dive combines (#449).
/// Mirrors the BulkDiveEditService shape: snapshot -> one transaction ->
/// one SyncEventBus notify.
class DiveMergeService {
  DiveMergeService(this._diveRepo);

  final DiveRepository _diveRepo;

  final _uuid = const Uuid();
  final _builder = const DiveMergeBuilder();
  final _sync = SyncRepository();
  final _tagRepository = TagRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Reads (does not mutate) every row belonging to [diveIds] so a merge
  /// can later be applied and, if needed, undone.
  Future<DiveMergeSnapshot> captureSnapshot(
    List<String> diveIds,
    String mergedDiveId,
  ) async {
    final mediaRows = await (_db.select(
      _db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    return DiveMergeSnapshot(
      mergedDiveId: mergedDiveId,
      diveRows: await (_db.select(
        _db.dives,
      )..where((t) => t.id.isIn(diveIds))).get(),
      profileRows: await (_db.select(
        _db.diveProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tankRows: await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      weightRows: await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      customFieldRows: await (_db.select(
        _db.diveCustomFields,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      equipmentRows: await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      diveTypeRows: await (_db.select(
        _db.diveDiveTypes,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tagRows: await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      buddyRows: await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      sightingRows: await (_db.select(
        _db.sightings,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      eventRows: await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      gasSwitchRows: await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tankPressureRows: await (_db.select(
        _db.tankPressureProfiles,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      dataSourceRows: await (_db.select(
        _db.diveDataSources,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      tideRows: await (_db.select(
        _db.tideRecords,
      )..where((t) => t.diveId.isIn(diveIds))).get(),
      mediaDiveIds: {for (final m in mediaRows) m.id: m.diveId!},
    );
  }

  /// Returns the first non-null [pick] value in chronological order, or
  /// null if none of [orderedRows] has one.
  T? _firstNonNullDiveColumn<T>(
    List<Dive> orderedRows,
    T? Function(Dive) pick,
  ) {
    for (final row in orderedRows) {
      final value = pick(row);
      if (value != null) return value;
    }
    return null;
  }

  /// The first profile row belonging to source dive [diveId] that carries a
  /// computerId, used to attribute synthesized gap samples to the correct
  /// source (#449 review F1).
  DiveProfile? _adjacentProfileRow(List<DiveProfile> rows, String diveId) {
    for (final row in rows) {
      if (row.diveId == diveId && row.computerId != null) return row;
    }
    return null;
  }

  /// The native sample cadence around [gap]: the median inter-sample delta
  /// of the previous segment's profile (falling back to the next segment's,
  /// then to 60s when neither has samples). Synthesized surface samples use
  /// this so they are indistinguishable from the computer's own rhythm.
  int _nativeSampleIntervalSeconds(List<DiveProfile> rows, MergeGap gap) {
    for (final diveId in [gap.afterDiveId, gap.beforeDiveId]) {
      final timestamps =
          rows.where((r) => r.diveId == diveId).map((r) => r.timestamp).toList()
            ..sort();
      final deltas = <int>[
        for (var i = 1; i < timestamps.length; i++)
          if (timestamps[i] - timestamps[i - 1] > 0)
            timestamps[i] - timestamps[i - 1],
      ];
      if (deltas.isNotEmpty) {
        deltas.sort();
        return deltas[deltas.length ~/ 2];
      }
    }
    return 60;
  }

  /// Merges [diveIds] into one new dive inside a single transaction.
  ///
  /// Throws [ArgumentError] (via [DiveMergeBuilder.build]) if the selection
  /// is not a valid sequential combine (too few dives, mixed divers, or
  /// overlapping timelines) -- nothing is read from the DB via a snapshot
  /// and nothing is written in that case.
  Future<DiveMergeOutcome> apply(List<String> diveIds) async {
    final sources = await _diveRepo.getDivesByIds(diveIds);
    final tagsByDive = await _tagRepository.getTagsForDives(diveIds);

    // Sightings from rows (speciesName not needed for persistence).
    final sightingRows = await (_db.select(
      _db.sightings,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    final sightingsByDive = <String, List<domain.MarineSighting>>{};
    for (final row in sightingRows) {
      sightingsByDive
          .putIfAbsent(row.diveId, () => [])
          .add(
            domain.MarineSighting(
              id: row.id,
              speciesId: row.speciesId,
              speciesName: '',
              count: row.count,
              notes: row.notes,
            ),
          );
    }

    // Throws ArgumentError for non-sequential selections; nothing has been
    // written yet, so the DB is untouched on failure.
    final result = _builder.build(
      sources,
      tagsByDive: tagsByDive,
      sightingsByDive: sightingsByDive,
      idGenerator: _uuid.v4,
    );
    final mergedId = result.mergedDive.id;
    final snapshot = await captureSnapshot(diveIds, mergedId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Merged dive + entity-carried children (tanks, weights, custom
      //    fields, profile=[], equipment, tags, dive types).
      await _diveRepo.createDive(result.mergedDive);

      // 1b. Columns the domain Dive entity has no field for (computerId,
      //     importVersion, cnsStart/cnsEnd/otu) never travel through
      //     createDive's round-trip through the domain layer, so backfill
      //     them directly from the source rows here, chronologically
      //     (sortedSources order), first-non-null wins per column. Same
      //     transaction/record as createDive's write above, so no separate
      //     markRecordPending is needed.
      final chronologicalDiveRows = [
        for (final source in result.sortedSources)
          snapshot.diveRows.firstWhere((r) => r.id == source.id),
      ];
      await (_db.update(_db.dives)..where((t) => t.id.equals(mergedId))).write(
        DivesCompanion(
          computerId: Value(
            _firstNonNullDiveColumn(chronologicalDiveRows, (r) => r.computerId),
          ),
          importVersion: Value(
            _firstNonNullDiveColumn(
              chronologicalDiveRows,
              (r) => r.importVersion,
            ),
          ),
          // cnsStart is NOT NULL (default 0), so the earliest source's value
          // is always the "first non-null" one.
          cnsStart: Value(chronologicalDiveRows.first.cnsStart),
          cnsEnd: Value(
            _firstNonNullDiveColumn(chronologicalDiveRows, (r) => r.cnsEnd),
          ),
          otu: Value(
            _firstNonNullDiveColumn(chronologicalDiveRows, (r) => r.otu),
          ),
        ),
      );

      // 2. Profile rows copied directly (preserves computerId/isPrimary/
      //    temperature/sensor columns), re-based onto the merged timeline.
      await _db.batch((batch) {
        for (final row in snapshot.profileRows) {
          final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
          batch.insert(
            _db.diveProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(mergedId),
                  timestamp: Value(row.timestamp + offset),
                ),
          );
        }
        // 3. Synthesized 0-depth samples across each gap (skip tiny gaps),
        //    at the source profile's native cadence and hugging both
        //    boundaries: a 2-point fill leaves a sample hole that the
        //    chart's curve smoothing draws as a swooping line with an
        //    overshoot loop (#449 manual test). Stamped with the adjacent
        //    segment's computerId/isPrimary so getProfilesBySource
        //    (dive_repository_impl.dart) doesn't see a bogus extra
        //    'original' source next to the real computer's rows.
        for (final gap in result.gaps) {
          if (gap.endSeconds - gap.startSeconds < 2) continue;
          final adjacent =
              _adjacentProfileRow(snapshot.profileRows, gap.afterDiveId) ??
              _adjacentProfileRow(snapshot.profileRows, gap.beforeDiveId);
          final interval = _nativeSampleIntervalSeconds(
            snapshot.profileRows,
            gap,
          );
          final timestamps = <int>[
            for (
              var ts = gap.startSeconds + 1;
              ts < gap.endSeconds;
              ts += interval
            )
              ts,
          ];
          if (timestamps.last != gap.endSeconds - 1) {
            timestamps.add(gap.endSeconds - 1);
          }
          for (final ts in timestamps) {
            batch.insert(
              _db.diveProfiles,
              DiveProfilesCompanion.insert(
                id: _uuid.v4(),
                diveId: mergedId,
                timestamp: ts,
                depth: 0,
                computerId: Value(adjacent?.computerId),
                isPrimary: Value(adjacent?.isPrimary ?? true),
              ),
            );
          }
        }
      });

      // 4. Surface events at each gap boundary (skip tiny gaps -- same
      //    threshold as step 3's synthesized samples).
      for (final gap in result.gaps) {
        if (gap.endSeconds - gap.startSeconds < 2) continue;
        for (final ts in [gap.startSeconds, gap.endSeconds]) {
          final eventId = _uuid.v4();
          await _db
              .into(_db.diveProfileEvents)
              .insert(
                DiveProfileEventsCompanion.insert(
                  id: eventId,
                  diveId: mergedId,
                  timestamp: ts,
                  eventType: 'surface',
                  severity: const Value('info'),
                  depth: const Value(0),
                  source: const Value('app'),
                  createdAt: now,
                ),
              );
          await _sync.markRecordPending(
            entityType: 'diveProfileEvents',
            recordId: eventId,
            localUpdatedAt: now,
          );
        }
      }

      // 5. Existing profile events, re-based, tank text-refs remapped.
      for (final row in snapshot.eventRows) {
        final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
        final eventId = _uuid.v4();
        await _db
            .into(_db.diveProfileEvents)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(eventId),
                    diveId: Value(mergedId),
                    timestamp: Value(row.timestamp + offset),
                    tankId: Value(
                      row.tankId == null
                          ? null
                          : result.tankIdMap[row.tankId] ?? row.tankId,
                    ),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: eventId,
          localUpdatedAt: now,
        );
      }

      // 6. Gas switches, re-based + tank FK remapped (drop unmappable).
      for (final row in snapshot.gasSwitchRows) {
        final newTankId = result.tankIdMap[row.tankId];
        if (newTankId == null) continue;
        final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
        final switchId = _uuid.v4();
        await _db
            .into(_db.gasSwitches)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(switchId),
                    diveId: Value(mergedId),
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

      // 7. Tank pressure series, re-based + remapped (parent-dive sync
      //    pattern: no per-row pending, same as createDive's profile rows).
      await _db.batch((batch) {
        for (final row in snapshot.tankPressureRows) {
          final newTankId = result.tankIdMap[row.tankId];
          if (newTankId == null) continue;
          final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
          batch.insert(
            _db.tankPressureProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(mergedId),
                  tankId: Value(newTankId),
                  timestamp: Value(row.timestamp + offset),
                ),
          );
        }
      });

      // 8. Buddies: union by buddyId, chronological (sortedSources order).
      final seenBuddies = <String>{};
      for (final source in result.sortedSources) {
        for (final row in snapshot.buddyRows.where(
          (r) => r.diveId == source.id,
        )) {
          if (!seenBuddies.add(row.buddyId)) continue;
          final buddyRowId = _uuid.v4();
          await _db
              .into(_db.diveBuddies)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(buddyRowId),
                      diveId: Value(mergedId),
                      createdAt: Value(now),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveBuddies',
            recordId: buddyRowId,
            localUpdatedAt: now,
          );
        }
      }

      // 9. Merged sightings (already unioned by the builder).
      for (final s in result.mergedSightings) {
        await _db
            .into(_db.sightings)
            .insert(
              SightingsCompanion.insert(
                id: s.id,
                diveId: mergedId,
                speciesId: s.speciesId,
                count: Value(s.count),
                notes: Value(s.notes),
              ),
            );
        await _sync.markRecordPending(
          entityType: 'sightings',
          recordId: s.id,
          localUpdatedAt: now,
        );
      }

      // 10. Data sources carried as provenance; NEVER primary (a merged
      //     profile is user-authored -- reparse must not rewrite it).
      // saveComputerReading (dive_repository_impl.dart:4437) does not call
      // markRecordPending for diveDataSources rows either -- it relies on
      // the parent dive's pending record (step 1) to carry the change, so
      // no per-row markRecordPending here mirrors that.
      for (final row in snapshot.dataSourceRows) {
        await _db
            .into(_db.diveDataSources)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(mergedId),
                    isPrimary: const Value(false),
                  ),
            );
      }

      // 11. Tide record: first dive's only.
      final firstTide = snapshot.tideRows
          .where((r) => r.diveId == result.sortedSources.first.id)
          .toList();
      if (firstTide.isNotEmpty) {
        final tideId = _uuid.v4();
        await _db
            .into(_db.tideRecords)
            .insert(
              firstTide.first
                  .toCompanion(false)
                  .copyWith(id: Value(tideId), diveId: Value(mergedId)),
            );
        await _sync.markRecordPending(
          entityType: 'tideRecords',
          recordId: tideId,
          localUpdatedAt: now,
        );
      }

      // 12. Re-point media BEFORE deleting sources (FK is setNull).
      for (final mediaId in snapshot.mediaDiveIds.keys) {
        await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
          MediaCompanion(diveId: Value(mergedId), updatedAt: Value(now)),
        );
        await _sync.markRecordPending(
          entityType: 'media',
          recordId: mediaId,
          localUpdatedAt: now,
        );
      }

      // 13. Delete sources through the tombstone-logging path.
      await _diveRepo.bulkDeleteDives(diveIds);
    });

    SyncEventBus.notifyLocalChange();
    return DiveMergeOutcome(mergedDive: result.mergedDive, snapshot: snapshot);
  }

  /// Restores the source dives exactly and removes the merged dive.
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Remove the merged dive's own children explicitly, then the dive row
      // itself (tombstone logged so the merge's remote copies are deleted
      // too). Child tables declare ON DELETE CASCADE, but that only fires
      // when the connection has `PRAGMA foreign_keys = ON`; deleting
      // explicitly keeps undo correct even where it is off, and avoids
      // leaving orphaned merge-output rows for the verbatim re-inserts below
      // to collide with.
      final mergedId = snapshot.mergedDiveId;
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
      await _diveRepo.deleteDive(mergedId);

      // Re-insert dives with ORIGINAL ids; newer HLC beats the tombstones.
      //
      // insertOrReplace (not a plain insert) throughout this method: child
      // tables use ON DELETE CASCADE, which only fires when the DB
      // connection has `PRAGMA foreign_keys = ON` (always true in the
      // running app; some test harnesses disable it). Falling back to plain
      // insert would then collide with rows deleteDive's cascade never
      // actually removed.
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

      // Child rows verbatim (original ids never collide with merge output:
      // merged children all had fresh ids).
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
