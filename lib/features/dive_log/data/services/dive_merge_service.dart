import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as series;
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
  final _profileSeries = ProfileSeriesRepository();
  final _tankSeries = TankPressureSeriesRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// Reads (does not mutate) every row belonging to [diveIds] so a merge
  /// can later be applied and, if needed, undone.
  Future<DiveMergeSnapshot> captureSnapshot(
    List<String> diveIds,
    String mergedDiveId,
  ) async {
    return DiveMergeSnapshot.capture(_db, diveIds, mergedDiveId);
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

  /// The draft that hosts a gap's surface samples: the segment's primary
  /// series, else one with a computer, else its first series.
  _SeriesDraft? _adjacentDraft(List<_SeriesDraft> drafts, String diveId) {
    final segment = drafts.where((d) => d.diveId == diveId).toList();
    if (segment.isEmpty) return null;
    for (final d in segment) {
      if (d.isPrimary) return d;
    }
    for (final d in segment) {
      if (d.computerId != null) return d;
    }
    return segment.first;
  }

  /// Median inter-sample delta of the previous segment (then the next, then
  /// 60 s), over every series of that segment.
  int _nativeSampleIntervalSecondsOf(
    List<series.ProfileSeries> originals,
    MergeGap gap,
  ) {
    for (final diveId in [gap.afterDiveId, gap.beforeDiveId]) {
      final timestamps = [
        for (final s in originals)
          if (s.diveId == diveId)
            for (final p in s.samples) p.timestamp,
      ]..sort();
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
    // Every series this operation will carry across has to decode: it
    // re-bases the samples onto the merged timeline and then deletes the
    // dives that hold them, and reads answer an unreadable blob with null,
    // so one would be dropped on the way through and then deleted with its
    // dive. Checked before anything is written.
    final unreadable = [
      ...await _profileSeries.unreadableSeriesIds(diveIds),
      ...await _tankSeries.unreadableSeriesIds(diveIds),
    ];
    if (unreadable.isNotEmpty) throw UnreadableSeriesException(unreadable);

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

      // Owning-source ids for the merged dive (issue #1149). The source
      // rows themselves are not inserted until step 10, but the profile
      // copy below has to reference them, so mint the ids up front and let
      // step 10 reuse them. A profile row whose sourceId names no copied row
      // falls back to its own segment's source, so samples never end up
      // pointing at a row on a dive this merge is about to consume.
      final mergedSourceIds = <String, String>{
        for (final row in snapshot.dataSourceRows) row.id: _uuid.v4(),
      };
      // Inserted here rather than at their step-10 slot: a profile series
      // row's sourceId is a real FK and foreign_keys is ON, so the parent
      // rows must land before the samples that reference them.
      //
      // Carried as provenance; NEVER primary (a merged profile is
      // user-authored -- reparse must not rewrite it).
      //     CAVEAT (#1164): isPrimary false only stops reparse from
      //     rewriting the dives row and tanks. ReparseService step 4 calls
      //     _replaceDiveProfiles unconditionally, so re-parsing a merged
      //     dive today still wipes the merged profile. Tracked separately.
      // DiveRepository.saveComputerReading does not call
      // markRecordPending for diveDataSources rows either -- it relies on
      // the parent dive's pending record (step 1) to carry the change, so
      // no per-row markRecordPending here mirrors that.
      //
      // EVERY row is carried, including several sharing one computerId --
      // the shape a same-computer split-pair merge produces. Do NOT collapse
      // them here (#1045): rows that share a computerId are not duplicates.
      // Each is the sole surviving copy of one download's rawData,
      // rawFingerprint and sourceUuid once step 13 deletes the originals, and
      // all three are load-bearing:
      //   - getSourceKeysByDiveId unions source_uuid/raw_fingerprint across
      //     ALL of a dive's rows so a re-download of EITHER half resolves as
      //     a duplicate; dropping a row makes that half import as a new dive.
      //   - ReparseService.getSourcesForDiveReparse selects on rawData, so a
      //     dropped row's bytes can never be re-parsed by a later
      //     libdivecomputer.
      // The duplicate is a display-side concern only, and is canonicalized on
      // read by _canonicalDataSourceRows (#1005). The gap that comment
      // described came from the old row-per-sample dive_profiles table, which
      // attributed samples by computerId alone; computerId was then treated
      // as a per-dive unique source key the schema never guaranteed. A profile
      // series row's sourceId closes that gap (#1149): each carried row keeps
      // its own id here and the copied samples point at it, so the strands
      // stay separable without a lossy write.
      for (final row in snapshot.dataSourceRows) {
        await _db
            .into(_db.diveDataSources)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(mergedSourceIds[row.id]!),
                    diveId: Value(mergedId),
                    isPrimary: const Value(false),
                  ),
            );
      }

      String? mergedSourceIdFor(String diveId, String? sourceId) {
        final mapped = mergedSourceIds[sourceId];
        if (mapped != null) return mapped;
        final segment = snapshot.dataSourceRows
            .where((r) => r.diveId == diveId)
            .toList();
        if (segment.isEmpty) return null;
        final owner = segment.firstWhere(
          (r) => r.isPrimary,
          orElse: () => segment.first,
        );
        return mergedSourceIds[owner.id];
      }

      // 2. Profile series re-based onto the merged timeline (preserves
      //    computerId/isPrimary/samples), one draft per original series.
      //    Read live, before anything is deleted (step 13 removes the
      //    sources).
      final seriesByDive = await _profileSeries.getSeriesForDives(diveIds);
      final originals = [
        for (final id in diveIds)
          ...(seriesByDive[id] ?? const <series.ProfileSeries>[]),
      ];
      final drafts = <_SeriesDraft>[
        for (final s in originals)
          _SeriesDraft(
            diveId: s.diveId,
            computerId: s.computerId,
            sourceId: s.sourceId,
            isPrimary: s.isPrimary,
            samples: [
              for (final p in s.samples)
                p.shiftedBy(result.segmentOffsetsSeconds[s.diveId] ?? 0),
            ],
          ),
      ];
      // 3. Synthesized 0-depth samples across each gap (skip tiny gaps), at
      //    the source profile's native cadence and hugging both boundaries:
      //    a 2-point fill leaves a sample hole that the chart's curve
      //    smoothing draws as a swooping line with an overshoot loop (#449
      //    manual test). Appended to the adjacent segment's hosting draft so
      //    getProfilesBySource (dive_repository_impl.dart) doesn't see a
      //    bogus extra 'original' source next to the real computer's rows.
      for (final gap in result.gaps) {
        if (gap.endSeconds - gap.startSeconds < 2) continue;
        final host =
            _adjacentDraft(drafts, gap.afterDiveId) ??
            _adjacentDraft(drafts, gap.beforeDiveId);
        final interval = _nativeSampleIntervalSecondsOf(originals, gap);
        // Cap the fill so a very long surface interval (hours/days) at a
        // dense cadence can't generate tens of thousands of rows in one
        // transaction; a few hundred flat points render identically.
        final minStep = ((gap.endSeconds - gap.startSeconds) / 300).ceil();
        final step = interval > minStep ? interval : minStep;
        final timestamps = <int>[
          for (var ts = gap.startSeconds + 1; ts < gap.endSeconds; ts += step)
            ts,
        ];
        if (timestamps.last != gap.endSeconds - 1) {
          timestamps.add(gap.endSeconds - 1);
        }
        final surface = [
          for (final ts in timestamps) ProfileSample(timestamp: ts, depth: 0),
        ];
        if (host != null) {
          host.samples.addAll(surface);
        } else {
          // No profile on either side: mirrors what a dive_profiles row
          // carried when unattributed, a null computer, a null source and
          // is_primary true; today's series row keeps the same convention.
          drafts.add(
            _SeriesDraft(
              diveId: gap.afterDiveId,
              computerId: null,
              sourceId: null,
              isPrimary: true,
              samples: surface,
              synthetic: true,
            ),
          );
        }
      }
      for (final d in drafts) {
        if (d.samples.isEmpty) continue;
        await _profileSeries.insertSeries(
          diveId: mergedId,
          computerId: d.computerId,
          sourceId: d.synthetic
              ? null
              : mergedSourceIdFor(d.diveId, d.sourceId),
          isPrimary: d.isPrimary,
          samples: d.samples,
          now: now,
        );
      }

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

      // 7. Tank pressure series, re-based + remapped onto the merged tanks.
      //    Each series insert is marked pending and stamped with an hlc by
      //    the repository, same as createDive's profile series.
      for (final id in diveIds) {
        for (final s in await _tankSeries.getSeriesForDive(id)) {
          final newTankId = result.tankIdMap[s.tankId];
          if (newTankId == null || s.samples.isEmpty) continue;
          final offset = result.segmentOffsetsSeconds[s.diveId] ?? 0;
          await _tankSeries.insertSeries(
            diveId: mergedId,
            tankId: newTankId,
            computerId: s.computerId,
            samples: [for (final p in s.samples) p.shiftedBy(offset)],
            now: now,
          );
        }
      }

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

      // 10. Data sources are inserted ahead of step 2 -- see the note there.

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
      // Series are tombstoned through the repository (row-level sync), not
      // the raw batch below: a cascade delete from deleteDive further down
      // would remove them without logging a deletion, and the merge's
      // series would never leave the other peers.
      await _profileSeries.deleteForDive(mergedId);
      await _tankSeries.deleteForDive(mergedId);
      await _db.batch((batch) {
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
          _db.diveDataSources,
          (t) => t.diveId.equals(mergedId),
        );
        batch.deleteWhere(_db.tideRecords, (t) => t.diveId.equals(mergedId));
      });
      // cascadeMedia: false - this undo re-points the merged dive's media
      // back to the restored sources below; the cascade would delete (and
      // tombstone) those rows before the restore could reach them.
      await _diveRepo.deleteDive(mergedId, cascadeMedia: false);

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

      // Tanks BEFORE the batch below: tank_pressure_series.tankId (and
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
      // Series restored after the batch above: dataSourceRows and diveTanks
      // (inserted earlier) are the series' FK parents and must be back
      // first.
      for (final r in snapshot.profileSeriesRows) {
        await _profileSeries.restoreSeriesRow(r, now: now);
      }
      for (final r in snapshot.tankSeriesRows) {
        await _tankSeries.restoreSeriesRow(r, now: now);
      }
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

/// One profile series being assembled for the merged dive: an original
/// series re-based onto the merged timeline, plus any gap-fill samples
/// appended onto its chosen host (see [DiveMergeService._adjacentDraft]).
/// [samples] is growable and mutated only by [DiveMergeService.apply]
/// before the single insert. [synthetic] marks a gap-fill draft created
/// because neither adjacent segment had a series to host it: it carries no
/// real source, so [DiveMergeService.apply] gives it a null sourceId rather
/// than resolving one through `mergedSourceIdFor`.
class _SeriesDraft {
  _SeriesDraft({
    required this.diveId,
    required this.computerId,
    required this.sourceId,
    required this.isPrimary,
    required this.samples,
    this.synthetic = false,
  });

  final String diveId;
  final String? computerId;
  final String? sourceId;
  final bool isPrimary;
  final bool synthetic;
  final List<ProfileSample> samples;
}
