import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Two-device sync round-trip for multi-computer consolidation.
///
/// Device A seeds the pre-consolidation pair and publishes it; device B
/// obtains the pair through a real pull (so its copies are fully synced,
/// not sync-pending -- _applyRemoteDeletions deliberately skips tombstones
/// for pending local records, and the invariant under test only holds for
/// synced rows). A then folds the secondary dive into the target via
/// [DiveConsolidationService.apply] and pushes; B pulls and must end up
/// with the target dive carrying both computers' data sources plus
/// attributed children, and the folded secondary dive gone (tombstone
/// honored, not resurrected). A then undoes the consolidation and B's next
/// pull must restore both original dives with no orphaned children left
/// behind -- including the consolidation-created child rows, which undo
/// tombstones explicitly because the surviving target dive can never
/// cascade them away on a peer.
///
/// This uses two genuinely separate in-memory [AppDatabase] instances, swapped
/// into [DatabaseService] between "device" phases, rather than the
/// single-database `impersonateFreshDevice` trick used elsewhere in the sync
/// suite (see sync_round_trip_test.dart / sync_deletion_propagation_test.dart).
/// That trick reuses one physical set of rows for every device in turn, which
/// cannot model this scenario: B must hold its own live copy of the
/// un-consolidated pair at the exact moment A is consolidating its copy.
void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late FakeCloudStorageProvider cloud;

  setUp(() {
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await dbA.close();
    await dbB.close();
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// Makes [db] the active database for every repository/service in this
  /// test (they all resolve `DatabaseService.instance.database` dynamically
  /// on each call) and drops the process-wide HLC clock so it re-seeds from
  /// [db]'s own sync metadata and row HLCs on the next write, rather than
  /// carrying over whichever device was previously active.
  void switchTo(AppDatabase db) {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  domain.DiveTank tank(
    String id, {
    required double o2,
    double? start,
    double? end,
  }) => domain.DiveTank(
    id: id,
    gasMix: domain.GasMix(o2: o2, he: 0),
    startPressure: start,
    endPressure: end,
    order: 0,
  );

  Future<void> seedFkPrereqs(AppDatabase db) async {
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
    for (final computerId in ['comp-t', 'comp-s']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computerId,
              name: computerId,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    // Catalog row for the tag seeded onto the secondary below (#449 review
    // finding 1's junction-union path also needs cross-device sync
    // coverage, not just tanks/events).
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'tag1',
            name: 'tag1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  }

  Future<void> seedTag(
    AppDatabase db,
    String id, {
    required String diveId,
    required String tagId,
  }) async {
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion.insert(
            id: id,
            diveId: diveId,
            tagId: tagId,
            createdAt: 0,
          ),
        );
  }

  /// Seeds a dive via the repository (base row + tanks + profile) and stamps
  /// the raw `dives.computerId` FK column the way a real download does (the
  /// domain Dive entity has no computerId field).
  Future<void> seedDive(
    AppDatabase db,
    String id, {
    required DateTime entry,
    required String computerId,
    required String serial,
    List<domain.DiveTank> tanks = const [],
  }) async {
    await DiveRepository().createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 18,
        diveComputerSerial: serial,
        tanks: tanks,
        profile: [
          const domain.DiveProfilePoint(timestamp: 0, depth: 0),
          const domain.DiveProfilePoint(
            timestamp: 900,
            depth: 18,
            temperature: 22.5,
          ),
          const domain.DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
    await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
      DivesCompanion(computerId: Value(computerId)),
    );
  }

  Future<void> seedDataSource(
    AppDatabase db,
    String id, {
    required String diveId,
    required String computerId,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(
            computerId: Value(computerId),
            // A single-source downloaded dive's reading is primary --
            // matches what importProfile persists.
            isPrimary: const Value(true),
          ),
        );
  }

  Future<void> seedTankPressure(
    AppDatabase db,
    String id, {
    required String diveId,
    required String tankId,
    required int timestamp,
    required double pressure,
  }) async {
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion.insert(
            id: id,
            diveId: diveId,
            tankId: tankId,
            timestamp: timestamp,
            pressure: pressure,
          ),
        );
  }

  Future<void> seedEvent(
    AppDatabase db,
    String id, {
    required String diveId,
    required int timestamp,
    String? tankId,
  }) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: id,
            diveId: diveId,
            timestamp: timestamp,
            eventType: 'gaschange',
            createdAt: 0,
          ).copyWith(tankId: Value(tankId)),
        );
  }

  /// Seeds the pre-consolidation pair -- target 't' (comp-t) and secondary
  /// 's' (comp-s, 60s later) -- identically on [db]. Used to give both
  /// devices the same starting point independently, the way two devices
  /// that each downloaded from their own dive computer and separately
  /// synced would.
  Future<void> seedPreConsolidationPair(AppDatabase db) async {
    await seedFkPrereqs(db);

    await seedDive(
      db,
      't',
      entry: DateTime.utc(2026, 7, 1, 9),
      computerId: 'comp-t',
      serial: 'SER-T',
      tanks: [tank('tank-t1', o2: 21, start: 200, end: 100)],
    );
    await seedDataSource(db, 'src-t', diveId: 't', computerId: 'comp-t');
    await seedTankPressure(
      db,
      'tp-t1',
      diveId: 't',
      tankId: 'tank-t1',
      timestamp: 60,
      pressure: 190,
    );

    await seedDive(
      db,
      's',
      entry: DateTime.utc(2026, 7, 1, 9, 1),
      computerId: 'comp-s',
      serial: 'SER-S',
      tanks: [tank('tank-s1', o2: 32, start: 200, end: 120)],
    );
    await seedDataSource(db, 'src-s', diveId: 's', computerId: 'comp-s');
    await seedTankPressure(
      db,
      'tp-s1',
      diveId: 's',
      tankId: 'tank-s1',
      timestamp: 60,
      pressure: 195,
    );
    await seedEvent(
      db,
      'event-s1',
      diveId: 's',
      timestamp: 30,
      tankId: 'tank-s1',
    );
    await seedTag(db, 'dtag-s1', diveId: 's', tagId: 'tag1');
  }

  test('device A consolidates two computer downloads; device B (holding the '
      'original un-consolidated pair) pulls the result, then A undoes and B '
      'gets both originals back with no orphaned children', () async {
    // Device A seeds the pre-consolidation pair and publishes it; device B
    // then PULLS the pair through a real sync rather than seeding its own
    // copy. This matters: a locally seeded copy would still be
    // sync-pending on B, and _applyRemoteDeletions deliberately skips a
    // remote tombstone for a pending local record (local unpushed edits
    // win) -- the production invariant under test ("tombstoned source
    // dives don't resurrect") only holds for rows the receiving device
    // has fully synced, which is the real-world state this scenario
    // describes.
    dbB = await setUpTestDatabase();
    dbA = await setUpTestDatabase();
    switchTo(dbA);
    await seedPreConsolidationPair(dbA);
    final seedPush = await buildService().performSync();
    expect(
      seedPush.isSuccess,
      isTrue,
      reason:
          'device A seed push should succeed; got ${seedPush.status} '
          '(${seedPush.message})',
    );

    switchTo(dbB);
    final seedPull = await buildService().performSync();
    expect(
      seedPull.isSuccess,
      isTrue,
      reason:
          'device B seed pull should succeed; got ${seedPull.status} '
          '(${seedPull.message})',
    );
    expect(
      await DiveRepository().getDiveById('t'),
      isNotNull,
      reason: 'B must hold the synced target dive before consolidation',
    );
    expect(
      await DiveRepository().getDiveById('s'),
      isNotNull,
      reason: 'B must hold the synced secondary dive before consolidation',
    );

    switchTo(dbA);
    final consolidation = DiveConsolidationService(DiveRepository());
    final outcome = await consolidation.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
    );

    final pushA = await buildService().performSync();
    expect(
      pushA.isSuccess,
      isTrue,
      reason:
          'device A push should succeed; got ${pushA.status} '
          '(${pushA.message})',
    );

    // ---- Device B pulls the consolidation ----
    switchTo(dbB);
    final pullB = await buildService().performSync();
    expect(
      pullB.isSuccess,
      isTrue,
      reason:
          'device B pull should succeed; got ${pullB.status} '
          '(${pullB.message})',
    );

    final sourcesOnB = await (dbB.select(
      dbB.diveDataSources,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(sourcesOnB.map((s) => s.computerId).toSet(), {
      'comp-t',
      'comp-s',
    }, reason: 'B must see both computers as data sources on the target dive');
    expect(
      sourcesOnB.where((s) => s.isPrimary),
      hasLength(1),
      reason: 'exactly one source stays primary after consolidation',
    );

    final tanksOnB = await (dbB.select(
      dbB.diveTanks,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(tanksOnB, hasLength(2));
    final targetTankOnB = tanksOnB.firstWhere((t) => t.id == 'tank-t1');
    expect(
      targetTankOnB.computerId,
      'comp-t',
      reason: "first-consolidation backfill stamps the target's own tank too",
    );
    final foldedTankOnB = tanksOnB.firstWhere((t) => t.id != 'tank-t1');
    expect(
      foldedTankOnB.computerId,
      'comp-s',
      reason: 're-parented secondary tank must carry its source computer id',
    );

    final pressuresOnB = await (dbB.select(
      dbB.tankPressureProfiles,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(
      pressuresOnB.any((p) => p.computerId == 'comp-s'),
      isTrue,
      reason: "the secondary's tank pressure series must be re-parented",
    );

    final eventsOnB = await (dbB.select(
      dbB.diveProfileEvents,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(
      eventsOnB.any((e) => e.computerId == 'comp-s'),
      isTrue,
      reason: "the secondary's profile events must be re-parented",
    );

    final profilesOnB = await (dbB.select(
      dbB.diveProfiles,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(
      profilesOnB.any((p) => p.computerId == 'comp-s'),
      isTrue,
      reason: "the secondary's profile points must be re-parented",
    );

    final tagsOnB = await (dbB.select(
      dbB.diveTags,
    )..where((t) => t.diveId.equals('t'))).get();
    expect(
      tagsOnB.map((t) => t.tagId),
      contains('tag1'),
      reason:
          "B must see the secondary's tag unioned onto the target dive "
          '(#449 review finding 1)',
    );

    final secondaryOnB = await DiveRepository().getDiveById('s');
    expect(
      secondaryOnB,
      isNull,
      reason:
          'the folded secondary dive must be tombstoned, not resurrected, '
          'on B',
    );

    // ---- Device A undoes the consolidation ----
    switchTo(dbA);
    await consolidation.undo(outcome.snapshot);
    final undoPush = await buildService().performSync();
    expect(
      undoPush.isSuccess,
      isTrue,
      reason:
          'device A undo-push should succeed; got ${undoPush.status} '
          '(${undoPush.message})',
    );

    // ---- Device B pulls the undo ----
    switchTo(dbB);
    final undoPull = await buildService().performSync();
    expect(
      undoPull.isSuccess,
      isTrue,
      reason:
          'device B undo-pull should succeed; got ${undoPull.status} '
          '(${undoPull.message})',
    );

    final tOnBAfterUndo = await DiveRepository().getDiveById('t');
    final sOnBAfterUndo = await DiveRepository().getDiveById('s');
    expect(tOnBAfterUndo, isNotNull);
    expect(
      sOnBAfterUndo,
      isNotNull,
      reason: 'undo must restore the secondary dive on B too',
    );

    // No orphaned children on B: exactly the two original tank rows,
    // each back under its original dive.
    final tanksAfterUndo = await dbB.select(dbB.diveTanks).get();
    expect(
      tanksAfterUndo.map((t) => t.id).toSet(),
      {'tank-t1', 'tank-s1'},
      reason:
          'undo must not leave the consolidation-created tank row behind '
          'on B',
    );
    final tankByIdAfterUndo = {for (final t in tanksAfterUndo) t.id: t};
    expect(tankByIdAfterUndo['tank-t1']!.diveId, 't');
    expect(tankByIdAfterUndo['tank-s1']!.diveId, 's');

    final sourcesAfterUndo = await dbB.select(dbB.diveDataSources).get();
    expect(
      sourcesAfterUndo.every((s) => s.isPrimary),
      isTrue,
      reason: 'undo restores each dive to a single primary source',
    );
    expect(sourcesAfterUndo.map((s) => s.diveId).toSet(), {'t', 's'});

    final pressuresAfterUndo = await dbB.select(dbB.tankPressureProfiles).get();
    expect(pressuresAfterUndo.map((p) => p.id).toSet(), {
      'tp-t1',
      'tp-s1',
    }, reason: 'undo must not leave orphaned tank-pressure rows on B');

    final eventsAfterUndo = await dbB.select(dbB.diveProfileEvents).get();
    expect(eventsAfterUndo.map((e) => e.id).toSet(), {
      'event-s1',
    }, reason: 'undo must not leave orphaned profile-event rows on B');

    final tagsAfterUndo = await dbB.select(dbB.diveTags).get();
    expect(
      tagsAfterUndo.map((t) => t.id).toSet(),
      {'dtag-s1'},
      reason:
          'undo must not leave the union-created tag row behind on B; the '
          'original tag returns to the secondary',
    );
    expect(tagsAfterUndo.single.diveId, 's');
  });
}
