import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/merge_gap_fill.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as series;
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_log/domain/services/dive_segment_grouper.dart';
import 'package:submersion/features/dive_log/domain/services/shared_tank_pressures.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';

/// One stretch of a combined dive's timeline, with the provenance rows that
/// recorded it. [sourceIds] is in canonical order (primary first, then
/// oldest), so the first is the segment's lead row.
class UncombineSegment {
  const UncombineSegment({
    required this.sourceIds,
    required this.startSeconds,
    required this.endSeconds,
  });

  final List<String> sourceIds;

  /// Bounds on the combined dive's timeline, in seconds from its start.
  final int startSeconds;
  final int endSeconds;

  /// Whether [timestamp], in combined-timeline seconds, falls in this
  /// segment. Segments never overlap, so no timestamp belongs to two.
  bool contains(int timestamp) =>
      timestamp >= startSeconds && timestamp <= endSeconds;
}

/// Pulls a combined dive back apart into the dives a Combine stitched
/// together (issue #1504).
///
/// Combine's undo is a snackbar, and once it dismisses the merged dive is the
/// only record of what happened. [DiveSplitService] moves ONE data source out
/// of a dive, which is the inverse of consolidation, not of combine: on a
/// dive whose halves collapse to a single display source it is not even
/// offered (issue #1451 made them collapse), and on a dive consolidated
/// before it was combined it would move one computer's whole recording rather
/// than one half of the dive. This service is the inverse of combine.
///
/// Segments are read off the timeline rather than from a stored marker, using
/// [groupSourcesIntoSegments] -- the same overlap test the chart uses to tell
/// consecutive sources from competing ones. That makes the action work on
/// dives combined before it shipped, which is the whole point: the user who
/// needs it has already lost the snackbar. A combine of a combine un-nests
/// completely, because every segment of it is disjoint from the others.
///
/// **What comes back and what does not.** Each segment's profile samples,
/// tank pressures, profile events and gas switches return to their own dive,
/// re-based so the restored dive starts at zero again, with the synthesized
/// surface fill that bridged the gaps dropped.
///
/// The logbook entry does not come apart. Combine unions it with no record of
/// which dive each value came from, so all of it stays on the original dive:
/// the linked rows (buddies, tags, equipment, weights, sightings, custom
/// fields, media) and equally the scalars on the dive row itself -- name,
/// number, notes, buddy, divemaster, diver role, boat, operator, dive centre,
/// trip, course, rating, favourite, weighting, statistics exclusions and
/// import provenance. Copying the dive row wholesale and clearing only a
/// couple of those quietly duplicated the rest onto every restored dive,
/// which is not what the confirmation dialog promises.
///
/// What carries is what describes the dive itself rather than the log of it:
/// its timings, depths and temperatures, the deco and CCR settings it was run
/// on, the water and weather it happened in, the computer that recorded it,
/// and its site -- both halves happened in one place. Timings and surface
/// fixes are taken per segment, so a restored half reports its own runtime
/// and its own GPS rather than the whole combine's. Tanks are cloned rather
/// than moved, because they are the dive's gas plan and every segment was
/// breathing them.
///
/// Mirrors the split and consolidation services' sync discipline: one
/// transaction, per-row tombstones for every moved row (the original dive
/// survives, so peers would otherwise keep upsert copies of them forever),
/// markRecordPending for new rows, one SyncEventBus notify.
class DiveUncombineService {
  DiveUncombineService(this._diveRepo);

  // Retained for parity with the split and consolidation services'
  // constructor shape; the work itself is done on raw rows.
  // ignore: unused_field
  final DiveRepository _diveRepo;

  final _uuid = const Uuid();
  final _sync = SyncRepository();
  final _profileSeries = ProfileSeriesRepository();
  final _tankSeries = TankPressureSeriesRepository();
  final _log = LoggerService.forClass(DiveUncombineService);

  AppDatabase get _db => DatabaseService.instance.database;

  /// The segments [diveId] reads as, in timeline order. A dive that was never
  /// combined yields one segment, or none when it has no provenance rows at
  /// all, so `length >= 2` is the test for "this dive can be separated".
  Future<List<UncombineSegment>> plan(String diveId) async {
    final rows = await _sourceRows(diveId);
    if (rows.isEmpty) return const [];
    final diveRow = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (diveRow == null) return const [];
    return _segmentsOf(
      rows: rows,
      seriesRows: await _profileSeries.getSpansForDive(diveId),
      diveRow: diveRow,
      gaps: await _gapsOf(diveId),
    );
  }

  /// Restores every segment of [diveId] after the first into its own dive and
  /// returns the new dives' ids in timeline order. The first segment stays on
  /// [diveId] together with the whole logbook entry.
  ///
  /// Throws [ArgumentError] when the dive reads as a single segment: it was
  /// never combined, or a reparse has since rewritten its timeline so the
  /// segments can no longer be told apart. Throws
  /// [UnreadableSeriesException] when any of the dive's series fails to
  /// decode. All-or-nothing: one transaction, full rollback on any failure.
  Future<List<String>> separate({required String diveId}) async {
    final newDiveIds = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    var segmentCount = 0;

    // The whole write is one transaction, so a failure anywhere rolls the
    // separation back and the user is told it did not happen. That is the
    // right outcome and a silent one: log what actually broke before the
    // caller turns it into a snackbar, because nothing about the resulting
    // database says a separation was ever attempted.
    try {
      await _db.transaction(() async {
        // EVERY read is inside the transaction, the plan included. A read
        // outside is a torn one, deciding what moves from a snapshot another
        // writer can change before the moves are applied -- and the segment
        // plan is the most consequential of those decisions, since it names
        // which provenance rows leave the dive. Both guards below are reads
        // too, so they belong in here with the rest.
        //
        // Every series has to decode before anything moves. A series that
        // reads as null (an unreadable blob) is invisible to the grouping
        // below, so its samples would neither move nor be trimmed while the
        // tank beneath it was cloned away. Split, merge and consolidate open
        // with the same guard.
        final unreadable = [
          ...await _profileSeries.unreadableSeriesIds([diveId]),
          ...await _tankSeries.unreadableSeriesIds([diveId]),
        ];
        if (unreadable.isNotEmpty) throw UnreadableSeriesException(unreadable);

        final diveRow = await (_db.select(
          _db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        final sourceRows = await _sourceRows(diveId);
        final allSeries = await _profileSeries.getSeriesForDive(diveId);
        final allPressures = await _tankSeries.getSeriesForDive(diveId);
        final allTanks = await (_db.select(
          _db.diveTanks,
        )..where((t) => t.diveId.equals(diveId))).get();
        final allEvents = await (_db.select(
          _db.diveProfileEvents,
        )..where((t) => t.diveId.equals(diveId))).get();
        final allSwitches = await (_db.select(
          _db.gasSwitches,
        )..where((t) => t.diveId.equals(diveId))).get();
        final gaps = MergeGapFill.readFrom(allEvents);

        final segments = _segmentsOf(
          rows: sourceRows,
          seriesRows: await _profileSeries.getSpansForDive(diveId),
          diveRow: diveRow,
          gaps: gaps,
        );
        segmentCount = segments.length;
        if (segments.length < 2) {
          throw ArgumentError('dive $diveId does not read as a combined dive');
        }
        final sourceById = {for (final row in sourceRows) row.id: row};
        // A cylinder breathed in more than one segment is one tank carrying
        // the combined start and end pressures (#2036). Each dive it lands
        // on takes its own from the readings it keeps.
        final sharedTankIds = tanksSharedAcrossSegments(allPressures, (t) {
          final index = segments.indexWhere((s) => s.contains(t));
          return index < 0 ? null : index;
        });

        for (final segment in segments.skip(1)) {
          newDiveIds.add(
            await _restoreSegment(
              segment: segment,
              isLast: identical(segment, segments.last),
              diveId: diveId,
              diveRow: diveRow,
              sourceById: sourceById,
              allSeries: allSeries,
              allPressures: allPressures,
              allTanks: allTanks,
              sharedTankIds: sharedTankIds,
              allEvents: allEvents,
              allSwitches: allSwitches,
              gaps: gaps,
              now: now,
            ),
          );
        }
        await _refreshSharedTankPressures(diveId, sharedTankIds, now);

        // The original dive keeps the first segment. Trim the surface fill the
        // merge synthesized across every gap and drop the markers bracketing
        // them: with the later segments gone there is no gap left to bridge,
        // and an untrimmed series draws the dive with a long flat tail.
        if (gaps.isNotEmpty) {
          for (final s in await _profileSeries.getSeriesForDive(diveId)) {
            final trimmed = gaps.trim(s.samples);
            if (trimmed.length == s.samples.length) continue;
            await _profileSeries.deleteByIds([s.id]);
            if (trimmed.isEmpty) continue;
            await _profileSeries.insertSeries(
              diveId: diveId,
              computerId: s.computerId,
              sourceId: s.sourceId,
              isPrimary: s.isPrimary,
              samples: trimmed,
              now: now,
            );
          }
          await _deleteEvents(allEvents.where(gaps.isMarker).toList());
        }

        // Refresh the original dive's summary from the segment it kept, and
        // touch it so sync carries the separation. Read after the trim so the
        // fallback describes the profile the dive is left with.
        await _refreshKeptDive(
          diveId: diveId,
          diveRow: diveRow,
          keptLead: sourceById[segments.first.sourceIds.first],
          keptSegment: segments.first,
          keptSummary: _summaryOf([
            for (final s in await _profileSeries.getSeriesForDive(diveId))
              ...s.samples,
          ]),
          now: now,
        );
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to separate combined dive: $diveId '
        '($segmentCount segments)',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    SyncEventBus.notifyLocalChange();
    return newDiveIds;
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Moves one departing [segment] onto a freshly created dive and returns
  /// its id. Runs inside [separate]'s transaction.
  Future<String> _restoreSegment({
    required UncombineSegment segment,
    required bool isLast,
    required String diveId,
    required Dive diveRow,
    required Map<String, DiveDataSourcesData> sourceById,
    required List<series.ProfileSeries> allSeries,
    required List<series.TankPressureSeries> allPressures,
    required List<DiveTank> allTanks,
    required Set<String> sharedTankIds,
    required List<DiveProfileEvent> allEvents,
    required List<GasSwitche> allSwitches,
    required MergeGapFill gaps,
    required int now,
  }) async {
    final newDiveId = _uuid.v4();
    final lead = sourceById[segment.sourceIds.first]!;
    final offset = -segment.startSeconds;

    // Profile series follow their owning provenance row rather than the
    // timeline: that FK is authoritative, and a series with none stays put
    // rather than being guessed at. Selected up front because the restored
    // dive's summary falls back to what these samples say.
    final movingProfiles = [
      for (final s in allSeries)
        if (segment.sourceIds.contains(s.sourceId)) s,
    ];
    final movingSamples = [
      for (final s in movingProfiles)
        for (final p in gaps.trim(s.samples)) p.shiftedBy(offset),
    ];
    final ownSummary = _summaryOf(movingSamples);

    // 1. The restored dive. Attribution and summary come from the segment's
    // lead provenance row, which holds what the computer or file reported
    // for this half.
    final entryMs =
        lead.entryTime?.millisecondsSinceEpoch ??
        _shiftedMs(diveRow, segment.startSeconds);
    await _db
        .into(_db.dives)
        .insert(
          diveRow
              .toCompanion(false)
              .copyWith(
                id: Value(newDiveId),
                diveDateTime: Value(entryMs),
                entryTime: Value(entryMs),
                exitTime: Value(
                  lead.exitTime?.millisecondsSinceEpoch ??
                      _shiftedMs(diveRow, segment.endSeconds),
                ),
                // The logbook entry does not come apart. Combine unions all
                // of this with no record of which dive each value came from,
                // so it stays on the surviving dive rather than being
                // duplicated onto every restored one -- copying the row
                // wholesale silently contradicted that, handing each
                // restored dive the combined dive's buddy, rating, trip and
                // weighting. What carries is what describes the dive itself:
                // its timings and depths, the water it happened in, the
                // computer that recorded it, and its site.
                diveNumber: const Value(null),
                name: const Value(null),
                notes: const Value(''),
                buddy: const Value(null),
                diveMaster: const Value(null),
                diverRole: const Value(null),
                boatName: const Value(null),
                boatCaptain: const Value(null),
                diveOperator: const Value(null),
                rating: const Value(null),
                isFavorite: const Value(false),
                diveCenterId: const Value(null),
                tripId: const Value(null),
                courseId: const Value(null),
                weightAmount: const Value(null),
                weightType: const Value(null),
                weightingFeedback: const Value(null),
                weightingFeedbackKg: const Value(null),
                // A deliberate exclusion is a judgement about the record the
                // user was looking at, not about halves they had not seen.
                // Restoring one silently excluded from statistics would hide
                // it with nothing on screen to explain why.
                excludedFromStats: const Value(false),
                excludedFromGasStats: const Value(false),
                // Import provenance belongs to the dive that was imported.
                // The restored dive's own dive_data_sources rows carry the
                // file name, fingerprint and source uuid that matter.
                importSource: const Value(null),
                importId: const Value(null),
                importVersion: const Value(null),
                siteSuggestionDismissedAt: const Value(null),
                // Runtime is the segment's own span. Left alone it kept the
                // whole combine's, the same defect as bottom time below.
                runtime: Value(
                  lead.exitTime != null && lead.entryTime != null
                      ? lead.exitTime!.difference(lead.entryTime!).inSeconds
                      : segment.endSeconds - segment.startSeconds,
                ),
                // Surface fixes are per-source, so a restored half takes its
                // own rather than inheriting the fix of the half that
                // happens to start the combined dive.
                entryLatitude: Value(lead.entryLatitude),
                entryLongitude: Value(lead.entryLongitude),
                exitLatitude: Value(lead.exitLatitude),
                exitLongitude: Value(lead.exitLongitude),
                computerId: Value(lead.computerId),
                diveComputerModel: Value(lead.computerModel),
                diveComputerSerial: Value(lead.computerSerial),
                // The provenance row first, then what this segment's own
                // samples say, and only then the combined dive's aggregate.
                // Skipping the middle step gave a restored 30 minute half the
                // whole combine's bottom time whenever its row carried none,
                // which is the shape backfillPrimaryDataSource mints for a
                // legacy dive with no bottom_time.
                maxDepth: Value(
                  lead.maxDepth ?? ownSummary?.maxDepth ?? diveRow.maxDepth,
                ),
                avgDepth: Value(lead.avgDepth ?? diveRow.avgDepth),
                bottomTime: Value(
                  lead.duration ?? ownSummary?.bottomTime ?? diveRow.bottomTime,
                ),
                waterTemp: Value(lead.waterTemp ?? diveRow.waterTemp),
                surfaceIntervalSeconds: Value(
                  lead.surfaceInterval ?? diveRow.surfaceIntervalSeconds,
                ),
                cnsEnd: Value(lead.cns ?? diveRow.cnsEnd),
                decoAlgorithm: Value(
                  lead.decoAlgorithm ?? diveRow.decoAlgorithm,
                ),
                gradientFactorLow: Value(
                  lead.gradientFactorLow ?? diveRow.gradientFactorLow,
                ),
                gradientFactorHigh: Value(
                  lead.gradientFactorHigh ?? diveRow.gradientFactorHigh,
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

    // 2. Provenance rows, copied onto the restored dive. Every row in a
    // segment overlaps the others in time -- that is what put them in one
    // segment -- so they are competing recordings of the same minutes and
    // must each keep their own display strand. Re-slot them 0..n-1 within
    // the segment for that, or clear the slot entirely on a segment of one
    // so the restored dive looks exactly like a dive that was never
    // combined.
    //
    // The originals are not deleted until step 8, once every row that
    // references them has moved. dive_profile_series.source_id is ON DELETE
    // SET NULL, so deleting a source row first silently unattributes the
    // series still pointing at it, which is the failure clearSource exists
    // to describe.
    final newSourceIdByOld = <String, String>{};
    final soloSegment = segment.sourceIds.length == 1;
    for (var i = 0; i < segment.sourceIds.length; i++) {
      final oldId = segment.sourceIds[i];
      final row = sourceById[oldId]!;
      final newSourceId = _uuid.v4();
      newSourceIdByOld[oldId] = newSourceId;
      await _db
          .into(_db.diveDataSources)
          .insert(
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(newSourceId),
                  diveId: Value(newDiveId),
                  isPrimary: Value(oldId == lead.id),
                  mergeSourceSlot: Value(soloSegment ? null : i),
                ),
          );
    }

    // 3. What else the segment takes with it, selected by where it sits on
    // the combined timeline.
    final movingPressures = [
      for (final s in allPressures)
        if (_spanOf(s.samples.map((p) => p.timestamp)) case (final start, _))
          if (segment.contains(start)) s,
    ];
    final movingEvents = [
      for (final row in allEvents)
        if (!gaps.isMarker(row) && segment.contains(row.timestamp)) row,
    ];
    final movingSwitches = [
      for (final row in allSwitches)
        if (segment.contains(row.timestamp)) row,
    ];

    // 4. Tanks, cloned on demand for whatever the segment is taking.
    final neededTankIds = <String>{
      for (final s in movingPressures) s.tankId,
      for (final row in movingEvents)
        if (row.tankId != null) row.tankId!,
      for (final row in movingSwitches) row.tankId,
    };
    final tankIdMap = <String, String>{};
    for (final tank in allTanks) {
      if (!neededTankIds.contains(tank.id)) continue;
      final freshId = _uuid.v4();
      tankIdMap[tank.id] = freshId;
      final ownSpan = sharedTankIds.contains(tank.id)
          ? pressureSpanOf(movingPressures.where((s) => s.tankId == tank.id))
          : null;
      await _db
          .into(_db.diveTanks)
          .insert(
            tank
                .toCompanion(false)
                .copyWith(
                  id: Value(freshId),
                  diveId: Value(newDiveId),
                  // The start is an inner boundary on every restored dive. The
                  // end is too, except on the last, where the stored value is
                  // that dive's own reported end.
                  startPressure: ownSpan == null ? null : Value(ownSpan.start),
                  endPressure: ownSpan == null
                      ? null
                      : Value(
                          isLast
                              ? tank.endPressure ?? ownSpan.end
                              : ownSpan.end,
                        ),
                ),
          );
      await _sync.markRecordPending(
        entityType: 'diveTanks',
        recordId: freshId,
        localUpdatedAt: now,
      );
    }

    // 5. Profile series, re-based, with the merge's surface fill trimmed out
    // first. isPrimary and computerId are preserved so edited-vs-original
    // semantics survive, and sourceId re-points at the copied row.
    for (final s in movingProfiles) {
      final samples = [
        for (final p in gaps.trim(s.samples)) p.shiftedBy(offset),
      ];
      if (samples.isEmpty) continue;

      await _profileSeries.insertSeries(
        diveId: newDiveId,
        computerId: s.computerId,
        sourceId: newSourceIdByOld[s.sourceId],
        isPrimary: s.isPrimary,
        samples: samples,
        now: now,
      );
    }
    await _profileSeries.deleteByIds([for (final s in movingProfiles) s.id]);

    // A dive with no primary series has no profile to read: getDiveProfile
    // filters on isPrimary, the stranding of issue #1149. Merge preserves
    // each segment's flags, so this normally finds one already.
    if (!await _profileSeries.hasPrimarySeries(newDiveId)) {
      await _profileSeries.promoteOwnedBy(
        newDiveId,
        sourceId: newSourceIdByOld[lead.id],
        computerId: lead.computerId,
        now: now,
      );
    }

    // 6. Tank pressure series, re-based onto the cloned tanks.
    for (final s in movingPressures) {
      await _tankSeries.insertSeries(
        diveId: newDiveId,
        tankId: tankIdMap[s.tankId] ?? s.tankId,
        computerId: s.computerId,
        samples: [for (final p in s.samples) p.shiftedBy(offset)],
        now: now,
      );
    }
    await _tankSeries.deleteByIds([for (final s in movingPressures) s.id]);

    // 7. Profile events and gas switches, re-based and re-pointed.
    for (final row in movingEvents) {
      final freshId = _uuid.v4();
      await _db
          .into(_db.diveProfileEvents)
          .insert(
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(freshId),
                  diveId: Value(newDiveId),
                  timestamp: Value(row.timestamp + offset),
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
                  tankId: Value(tankIdMap[row.tankId] ?? row.tankId),
                  timestamp: Value(row.timestamp + offset),
                ),
          );
      await _sync.markRecordPending(
        entityType: 'gasSwitches',
        recordId: freshId,
        localUpdatedAt: now,
      );
    }
    await _deleteEvents(movingEvents);
    await _deleteSwitches(movingSwitches);

    // 8. The originals of the provenance rows copied in step 2, now that
    // nothing on this dive still references them.
    for (final oldId in segment.sourceIds) {
      await (_db.delete(
        _db.diveDataSources,
      )..where((t) => t.id.equals(oldId))).go();
      await _sync.logDeletion(entityType: 'diveDataSources', recordId: oldId);
    }

    return newDiveId;
  }

  /// Resets each shared tank left on the surviving dive to the end pressure
  /// its remaining series report, once the later segments' series have moved
  /// off. Otherwise the first half keeps the combined dive's end pressure.
  /// The stored start is the first half's own reported one and stays.
  Future<void> _refreshSharedTankPressures(
    String diveId,
    Set<String> sharedTankIds,
    int now,
  ) async {
    for (final tankId in sharedTankIds) {
      final span = pressureSpanOf(
        await _tankSeries.getSeriesForTank(diveId, tankId),
      );
      if (span == null) continue;
      final kept = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.id.equals(tankId))).getSingle();
      await (_db.update(
        _db.diveTanks,
      )..where((t) => t.id.equals(tankId))).write(
        DiveTanksCompanion(
          startPressure: Value(kept.startPressure ?? span.start),
          endPressure: Value(span.end),
        ),
      );
      await _sync.markRecordPending(
        entityType: 'diveTanks',
        recordId: tankId,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _refreshKeptDive({
    required String diveId,
    required Dive diveRow,
    required DiveDataSourcesData? keptLead,
    required _ProfileSummary? keptSummary,
    required UncombineSegment keptSegment,
    required int now,
  }) async {
    var update = DivesCompanion(updatedAt: Value(now));
    if (keptLead != null) {
      update = update.copyWith(
        computerId: Value(keptLead.computerId),
        diveComputerModel: Value(keptLead.computerModel),
        diveComputerSerial: Value(keptLead.computerSerial),
        maxDepth: Value(
          keptLead.maxDepth ?? keptSummary?.maxDepth ?? diveRow.maxDepth,
        ),
        avgDepth: Value(keptLead.avgDepth ?? diveRow.avgDepth),
        bottomTime: Value(
          keptLead.duration ?? keptSummary?.bottomTime ?? diveRow.bottomTime,
        ),
        waterTemp: Value(keptLead.waterTemp ?? diveRow.waterTemp),
        // Both fall back to where the kept segment actually ends, never to
        // the combined dive's own end. Falling back to diveRow.exitTime left
        // a dive claiming an exit an hour after a runtime that had already
        // been corrected to its own half -- and every provenance row an
        // import writes carries an exit time, so the inconsistent branch was
        // the one only legacy rows take.
        exitTime: Value(
          keptLead.exitTime?.millisecondsSinceEpoch ??
              _shiftedMs(diveRow, keptSegment.endSeconds),
        ),
        // As on a restored dive: without this the surviving dive keeps the
        // whole combine's runtime after the later segments have left it.
        runtime: Value(
          keptLead.exitTime != null && keptLead.entryTime != null
              ? keptLead.exitTime!.difference(keptLead.entryTime!).inSeconds
              : keptSegment.endSeconds - keptSegment.startSeconds,
        ),
        cnsEnd: Value(keptLead.cns ?? diveRow.cnsEnd),
        decoAlgorithm: Value(keptLead.decoAlgorithm ?? diveRow.decoAlgorithm),
        gradientFactorLow: Value(
          keptLead.gradientFactorLow ?? diveRow.gradientFactorLow,
        ),
        gradientFactorHigh: Value(
          keptLead.gradientFactorHigh ?? diveRow.gradientFactorHigh,
        ),
      );
    }
    await (_db.update(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).write(update);
    await _sync.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }

  Future<void> _deleteEvents(List<DiveProfileEvent> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      await _sync.logDeletion(
        entityType: 'diveProfileEvents',
        recordId: row.id,
      );
    }
    await (_db.delete(
      _db.diveProfileEvents,
    )..where((t) => t.id.isIn([for (final r in rows) r.id]))).go();
  }

  Future<void> _deleteSwitches(List<GasSwitche> rows) async {
    if (rows.isEmpty) return;
    for (final row in rows) {
      await _sync.logDeletion(entityType: 'gasSwitches', recordId: row.id);
    }
    await (_db.delete(
      _db.gasSwitches,
    )..where((t) => t.id.isIn([for (final r in rows) r.id]))).go();
  }

  // -------------------------------------------------------------------------
  // Reads and grouping
  // -------------------------------------------------------------------------

  /// The dive's provenance rows in canonical order (primary first, then
  /// oldest), the order every canonical read and the merge writer use.
  Future<List<DiveDataSourcesData>> _sourceRows(String diveId) =>
      (_db.select(_db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPrimary),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  /// The dive's merge gaps, read off the surface markers the merge wrote.
  Future<MergeGapFill> _gapsOf(String diveId) async => MergeGapFill.readFrom(
    await (_db.select(
      _db.diveProfileEvents,
    )..where((t) => t.diveId.equals(diveId))).get(),
  );

  /// Groups [rows] into segments, spanning each by its own profile series and
  /// falling back to its recorded entry/exit times.
  ///
  /// Takes spans from `ProfileSeriesRepository.getSpansForDive`, which
  /// projects to the summary columns instead of selecting whole rows: this
  /// runs on every dive-detail open to decide whether to offer the action,
  /// and reading the packed blobs to look at the scalars beside them would
  /// put a dive's most expensive data on a UI path for nothing.
  List<UncombineSegment> _segmentsOf({
    required List<DiveDataSourcesData> rows,
    required List<
      ({String id, String? sourceId, int startTimestamp, int endTimestamp})
    >
    seriesRows,
    required Dive diveRow,
    required MergeGapFill gaps,
  }) {
    // The combined timeline's origin, so a row's wall-clock entry and exit
    // read as seconds from the dive's start.
    final originMs = diveRow.entryTime ?? diveRow.diveDateTime;

    final spans = <SourceSpan>[];
    final spanless = <String>[];
    for (final row in rows) {
      // The merge's surface fill is clamped off both ends first. That fill is
      // appended to the segment BEFORE each gap, so a raw span reaches across
      // the gap into the next segment -- and on a combine of a combine it
      // reaches across two of them, swallowing every later segment into the
      // first.
      final bounds = <int>[];
      for (final series in seriesRows) {
        if (series.sourceId != row.id) continue;
        final start = gaps.clampStart(series.startTimestamp);
        final end = gaps.clampEnd(series.endTimestamp);
        // A series lying wholly inside a gap is fill and nothing else.
        if (start > end) continue;
        // Confined to the stretch between gaps that the series STARTS in.
        // Clamping the end is not enough on its own: the merge appends a
        // gap's fill to its segment's PRIMARY series, not to whichever one
        // is adjacent in time, so on a combine of a combine one series can
        // carry the fill for a gap that its own samples end nowhere near.
        // Its start is never in doubt, because the fill is only ever
        // appended.
        bounds.addAll([start, gaps.confineEnd(start, end)]);
      }
      final sampleSpan = _spanOf(bounds);
      final entry = row.entryTime?.millisecondsSinceEpoch;
      final exit = row.exitTime?.millisecondsSinceEpoch;
      if (sampleSpan != null) {
        spans.add(
          SourceSpan(
            sourceId: row.id,
            start: sampleSpan.$1,
            end: sampleSpan.$2,
          ),
        );
      } else if (entry != null && exit != null && exit >= entry) {
        spans.add(
          SourceSpan(
            sourceId: row.id,
            start: (entry - originMs) ~/ 1000,
            end: (exit - originMs) ~/ 1000,
          ),
        );
      } else {
        spanless.add(row.id);
      }
    }

    final spanById = {for (final span in spans) span.sourceId: span};
    final grouped = [
      for (final ids in groupSourcesIntoSegments(
        spans: spans,
        spanless: spanless,
      ))
        UncombineSegment(
          sourceIds: ids,
          startSeconds: _reduce(ids, spanById, (s) => s.start, min: true),
          endSeconds: _reduce(ids, spanById, (s) => s.end, min: false),
        ),
    ];
    // Segments are told apart by disjointness, and spans that merely TOUCH
    // count as disjoint (a merge that bridged a gap too short to fill leaves
    // one segment ending exactly where the next begins). Both ends of
    // [UncombineSegment.contains] are inclusive, so a shared boundary second
    // would sit in two segments at once and an event on it would move to
    // whichever came first. Pull each end back off its successor's start.
    return [
      for (var i = 0; i < grouped.length; i++)
        if (i + 1 < grouped.length &&
            grouped[i].endSeconds >= grouped[i + 1].startSeconds)
          UncombineSegment(
            sourceIds: grouped[i].sourceIds,
            startSeconds: grouped[i].startSeconds,
            endSeconds: grouped[i + 1].startSeconds - 1,
          )
        else
          grouped[i],
    ];
  }

  /// The min or max of [pick] across the spans of [ids]; 0 when none of them
  /// has a span (a segment of nothing but spanless rows).
  int _reduce(
    List<String> ids,
    Map<String, SourceSpan> spanById,
    int Function(SourceSpan) pick, {
    required bool min,
  }) {
    int? best;
    for (final id in ids) {
      final span = spanById[id];
      if (span == null) continue;
      final value = pick(span);
      if (best == null || (min ? value < best : value > best)) best = value;
    }
    return best ?? 0;
  }

  /// The min and max of [timestamps], or null when there are none. Min/max
  /// rather than first/last: ascending order is not an invariant of the
  /// concatenation of several decoded series.
  (int, int)? _spanOf(Iterable<int> timestamps) {
    int? low;
    int? high;
    for (final t in timestamps) {
      if (low == null || t < low) low = t;
      if (high == null || t > high) high = t;
    }
    return low == null ? null : (low, high!);
  }

  /// What [samples] say about the dive they describe, or null when there are
  /// too few to say anything. Bottom time goes through
  /// [BottomTimeCalculator] rather than being taken as the sample span:
  /// seeding bottom time from a total runtime is exactly the defect issue
  /// #675 fixed across the importers.
  _ProfileSummary? _summaryOf(List<ProfileSample> samples) {
    if (samples.isEmpty) return null;
    var maxDepth = 0.0;
    for (final sample in samples) {
      if (sample.depth > maxDepth) maxDepth = sample.depth;
    }
    return _ProfileSummary(
      maxDepth: maxDepth > 0 ? maxDepth : null,
      bottomTime: BottomTimeCalculator.secondsFromSamples([
        for (final sample in samples)
          (timestamp: sample.timestamp, depth: sample.depth),
      ]),
    );
  }

  int _shiftedMs(Dive diveRow, int seconds) =>
      (diveRow.entryTime ?? diveRow.diveDateTime) + seconds * 1000;
}

/// The summary scalars a set of samples can answer for on its own, used only
/// where a provenance row carries none.
class _ProfileSummary {
  const _ProfileSummary({required this.maxDepth, required this.bottomTime});

  final double? maxDepth;
  final int? bottomTime;
}
