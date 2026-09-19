import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService merge;
  late DiveUncombineService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    merge = DiveMergeService(diveRepo);
    service = DiveUncombineService(diveRepo);
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Seeds one importable dive: a tank, a sparse 3-sample profile, a tank
  /// pressure series, a gas switch, one imported event, and the
  /// `dive_data_sources` row an import writes.
  ///
  /// [computerId] is stamped onto the profile series the way a real download
  /// does, by re-inserting what `createDive` wrote: the domain
  /// DiveProfilePoint carries no computerId, so createDive cannot set one.
  /// FK enforcement is off in this suite, so no `dive_computers` row is
  /// needed.
  Future<void> seedDive(
    String id, {
    required DateTime entry,
    int runtimeMin = 30,
    double depth = 10,
    String? computerId,
    String? siteId,
    bool sourceCarriesSummary = true,
    double? startPressure,
    double? endPressure,
    List<TankPressureSample> pressures = const [
      TankPressureSample(timestamp: 60, pressure: 180.0),
    ],
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        tanks: [
          domain.DiveTank(
            id: 'tank-$id',
            volume: 11.1,
            startPressure: startPressure,
            endPressure: endPressure,
          ),
        ],
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    if (siteId != null) {
      await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
        DivesCompanion(siteId: Value(siteId)),
      );
    }
    if (computerId != null) {
      final created = await profileSeries.getSeriesForDive(id);
      await profileSeries.deleteForDive(id);
      for (final s in created) {
        await profileSeries.insertSeries(
          diveId: id,
          computerId: computerId,
          sourceId: s.sourceId,
          isPrimary: s.isPrimary,
          samples: s.samples,
          now: 0,
        );
      }
    }
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'event-$id',
            diveId: id,
            timestamp: 60,
            eventType: 'gaschange',
            createdAt: 0,
          ).copyWith(tankId: Value('tank-$id')),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-$id',
            diveId: id,
            timestamp: 60,
            tankId: 'tank-$id',
            createdAt: 0,
          ),
        );
    if (pressures.isNotEmpty) {
      await tankSeries.insertSeries(
        diveId: id,
        tankId: 'tank-$id',
        samples: pressures,
        id: 'tp-$id',
        now: 0,
      );
    }
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(
            isPrimary: const Value(true),
            computerId: Value(computerId),
            maxDepth: Value(sourceCarriesSummary ? depth : null),
            sourceFileName: Value('$id.uddf'),
          ),
        );
  }

  Future<String> mergeTwoImports({String? siteId}) async {
    await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), siteId: siteId);
    await seedDive(
      'b',
      entry: DateTime.utc(2026, 7, 1, 10),
      depth: 20,
      runtimeMin: 20,
      siteId: siteId,
    );
    final outcome = await merge.apply(['a', 'b']);
    return outcome.mergedDive.id;
  }

  group('plan', () {
    test('a dive that was never combined reads as one segment', () async {
      await seedDive('solo', entry: DateTime.utc(2026, 7, 1, 9));

      expect(await service.plan('solo'), hasLength(1));
    });

    test('a dive with no provenance rows reads as no segments', () async {
      await seedDive('solo', entry: DateTime.utc(2026, 7, 1, 9));
      await db.delete(db.diveDataSources).go();

      expect(await service.plan('solo'), isEmpty);
    });

    test('two combined file imports read as two segments', () async {
      // The repro of issue #1504: neither import carries a computerId, so
      // both carried rows land on merge slot 0 and collapse to a single
      // display source, which is what hid Split.
      final mergedId = await mergeTwoImports();
      expect(await diveRepo.getDataSources(mergedId), hasLength(1));

      final segments = await service.plan(mergedId);
      expect(segments, hasLength(2));
      expect(segments.first.sourceIds, hasLength(1));
      expect(segments.last.sourceIds, hasLength(1));
      expect(segments.first.startSeconds, 0);
      expect(segments.last.startSeconds, 3600);
    });

    test(
      'two consolidated computers reading one dive stay one segment',
      () async {
        await seedDive(
          'a',
          entry: DateTime.utc(2026, 7, 1, 9),
          computerId: 'c1',
        );
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion.insert(
                id: 'src-a2',
                diveId: 'a',
                importedAt: DateTime.utc(2026, 7, 1),
                createdAt: DateTime.utc(2026, 7, 2),
              ).copyWith(computerId: const Value('c2')),
            );
        // The second computer's own recording of the same minutes.
        await profileSeries.insertSeries(
          diveId: 'a',
          computerId: 'c2',
          sourceId: 'src-a2',
          isPrimary: false,
          samples: [
            for (final s in (await profileSeries.getSeriesForDive(
              'a',
            )).first.samples)
              s,
          ],
          now: 0,
        );

        expect(await service.plan('a'), hasLength(1));
      },
    );

    test('segments never share a boundary second', () async {
      // Spans that merely TOUCH count as disjoint, so a merge across a gap
      // too short to fill leaves one segment ending exactly where the next
      // begins. Both ends of UncombineSegment.contains are inclusive, so
      // without a correction that second would sit in two segments and an
      // event on it would move to whichever was visited first.
      const entry = 1780000000000;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'touching',
              diveDateTime: entry,
              createdAt: 0,
              updatedAt: 0,
            ).copyWith(entryTime: const Value(entry)),
          );
      for (final (id, startS, endS) in [('s1', 0, 1800), ('s2', 1800, 3000)]) {
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion.insert(
                id: id,
                diveId: 'touching',
                importedAt: DateTime.utc(2026, 7, 1),
                createdAt: DateTime.utc(2026, 7, 1),
              ).copyWith(
                // No profile series, so the spans come from these.
                entryTime: Value(
                  DateTime.fromMillisecondsSinceEpoch(
                    entry + startS * 1000,
                    isUtc: true,
                  ),
                ),
                exitTime: Value(
                  DateTime.fromMillisecondsSinceEpoch(
                    entry + endS * 1000,
                    isUtc: true,
                  ),
                ),
              ),
            );
      }

      final segments = await service.plan('touching');

      expect(segments, hasLength(2));
      expect(segments.first.endSeconds, lessThan(segments.last.startSeconds));
      expect(segments.first.contains(1800), isFalse);
      expect(segments.last.contains(1800), isTrue);
    });
  });

  group('separate', () {
    test('round-trips with foreign keys enforced', () async {
      // Production opens the database with PRAGMA foreign_keys = ON and no
      // deferred constraints, while this suite turns them off so link rows
      // can be seeded without catalog rows. That convention hides insert and
      // delete ORDER defects: dive_profile_series.source_id is ON DELETE SET
      // NULL, so deleting a provenance row before the series pointing at it
      // have moved silently unattributes them rather than failing loudly.
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'diver1',
              name: 'Test Diver',
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      final mergedId = await mergeTwoImports();
      final restoredId = (await service.separate(diveId: mergedId)).single;

      // Every moved series still names the provenance row that owns it: a
      // null here is the SET NULL cascade having fired on a row that had not
      // moved yet.
      for (final diveId in [mergedId, restoredId]) {
        final series = await profileSeries.getSeriesForDive(diveId);
        expect(series, isNotEmpty);
        expect(series.map((s) => s.sourceId), everyElement(isNotNull));
        final sourceIds = {
          for (final row in await (db.select(
            db.diveDataSources,
          )..where((t) => t.diveId.equals(diveId))).get())
            row.id,
        };
        expect(series.map((s) => s.sourceId), everyElement(isIn(sourceIds)));
      }
    });

    test('leaves the logbook entry on the surviving dive', () async {
      // The confirmation dialog promises buddies, tags, equipment, media,
      // notes and the dive number stay put. Restored dives are created by
      // copying the combined dive's row, so every logbook scalar on it was
      // duplicated onto them until this was pinned: the restored half
      // claimed the same buddy, divemaster, rating, trip and weighting.
      final mergedId = await mergeTwoImports();
      await (db.update(db.dives)..where((t) => t.id.equals(mergedId))).write(
        const DivesCompanion(
          name: Value('Blue Hole, second half'),
          diveNumber: Value(412),
          buddy: Value('Sam'),
          diveMaster: Value('Alex'),
          diverRole: Value('role-guide'),
          boatName: Value('Sea Wolf'),
          boatCaptain: Value('Robin'),
          diveOperator: Value('Reef Divers'),
          rating: Value(5),
          isFavorite: Value(true),
          tripId: Value('trip-1'),
          courseId: Value('course-1'),
          diveCenterId: Value('centre-1'),
          weightAmount: Value(6.5),
          weightType: Value('integrated'),
          excludedFromStats: Value(true),
          excludedFromGasStats: Value(true),
          importSource: Value('garmin'),
          importId: Value('import-1'),
          notes: Value('Two halves of one dive.'),
          siteId: Value('site-1'),
          waterType: Value('salt'),
          visibilityMeters: Value(18),
        ),
      );

      final restoredId = (await service.separate(diveId: mergedId)).single;

      final dives = await db.select(db.dives).get();
      final restored = dives.firstWhere((d) => d.id == restoredId);
      final kept = dives.firstWhere((d) => d.id == mergedId);

      // None of the logbook entry follows.
      expect(restored.name, isNull);
      expect(restored.diveNumber, isNull);
      expect(restored.buddy, isNull);
      expect(restored.diveMaster, isNull);
      expect(restored.diverRole, isNull);
      expect(restored.boatName, isNull);
      expect(restored.boatCaptain, isNull);
      expect(restored.diveOperator, isNull);
      expect(restored.rating, isNull);
      expect(restored.isFavorite, isFalse);
      expect(restored.tripId, isNull);
      expect(restored.courseId, isNull);
      expect(restored.diveCenterId, isNull);
      expect(restored.weightAmount, isNull);
      expect(restored.weightType, isNull);
      expect(restored.importSource, isNull);
      expect(restored.importId, isNull);
      expect(restored.notes, '');
      // A restored dive must not be silently hidden from statistics.
      expect(restored.excludedFromStats, isFalse);
      expect(restored.excludedFromGasStats, isFalse);

      // What describes the dive itself does follow: the site and the water
      // it happened in are true of both halves.
      expect(restored.siteId, 'site-1');
      expect(restored.waterType, 'salt');
      expect(restored.visibilityMeters, 18);

      // And the surviving dive keeps all of it.
      expect(kept.buddy, 'Sam');
      expect(kept.diveNumber, 412);
      expect(kept.rating, 5);
      expect(kept.tripId, 'trip-1');
      expect(kept.notes, 'Two halves of one dive.');
    });

    test('gives each dive its own runtime, not the combined total', () async {
      final mergedId = await mergeTwoImports();
      final merged = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(mergedId))).getSingle();

      final restoredId = (await service.separate(diveId: mergedId)).single;

      final dives = await db.select(db.dives).get();
      final restored = dives.firstWhere((d) => d.id == restoredId);
      final kept = dives.firstWhere((d) => d.id == mergedId);
      // a spans 0..1800 s and b 3600..4800 s on the combined timeline, so
      // the combine runs 4800 s and neither half may keep that.
      expect(merged.runtime, greaterThan(4000));
      expect(kept.runtime, 1800);
      expect(restored.runtime, 1200);

      // The timestamps have to agree with those runtimes. The seeded
      // provenance rows carry no exit time, which is the shape
      // backfillPrimaryDataSource mints for a legacy dive, and the surviving
      // dive used to fall back to the COMBINED dive's exit: an exit an hour
      // after a runtime that had already been corrected to its own half.
      for (final dive in [kept, restored]) {
        expect(dive.entryTime, isNotNull);
        expect(dive.exitTime, isNotNull);
        expect(
          (dive.exitTime! - dive.entryTime!) ~/ 1000,
          dive.runtime,
          reason: 'exit - entry must match runtime on ${dive.id}',
        );
      }
      expect(kept.exitTime, lessThan(merged.exitTime!));
    });

    test('summarises each restored dive from its own samples', () async {
      // backfillPrimaryDataSource mints a provenance row from the dive it
      // found, so a legacy dive with no bottom_time carries none here. The
      // fallback has to be the segment's own profile: taking the combined
      // dive's aggregate gave a 20 minute half the whole combine's numbers.
      await seedDive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        sourceCarriesSummary: false,
      );
      await seedDive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        depth: 20,
        runtimeMin: 20,
        sourceCarriesSummary: false,
      );
      final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;

      final restoredId = (await service.separate(diveId: mergedId)).single;

      final dives = await db.select(db.dives).get();
      final restored = dives.firstWhere((d) => d.id == restoredId);
      final kept = dives.firstWhere((d) => d.id == mergedId);
      // b: samples 0/600/1200 at depths 0/20/0, so the last sample at or
      // below the 6.6 m threshold sits at 600 s.
      expect(restored.maxDepth, 20);
      expect(restored.bottomTime, 600);
      // a: samples 0/900/1800 at depths 0/10/0, threshold 6 m.
      expect(kept.maxDepth, 10);
      expect(kept.bottomTime, 900);
    });

    test('refuses a dive whose series cannot be decoded', () async {
      // Reads answer an undecodable blob with null, so such a series is
      // invisible to the grouping: its samples would neither move nor be
      // trimmed while the tank beneath it was cloned away. The guard runs
      // inside the transaction with every other read, so nothing is written
      // before it fires.
      final mergedId = await mergeTwoImports();
      final row = (await profileSeries.getRowsForDives([mergedId])).first;
      await db.customStatement(
        'UPDATE dive_profile_series SET samples = ? WHERE id = ?',
        [Uint8List.fromList(row.samples)..[3] ^= 0xFF, row.id],
      );

      await expectLater(
        service.separate(diveId: mergedId),
        throwsA(isA<UnreadableSeriesException>()),
      );
      expect(await db.select(db.dives).get(), hasLength(1));
    });

    test('refuses a dive that reads as one segment', () async {
      await seedDive('solo', entry: DateTime.utc(2026, 7, 1, 9));

      expect(
        () => service.separate(diveId: 'solo'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('restores the combined imports as two dives', () async {
      final mergedId = await mergeTwoImports();
      // A site the user assigned to the combined dive: both halves happened
      // in one place, so a restored half inherits it.
      await (db.update(db.dives)..where((t) => t.id.equals(mergedId))).write(
        const DivesCompanion(siteId: Value('site-1')),
      );

      final newIds = await service.separate(diveId: mergedId);

      expect(newIds, hasLength(1));
      final restoredId = newIds.single;
      final dives = await db.select(db.dives).get();
      expect(dives.map((d) => d.id).toSet(), {mergedId, restoredId});

      // Each dive keeps exactly one provenance row, and the restored one is
      // primary again with its own file name.
      final keptSources = await diveRepo.getDataSources(mergedId);
      final restoredSources = await diveRepo.getDataSources(restoredId);
      expect(keptSources, hasLength(1));
      expect(restoredSources, hasLength(1));
      expect(keptSources.single.sourceFileName, 'a.uddf');
      expect(restoredSources.single.sourceFileName, 'b.uddf');
      expect(restoredSources.single.isPrimary, isTrue);

      // The restored dive's profile is re-based to its own zero, and the
      // merge's surface fill is gone from both.
      final restoredSeries = await profileSeries.getSeriesForDive(restoredId);
      expect(
        [for (final s in restoredSeries) ...s.samples.map((p) => p.timestamp)],
        [0, 600, 1200],
      );
      final keptSeries = await profileSeries.getSeriesForDive(mergedId);
      expect(
        [for (final s in keptSeries) ...s.samples.map((p) => p.timestamp)],
        [0, 900, 1800],
      );

      // Both restored dives are readable: a dive with no primary series has
      // no profile at all (#1149).
      expect(await profileSeries.hasPrimarySeries(restoredId), isTrue);
      expect(await profileSeries.hasPrimarySeries(mergedId), isTrue);

      // Summary scalars come from each half's own provenance row.
      final restored = dives.firstWhere((d) => d.id == restoredId);
      expect(restored.maxDepth, 20);
      expect(restored.diveNumber, isNull);
      expect(restored.siteId, 'site-1');
      expect(
        DateTime.fromMillisecondsSinceEpoch(restored.diveDateTime, isUtc: true),
        DateTime.utc(2026, 7, 1, 10),
      );
    });

    test('drops the surface markers the merge wrote at the gap', () async {
      final mergedId = await mergeTwoImports();

      final newIds = await service.separate(diveId: mergedId);

      final events = await db.select(db.diveProfileEvents).get();
      expect(
        events.where((e) => e.eventType == 'surface' && e.source == 'app'),
        isEmpty,
      );
      // The imported events survive, re-based onto their own dive.
      final restoredEvents = events.where((e) => e.diveId == newIds.single);
      expect(restoredEvents.map((e) => e.timestamp), [60]);
      expect(
        events.where((e) => e.diveId == mergedId).map((e) => e.timestamp),
        [60],
      );
    });

    test('moves tank pressures and gas switches onto cloned tanks', () async {
      final mergedId = await mergeTwoImports();

      final restoredId = (await service.separate(diveId: mergedId)).single;

      final restoredPressures = await tankSeries.getSeriesForDive(restoredId);
      expect(restoredPressures, hasLength(1));
      expect(restoredPressures.single.samples.single.timestamp, 60);
      final restoredTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(restoredId))).get();
      expect(restoredTanks, hasLength(1));
      expect(restoredPressures.single.tankId, restoredTanks.single.id);

      final restoredSwitches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(restoredId))).get();
      expect(restoredSwitches, hasLength(1));
      expect(restoredSwitches.single.timestamp, 60);
      expect(restoredSwitches.single.tankId, restoredTanks.single.id);

      // The original keeps its own, untouched.
      expect(await tankSeries.getSeriesForDive(mergedId), hasLength(1));
    });

    test('gives each dive its own pressures on a cylinder both breathed '
        '(#2036)', () async {
      // One cylinder across a surface interval: combine carries it as one
      // tank from 200 to 90 bar, and separating must hand each half back
      // its own start and end rather than the combined ones.
      await seedDive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        // The computer's pre-dive reading, a little above the first logged
        // sample: the stored outer values must survive the round trip.
        startPressure: 207,
        endPressure: 150,
        pressures: const [
          TankPressureSample(timestamp: 60, pressure: 205),
          TankPressureSample(timestamp: 1700, pressure: 150),
        ],
      );
      await seedDive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 20,
        startPressure: 150,
        endPressure: 88,
        pressures: const [
          TankPressureSample(timestamp: 60, pressure: 150),
          TankPressureSample(timestamp: 1100, pressure: 90),
        ],
      );
      final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;
      final mergedTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(mergedTanks, hasLength(1));
      expect(mergedTanks.single.startPressure, 207);
      expect(mergedTanks.single.endPressure, 88);
      // Cleared so the check below sees only what separate itself marks.
      await (db.delete(
        db.syncRecords,
      )..where((t) => t.entityType.equals('diveTanks'))).go();

      final restoredId = (await service.separate(diveId: mergedId)).single;

      final restoredTank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(restoredId))).getSingle();
      expect(restoredTank.startPressure, 150);
      expect(restoredTank.endPressure, 88);
      final keptTank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(mergedId))).getSingle();
      expect(keptTank.startPressure, 207);
      expect(keptTank.endPressure, 150);
      final keptTankSync =
          await (db.select(db.syncRecords)
                ..where((t) => t.entityType.equals('diveTanks'))
                ..where((t) => t.recordId.equals(keptTank.id)))
              .get();
      expect(keptTankSync, isNotEmpty);
    });

    test('a shared cylinder with no pressure log keeps the combined '
        'pressures on both halves (#2036)', () async {
      // Accepted trade-off: combine carries a hand-entered cylinder once,
      // from the first half's start to the last half's end, and nothing
      // records where the first half ended. Separate cannot rebuild it, so
      // both halves come back with the combined pair.
      await seedDive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        startPressure: 200,
        endPressure: 120,
        pressures: const [],
      );
      await seedDive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 20,
        startPressure: 120,
        endPressure: 60,
        pressures: const [],
      );
      final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;

      final restoredId = (await service.separate(diveId: mergedId)).single;

      for (final id in [mergedId, restoredId]) {
        final tank = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals(id))).getSingle();
        expect(tank.startPressure, 200);
        expect(tank.endPressure, 60);
      }
    });

    test('tombstones every row it moves off the surviving dive', () async {
      final mergedId = await mergeTwoImports();

      await service.separate(diveId: mergedId);

      final logged = await db.select(db.deletionLog).get();
      final byType = <String, int>{};
      for (final row in logged) {
        byType[row.entityType] = (byType[row.entityType] ?? 0) + 1;
      }
      // The merged dive survives, so peers that already pulled these rows
      // would keep upsert copies of them forever without a tombstone.
      expect(byType['diveDataSources'], greaterThanOrEqualTo(1));
      expect(byType['diveProfileEvents'], greaterThanOrEqualTo(3));
      expect(byType['gasSwitches'], greaterThanOrEqualTo(1));
      expect(byType['diveProfileSeries'], greaterThanOrEqualTo(2));
      expect(byType['tankPressureSeries'], greaterThanOrEqualTo(1));
    });

    test('un-nests a combine of a combine into three dives', () async {
      final mergedId = await mergeTwoImports();
      await seedDive(
        'c',
        entry: DateTime.utc(2026, 7, 1, 11),
        depth: 15,
        runtimeMin: 10,
      );
      final nestedId = (await merge.apply([mergedId, 'c'])).mergedDive.id;

      final newIds = await service.separate(diveId: nestedId);

      expect(newIds, hasLength(2));
      final dives = await db.select(db.dives).get();
      expect(dives, hasLength(3));
      for (final dive in dives) {
        expect(await diveRepo.getDataSources(dive.id), hasLength(1));
      }
      // Every dive is back on its own zero-based timeline, with none of the
      // fill the two merges synthesized. The first merge's fill lives in the
      // FIRST segment's series, not the one adjacent to the second gap, so a
      // span read straight off the summary columns would have swallowed
      // every later segment into it.
      expect(
        [
          for (final dive in dives)
            [
              for (final s in await profileSeries.getSeriesForDive(dive.id))
                ...s.samples.map((p) => p.timestamp),
            ],
        ],
        containsAll([
          [0, 900, 1800],
          [0, 600, 1200],
          [0, 300, 600],
        ]),
      );
    });

    test(
      'separates two computers that were consolidated then combined',
      () async {
        // Both halves carry a computerId, so the display never collapsed them
        // and per-source Split was offered -- but Split would have moved one
        // computer's whole recording, not one half of the dive.
        await seedDive(
          'a',
          entry: DateTime.utc(2026, 7, 1, 9),
          computerId: 'c1',
        );
        await seedDive(
          'b',
          entry: DateTime.utc(2026, 7, 1, 10),
          runtimeMin: 20,
          depth: 20,
          computerId: 'c1',
        );
        final mergedId = (await merge.apply(['a', 'b'])).mergedDive.id;
        expect(await diveRepo.getDataSources(mergedId), hasLength(1));

        final restoredId = (await service.separate(diveId: mergedId)).single;

        expect(
          [
            for (final s in await profileSeries.getSeriesForDive(restoredId))
              ...s.samples.map((p) => p.timestamp),
          ],
          [0, 600, 1200],
        );
        final restoredSources = await diveRepo.getDataSources(restoredId);
        expect(restoredSources.single.computerId, 'c1');
      },
    );
  });
}
