import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiverRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> insertDiver(String id, {String name = 'Test Diver'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiverSettings(String diverId) async {
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion(
            id: Value('settings-$diverId'),
            diverId: Value(diverId),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    String? diverId,
    String? computerId,
    String? siteId,
    int? bottomTime,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(now),
            computerId: Value(computerId),
            siteId: Value(siteId),
            bottomTime: Value(bottomTime),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveComputer(
    String id, {
    String? diverId,
    String name = 'Test Computer',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertEquipment(
    String id, {
    String? diverId,
    String name = 'Test Gear',
    String type = 'regulator',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            type: Value(type),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveSite(
    String id, {
    String? diverId,
    String name = 'Test Site',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertBuddy(
    String id, {
    String? diverId,
    String name = 'Test Buddy',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveProfile(
    String id, {
    required String diveId,
    String? computerId,
    int timestamp = 0,
    double depth = 10.0,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  Future<void> insertDiveDataSource(
    String id, {
    required String diveId,
    String? computerId,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Query helpers (to verify deletion)
  // ---------------------------------------------------------------------------

  Future<List<Diver>> getDivers() => db.select(db.divers).get();

  Future<List<Dive>> getDives() => db.select(db.dives).get();

  Future<List<DiveComputer>> getDiveComputers() =>
      db.select(db.diveComputers).get();

  Future<List<EquipmentData>> getEquipment() => db.select(db.equipment).get();

  Future<List<DiveSite>> getDiveSites() => db.select(db.diveSites).get();

  Future<List<Buddy>> getBuddies() => db.select(db.buddies).get();

  Future<List<DiverSetting>> getDiverSettings() =>
      db.select(db.diverSettings).get();

  Future<List<DiveProfile>> getDiveProfiles() =>
      db.select(db.diveProfiles).get();

  Future<List<DiveDataSourcesData>> getDiveDataSources() =>
      db.select(db.diveDataSources).get();

  // ---------------------------------------------------------------------------
  // deleteDiver tests
  // ---------------------------------------------------------------------------

  group('deleteDiver', () {
    test('deletes the diver record', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');

      await repository.deleteDiver('d1');

      final divers = await getDivers();
      expect(divers, isEmpty);
    });

    test('deletes associated dives', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');
      await insertDive('dive-1', diverId: 'd1');
      await insertDive('dive-2', diverId: 'd1');

      await repository.deleteDiver('d1');

      final dives = await getDives();
      expect(dives, isEmpty);
    });

    test('deletes associated dive computers', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');
      await insertDiveComputer('comp-1', diverId: 'd1');
      await insertDiveComputer('comp-2', diverId: 'd1');

      await repository.deleteDiver('d1');

      final computers = await getDiveComputers();
      expect(computers, isEmpty);
    });

    test('deletes associated equipment', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');
      await insertEquipment('eq-1', diverId: 'd1');
      await insertEquipment('eq-2', diverId: 'd1', type: 'bcd');

      await repository.deleteDiver('d1');

      final gear = await getEquipment();
      expect(gear, isEmpty);
    });

    test('deletes associated dive sites', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');
      await insertDiveSite('site-1', diverId: 'd1');
      await insertDiveSite('site-2', diverId: 'd1');

      await repository.deleteDiver('d1');

      final sites = await getDiveSites();
      expect(sites, isEmpty);
    });

    test('deletes associated buddies', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');
      await insertBuddy('buddy-1', diverId: 'd1');
      await insertBuddy('buddy-2', diverId: 'd1');

      await repository.deleteDiver('d1');

      final buddies = await getBuddies();
      expect(buddies, isEmpty);
    });

    test('deletes diver settings', () async {
      await insertDiver('d1');
      await insertDiverSettings('d1');

      await repository.deleteDiver('d1');

      final settings = await getDiverSettings();
      expect(settings, isEmpty);
    });

    test('nulls cross-diver computer references in dives', () async {
      // Diver A owns a computer; Diver B has a dive that references it.
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertDiverSettings('diver-a');
      await insertDiverSettings('diver-b');
      await insertDiveComputer('comp-a', diverId: 'diver-a');
      await insertDive('dive-b', diverId: 'diver-b', computerId: 'comp-a');

      // Delete diver A (who owns the computer).
      await repository.deleteDiver('diver-a');

      // Diver B's dive should still exist, but computer_id should be null.
      final dives = await getDives();
      expect(dives, hasLength(1));
      expect(dives.first.id, equals('dive-b'));
      expect(dives.first.computerId, isNull);
    });

    test('nulls cross-diver computer references in dive_profiles', () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertDiverSettings('diver-a');
      await insertDiverSettings('diver-b');
      await insertDiveComputer('comp-a', diverId: 'diver-a');
      await insertDive('dive-b', diverId: 'diver-b');
      await insertDiveProfile(
        'profile-b',
        diveId: 'dive-b',
        computerId: 'comp-a',
      );

      await repository.deleteDiver('diver-a');

      final profiles = await getDiveProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.id, equals('profile-b'));
      expect(profiles.first.computerId, isNull);
    });

    test(
      'nulls cross-diver computer references in dive_data_sources',
      () async {
        await insertDiver('diver-a');
        await insertDiver('diver-b');
        await insertDiverSettings('diver-a');
        await insertDiverSettings('diver-b');
        await insertDiveComputer('comp-a', diverId: 'diver-a');
        await insertDive('dive-b', diverId: 'diver-b');
        await insertDiveDataSource(
          'ds-b',
          diveId: 'dive-b',
          computerId: 'comp-a',
        );

        await repository.deleteDiver('diver-a');

        final sources = await getDiveDataSources();
        expect(sources, hasLength(1));
        expect(sources.first.id, equals('ds-b'));
        expect(sources.first.computerId, isNull);
      },
    );

    test('preserves other diver data when deleting one diver', () async {
      // Set up two divers with full data sets.
      await insertDiver('diver-a');
      await insertDiver('diver-b');
      await insertDiverSettings('diver-a');
      await insertDiverSettings('diver-b');

      // Diver A's data
      await insertDive('dive-a', diverId: 'diver-a');
      await insertDiveComputer('comp-a', diverId: 'diver-a');
      await insertEquipment('eq-a', diverId: 'diver-a');
      await insertDiveSite('site-a', diverId: 'diver-a');
      await insertBuddy('buddy-a', diverId: 'diver-a');

      // Diver B's data
      await insertDive('dive-b', diverId: 'diver-b');
      await insertDiveComputer('comp-b', diverId: 'diver-b');
      await insertEquipment('eq-b', diverId: 'diver-b');
      await insertDiveSite('site-b', diverId: 'diver-b');
      await insertBuddy('buddy-b', diverId: 'diver-b');

      // Delete diver A only
      await repository.deleteDiver('diver-a');

      // Verify diver B and all their data are intact.
      final divers = await getDivers();
      expect(divers, hasLength(1));
      expect(divers.first.id, equals('diver-b'));

      final dives = await getDives();
      expect(dives, hasLength(1));
      expect(dives.first.id, equals('dive-b'));

      final computers = await getDiveComputers();
      expect(computers, hasLength(1));
      expect(computers.first.id, equals('comp-b'));

      final gear = await getEquipment();
      expect(gear, hasLength(1));
      expect(gear.first.id, equals('eq-b'));

      final sites = await getDiveSites();
      expect(sites, hasLength(1));
      expect(sites.first.id, equals('site-b'));

      final buddies = await getBuddies();
      expect(buddies, hasLength(1));
      expect(buddies.first.id, equals('buddy-b'));

      final settings = await getDiverSettings();
      expect(settings, hasLength(1));
      expect(settings.first.diverId, equals('diver-b'));
    });

    test('deletes diver with no associated data', () async {
      await insertDiver('d1');
      // No settings, no dives, no computers, no gear, etc.

      // Should not throw even with no associated data.
      await repository.deleteDiver('d1');

      final divers = await getDivers();
      expect(divers, isEmpty);
    });

    test(
      'does not leave stale own-diver dive computer_id on own dives',
      () async {
        // Diver A owns a computer and a dive that references it.
        // Both should be deleted (the dive for having diver_id=A,
        // the computer for having diver_id=A). The cross-diver null-out
        // should NOT affect own dives.
        await insertDiver('diver-a');
        await insertDiverSettings('diver-a');
        await insertDiveComputer('comp-a', diverId: 'diver-a');
        await insertDive('dive-a', diverId: 'diver-a', computerId: 'comp-a');

        await repository.deleteDiver('diver-a');

        final dives = await getDives();
        expect(dives, isEmpty);
        final computers = await getDiveComputers();
        expect(computers, isEmpty);
      },
    );
  });
}
