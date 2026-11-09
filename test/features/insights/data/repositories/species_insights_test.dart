import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';

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

/// Insert a dive with optional site, depth, dateTime, and diverId. [dateTime]
/// is a wall clock flagged UTC, the way dive_date_time is stored (#2808).
Future<void> insertTestDive({
  required String id,
  String? diverId,
  String? siteId,
  double? maxDepth,
  DateTime? dateTime,
}) async {
  final db = DatabaseService.instance.database;
  final dt = dateTime ?? DateTime.utc(2024, 6, 15, 10, 0);
  assert(dt.isUtc, 'dive_date_time is stored as a wall clock flagged UTC');
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
  late InsightsRepository statsRepository;
  late SpeciesRepository speciesRepository;

  setUp(() async {
    await setUpTestDatabase();
    statsRepository = InsightsRepository();
    speciesRepository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getSpeciesInsights', () {
    test('returns empty stats for species with no sightings', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Unseen Fish',
        category: SpeciesCategory.fish,
      );

      final stats = await statsRepository.getSpeciesInsights(
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
        dateTime: DateTime.utc(2024, 1, 10),
      );
      await insertTestDive(
        id: 'dive-2',
        siteId: 'site-b',
        maxDepth: 28.0,
        dateTime: DateTime.utc(2024, 6, 20),
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

      final stats = await statsRepository.getSpeciesInsights(
        speciesId: species.id,
      );

      expect(stats.isEmpty, false);
      // Sightings, not animals (issue #4337): two dives, two sightings.
      expect(stats.totalSightings, 2);
      expect(stats.diveCount, 2);
      expect(stats.siteCount, 2);
      expect(stats.minDepthMeters, 15.0);
      expect(stats.maxDepthMeters, 28.0);
      // DateTime equality compares the UTC flag, so these fail on a local
      // decode in any time zone, UTC CI included.
      expect(stats.firstSeen, DateTime.utc(2024, 1, 10));
      expect(stats.lastSeen, DateTime.utc(2024, 6, 20));
    });

    test('returns top sites sorted by sighting count', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Test Angelfish',
        category: SpeciesCategory.fish,
      );

      await insertTestDive(id: 'dive-a', siteId: 'site-alpha');
      await insertTestDive(id: 'dive-b', siteId: 'site-beta');
      await insertTestDive(id: 'dive-c', siteId: 'site-alpha');

      // site-alpha: seen on 2 dives, site-beta: 1 (counts are not summed)
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

      final stats = await statsRepository.getSpeciesInsights(
        speciesId: species.id,
      );

      expect(stats.topSites.length, 2);
      expect(stats.topSites[0].name, 'Site site-alpha');
      expect(stats.topSites[0].count, 2);
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

      // Without filter: two sightings
      final allStats = await statsRepository.getSpeciesInsights(
        speciesId: species.id,
      );
      expect(allStats.totalSightings, 2);

      // With filter: only Alice's dives
      final aliceStats = await statsRepository.getSpeciesInsights(
        speciesId: species.id,
        diverId: 'diver-alice',
      );
      expect(aliceStats.totalSightings, 1);
      expect(aliceStats.diveCount, 1);
    });
  });

  group('abundance does not inflate totals (issue #4337)', () {
    test('an exact 40 and a Few rank as two dives, not 41', () async {
      final jack = await speciesRepository.createSpecies(
        commonName: 'Test Jack',
        category: SpeciesCategory.fish,
      );
      final grouper = await speciesRepository.createSpecies(
        commonName: 'Test Grouper',
        category: SpeciesCategory.fish,
      );
      await insertTestDive(id: 'dive-x', siteId: 'site-x');
      await insertTestDive(id: 'dive-y', siteId: 'site-x');
      await insertTestDive(id: 'dive-z', siteId: 'site-x');

      await speciesRepository.addSighting(
        diveId: 'dive-x',
        speciesId: jack.id,
        abundance: SightingAbundance.exact,
        count: 40,
      );
      await speciesRepository.addSighting(
        diveId: 'dive-y',
        speciesId: jack.id,
        abundance: SightingAbundance.few,
      );
      for (final dive in ['dive-x', 'dive-y', 'dive-z']) {
        await speciesRepository.addSighting(
          diveId: dive,
          speciesId: grouper.id,
        );
      }

      final ranking = await statsRepository.getMostCommonSightings();
      expect(ranking.map((r) => (r.name, r.count)), [
        ('Test Grouper', 3),
        ('Test Jack', 2),
      ]);

      final stats = await statsRepository.getSpeciesInsights(
        speciesId: jack.id,
      );
      expect(stats.totalSightings, 2);
      expect(stats.topSites.single.count, 2);
    });

    test('two rows of one species on one dive count once', () async {
      final ray = await speciesRepository.createSpecies(
        commonName: 'Test Ray',
        category: SpeciesCategory.ray,
      );
      await insertTestDive(id: 'dive-r', siteId: 'site-r');
      for (var i = 0; i < 2; i++) {
        await speciesRepository.addSighting(
          diveId: 'dive-r',
          speciesId: ray.id,
        );
      }

      final stats = await statsRepository.getSpeciesInsights(speciesId: ray.id);
      expect(stats.totalSightings, 1);
      expect(stats.diveCount, 1);
    });
  });

  // Issue #4339: the stored category key went into the subtitle, which the
  // page rendered as text ("fish") in every language. It belongs in `kind`,
  // the field the page names in the viewer's language.
  group('getMostCommonSightings', () {
    test('carries the category as a kind, not as display text', () async {
      final species = await speciesRepository.createSpecies(
        commonName: 'Test Perch',
        category: SpeciesCategory.fish,
      );
      await insertTestDive(id: 'dive-1');
      await speciesRepository.addSighting(
        diveId: 'dive-1',
        speciesId: species.id,
      );

      final items = await statsRepository.getMostCommonSightings();

      expect(items, hasLength(1));
      expect(items.single.name, 'Test Perch');
      expect(items.single.count, 1, reason: 'one dive (issue #4337)');
      expect(items.single.kind, 'fish');
      expect(items.single.subtitle, isNull);
    });
  });

  group('SpeciesInsights entity', () {
    test('empty constant has expected defaults', () {
      expect(SpeciesInsights.empty.isEmpty, true);
      expect(SpeciesInsights.empty.totalSightings, 0);
      expect(SpeciesInsights.empty.diveCount, 0);
      expect(SpeciesInsights.empty.topSites, isEmpty);
    });

    test('non-empty stats report isEmpty as false', () {
      const stats = SpeciesInsights(
        totalSightings: 1,
        diveCount: 1,
        siteCount: 1,
        topSites: [],
      );
      expect(stats.isEmpty, false);
    });
  });
}
