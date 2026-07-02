import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService service;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = DiveMergeService(diveRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Seeds a dive with one tank, a 3-sample profile, and link rows in the
  /// tables createDive does not cover (buddy, sighting, event, gas switch,
  /// tank pressure, data source, media).
  Future<void> seedDive(
    String id, {
    required DateTime entry,
    int runtimeMin = 30,
    double depth = 10,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        tanks: [domain.DiveTank(id: 'tank-$id', volume: 11.1)],
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'buddy-$id',
            diveId: id,
            buddyId: 'buddy-cat-1',
            createdAt: 0,
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-$id',
            diveId: id,
            speciesId: 'turtle',
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'event-$id',
            diveId: id,
            timestamp: 60,
            eventType: 'gaschange',
            createdAt: 0,
          ),
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
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion.insert(
            id: 'tp-$id',
            diveId: id,
            tankId: 'tank-$id',
            timestamp: 60,
            pressure: 180,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(isPrimary: const Value(true)),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'media-$id',
            filePath: '/photos/$id.jpg',
            createdAt: 0,
            updatedAt: 0,
          ).copyWith(diveId: Value(id)),
        );
  }

  group('captureSnapshot', () {
    test('captures every child table and media pointers', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));

      final snap = await service.captureSnapshot(['a', 'b'], 'merged-1');

      expect(snap.mergedDiveId, 'merged-1');
      expect(snap.diveRows, hasLength(2));
      expect(snap.profileRows, hasLength(6));
      expect(snap.tankRows, hasLength(2));
      expect(snap.buddyRows, hasLength(2));
      expect(snap.sightingRows, hasLength(2));
      expect(snap.eventRows, hasLength(2));
      expect(snap.gasSwitchRows, hasLength(2));
      expect(snap.tankPressureRows, hasLength(2));
      expect(snap.dataSourceRows, hasLength(2));
      expect(snap.mediaDiveIds, {'media-a': 'a', 'media-b': 'b'});
    });
  });

  group('apply', () {
    test('creates merged dive, copies children, deletes sources', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), depth: 10);
      await seedDive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        depth: 20,
        runtimeMin: 20,
      );

      final outcome = await service.apply(['a', 'b']);
      final mergedId = outcome.mergedDive.id;

      // Sources gone, tombstones logged.
      final remaining = await db.select(db.dives).get();
      expect(remaining.map((r) => r.id), [mergedId]);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('dives'))).get();
      expect(tombstones.map((t) => t.recordId).toSet(), {'a', 'b'});

      // Profile: 3 samples per source, re-based, plus 2 gap samples.
      final profile =
          await (db.select(db.diveProfiles)
                ..where((t) => t.diveId.equals(mergedId))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(profile, hasLength(8));
      // Dive a ends at 1800s; dive b starts at 3600s; gap samples inside.
      final gapSamples = profile.where(
        (p) => p.timestamp > 1800 && p.timestamp < 3600,
      );
      expect(gapSamples, hasLength(2));
      expect(gapSamples.every((p) => p.depth == 0), isTrue);
      // b's first sample re-based to 3600.
      expect(profile.where((p) => p.timestamp == 3600), isNotEmpty);

      // Surface events at the gap boundaries.
      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(
        events.where((e) => e.eventType == 'surface').map((e) => e.timestamp),
        containsAll([1800, 3600]),
      );

      // Gas switch re-pointed to a NEW tank id belonging to the merged dive.
      final mergedTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(mergedTanks, hasLength(2));
      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(switches, hasLength(2));
      expect(
        mergedTanks
            .map((t) => t.id)
            .toSet()
            .containsAll(switches.map((s) => s.tankId)),
        isTrue,
      );

      // Tank pressures re-based and re-pointed.
      final pressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(pressures.map((p) => p.timestamp).toSet(), {60, 3660});

      // Buddies and sightings carried; same-species sightings merged.
      final buddies = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(buddies.map((b) => b.buddyId).toSet(), {'buddy-cat-1'});
      final sightings = await (db.select(
        db.sightings,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(sightings, hasLength(1));
      expect(sightings.single.count, 2);

      // Data sources carried, all non-primary.
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(sources, hasLength(2));
      expect(sources.every((s) => !s.isPrimary), isTrue);

      // Media re-pointed, not orphaned.
      final media = await db.select(db.media).get();
      expect(media.every((m) => m.diveId == mergedId), isTrue);

      // Merged stats.
      final mergedRow = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(mergedId))).getSingle();
      expect(mergedRow.maxDepth, 20);
      expect(mergedRow.runtime, 80 * 60); // createDive persists seconds.
    });

    test('rejects overlapping selections', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 90);
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));
      expect(() => service.apply(['a', 'b']), throwsArgumentError);
      expect(await db.select(db.dives).get(), hasLength(2)); // untouched
    });

    test(
      'rejects when a selected dive no longer exists; DB untouched',
      () async {
        await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
        // 'ghost' was never created -> only 1 dive loads -> tooFewDives.
        expect(() => service.apply(['a', 'ghost']), throwsArgumentError);
        expect(await db.select(db.dives).get(), hasLength(1));
        expect(await db.select(db.deletionLog).get(), isEmpty);
      },
    );
  });

  group('undo', () {
    test(
      'restores sources byte-for-byte and removes the merged dive',
      () async {
        await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
        await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));
        final before = await (db.select(
          db.dives,
        )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

        final outcome = await service.apply(['a', 'b']);
        await service.undo(outcome.snapshot);

        final after = await (db.select(
          db.dives,
        )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
        expect(after.map((r) => r.id), ['a', 'b']);
        // Every column identical except updatedAt and hlc: undo's
        // markRecordPending deliberately stamps a fresh, newer HLC on the
        // restored row (per DiveMergeService.undo's doc comment) so it wins
        // LWW conflict resolution over the merge's tombstone.
        // Drift ROW classes have value equality + copyWith; companions do not.
        for (var i = 0; i < before.length; i++) {
          expect(
            after[i].copyWith(updatedAt: 0, hlc: const Value(null)),
            before[i].copyWith(updatedAt: 0, hlc: const Value(null)),
          );
        }

        // Children restored with original ids.
        final tanks = await db.select(db.diveTanks).get();
        expect(tanks.map((t) => t.id).toSet(), {'tank-a', 'tank-b'});
        final buddies = await db.select(db.diveBuddies).get();
        expect(buddies.map((b) => b.id).toSet(), {'buddy-a', 'buddy-b'});
        final events = await db.select(db.diveProfileEvents).get();
        expect(events.map((e) => e.id).toSet(), {'event-a', 'event-b'});
        final sources = await db.select(db.diveDataSources).get();
        expect(sources.every((s) => s.isPrimary), isTrue); // original flag back

        // Media pointers restored.
        final media = await (db.select(
          db.media,
        )..where((t) => t.id.equals('media-a'))).getSingle();
        expect(media.diveId, 'a');

        // Merged dive tombstoned.
        final tombstones = await (db.select(
          db.deletionLog,
        )..where((t) => t.recordId.equals(outcome.mergedDive.id))).get();
        expect(tombstones, isNotEmpty);
      },
    );

    test('apply + undo round-trip works with foreign_keys ON '
        '(production path)', () async {
      await db.customStatement('PRAGMA foreign_keys = ON');

      // Seed every catalog row seedDive's children reference, so seeding
      // itself passes immediate FK enforcement.
      await db
          .into(db.divers)
          .insert(
            const DiversCompanion(
              id: Value('diver1'),
              name: Value('diver1'),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      await db
          .into(db.buddies)
          .insert(
            const BuddiesCompanion(
              id: Value('buddy-cat-1'),
              name: Value('buddy-cat-1'),
              createdAt: Value(0),
              updatedAt: Value(0),
            ),
          );
      await db
          .into(db.species)
          .insert(
            const SpeciesCompanion(
              id: Value('turtle'),
              commonName: Value('Turtle'),
              category: Value('reptile'),
            ),
          );

      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));

      final outcome = await service.apply(['a', 'b']);
      await service.undo(outcome.snapshot);

      final after = await (db.select(
        db.dives,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(after.map((r) => r.id), ['a', 'b']);
      final tanks = await db.select(db.diveTanks).get();
      expect(tanks.map((t) => t.id).toSet(), {'tank-a', 'tank-b'});
      // tankPressureProfiles.tankId is an FK into diveTanks: these rows only
      // restore if the parent tanks were re-inserted first.
      final pressures = await db.select(db.tankPressureProfiles).get();
      expect(pressures.map((p) => p.id).toSet(), {'tp-a', 'tp-b'});
    });
  });
}
