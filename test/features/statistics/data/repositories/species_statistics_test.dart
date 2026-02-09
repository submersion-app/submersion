import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';

import '../../../../helpers/test_database.dart';

/// Insert a diver into the test DB
Future<void> insertTestDiver(String id) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insertOnConflictUpdate(
        DiversCompanion(
          id: Value(id),
          name: Value('Diver $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Insert a dive with optional site, depth, dateTime, and diverId
Future<void> insertTestDive({
  required String id,
  String? diverId,
  String? siteId,
  double? maxDepth,
  DateTime? dateTime,
}) async {
  final db = DatabaseService.instance.database;
  final dt = dateTime ?? DateTime(2024, 6, 15, 10, 0);
  final now = DateTime.now().millisecondsSinceEpoch;

  if (siteId != null) {
    await db
        .into(db.diveSites)
        .insertOnConflictUpdate(
          DiveSitesCompanion(
            id: Value(siteId),
            name: Value('Site $siteId'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  if (diverId != null) {
    await insertTestDiver(diverId);
  }

  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(dt.millisecondsSinceEpoch),
          diverId: Value(diverId),
          siteId: Value(siteId),
          maxDepth: Value(maxDepth),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

void main() {
  late StatisticsRepository statsRepository;
  late SpeciesRepository speciesRepository;

  setUp(() async {
    await setUpTestDatabase();
    statsRepository = StatisticsRepository();
    speciesRepository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getSpeciesStatistics', () {
    test('returns empty stats for species with no sightings', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Unseen Fish',
        category: SpeciesCategory.fish,
      );

      final stats = await statsRepository.getSpeciesStatistics(
        speciesId: species.id,
      );

      expect(stats.isEmpty, true);
      expect(stats.totalSightings, 0);
      expect(stats.diveCount, 0);
    });

    test('returns correct aggregate statistics', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Test Butterflyfish',
        category: SpeciesCategory.fish,
      );

      await insertTestDive(
        id: 'dive-1',
        siteId: 'site-a',
        maxDepth: 15.0,
        dateTime: DateTime(2024, 1, 10),
      );
      await insertTestDive(
        id: 'dive-2',
        siteId: 'site-b',
        maxDepth: 28.0,
        dateTime: DateTime(2024, 6, 20),
      );

      await speciesRepository.addSighting(
        diveId: 'dive-1',
        speciesId: species.id,
        count: 3,
      );
      await speciesRepository.addSighting(
        diveId: 'dive-2',
        speciesId: species.id,
        count: 2,
      );

      final stats = await statsRepository.getSpeciesStatistics(
        speciesId: species.id,
      );

      expect(stats.isEmpty, false);
      expect(stats.totalSightings, 5);
      expect(stats.diveCount, 2);
      expect(stats.siteCount, 2);
      expect(stats.minDepthMeters, 15.0);
      expect(stats.maxDepthMeters, 28.0);
      expect(
        stats.firstSeen,
        DateTime.fromMillisecondsSinceEpoch(
          DateTime(2024, 1, 10).millisecondsSinceEpoch,
        ),
      );
      expect(
        stats.lastSeen,
        DateTime.fromMillisecondsSinceEpoch(
          DateTime(2024, 6, 20).millisecondsSinceEpoch,
        ),
      );
    });

    test('returns top sites sorted by sighting count', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Test Angelfish',
        category: SpeciesCategory.fish,
      );

      await insertTestDive(id: 'dive-a', siteId: 'site-alpha');
      await insertTestDive(id: 'dive-b', siteId: 'site-beta');
      await insertTestDive(id: 'dive-c', siteId: 'site-alpha');

      // site-alpha: 5 sightings total, site-beta: 1
      await speciesRepository.addSighting(
        diveId: 'dive-a',
        speciesId: species.id,
        count: 3,
      );
      await speciesRepository.addSighting(
        diveId: 'dive-c',
        speciesId: species.id,
        count: 2,
      );
      await speciesRepository.addSighting(
        diveId: 'dive-b',
        speciesId: species.id,
        count: 1,
      );

      final stats = await statsRepository.getSpeciesStatistics(
        speciesId: species.id,
      );

      expect(stats.topSites.length, 2);
      expect(stats.topSites[0].name, 'Site site-alpha');
      expect(stats.topSites[0].count, 5);
      expect(stats.topSites[1].name, 'Site site-beta');
      expect(stats.topSites[1].count, 1);
    });

    test('filters by diverId when provided', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Test Wrasse',
        category: SpeciesCategory.fish,
      );

      // Must insert divers first for FK constraint
      await insertTestDive(id: 'dive-d1', diverId: 'diver-alice');
      await insertTestDive(id: 'dive-d2', diverId: 'diver-bob');

      await speciesRepository.addSighting(
        diveId: 'dive-d1',
        speciesId: species.id,
        count: 4,
      );
      await speciesRepository.addSighting(
        diveId: 'dive-d2',
        speciesId: species.id,
        count: 7,
      );

      // Without filter: total = 11
      final allStats = await statsRepository.getSpeciesStatistics(
        speciesId: species.id,
      );
      expect(allStats.totalSightings, 11);

      // With filter: only Alice's dives
      final aliceStats = await statsRepository.getSpeciesStatistics(
        speciesId: species.id,
        diverId: 'diver-alice',
      );
      expect(aliceStats.totalSightings, 4);
      expect(aliceStats.diveCount, 1);
    });
  });

  group('SpeciesStatistics entity', () {
    test('empty constant has expected defaults', () {
      expect(SpeciesStatistics.empty.isEmpty, true);
      expect(SpeciesStatistics.empty.totalSightings, 0);
      expect(SpeciesStatistics.empty.diveCount, 0);
      expect(SpeciesStatistics.empty.topSites, isEmpty);
    });

    test('non-empty stats report isEmpty as false', () {
      const stats = SpeciesStatistics(
        totalSightings: 1,
        diveCount: 1,
        siteCount: 1,
        topSites: [],
      );
      expect(stats.isEmpty, false);
    });
  });
}
