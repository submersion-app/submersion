import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/seen_species_repository.dart';

import '../../../../helpers/test_database.dart';

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

Future<void> insertTestSite(String id, String name) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insertOnConflictUpdate(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(name),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestDive({
  required String id,
  required DateTime at,
  String? diverId,
  String? siteId,
  int? number,
  double? maxDepth,
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveNumber: Value(number),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          diverId: Value(diverId),
          siteId: Value(siteId),
          maxDepth: Value(maxDepth),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> insertTestSpecies({
  required String id,
  required String name,
  String? scientific,
  SpeciesCategory category = SpeciesCategory.fish,
  bool builtIn = false,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          scientificName: Value(scientific),
          category: Value(category.name),
          isBuiltIn: Value(builtIn),
        ),
      );
}

Future<void> insertTestSighting({
  required String id,
  required String diveId,
  required String speciesId,
  int count = 1,
  String notes = '',
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.sightings)
      .insert(
        SightingsCompanion(
          id: Value(id),
          diveId: Value(diveId),
          speciesId: Value(speciesId),
          count: Value(count),
          notes: Value(notes),
        ),
      );
}

/// Two divers, two sites, five dives, four species (one never seen).
///
/// diver-a: d1 (s1, Jan), d2 (s1, Feb), d3 (s2, Mar), d4 (no site, Apr)
/// diver-b: d5 (s2, May)
/// whale shark: d1 x2, d2 x1, d4 x3   turtle: d3 x1
/// custom c1:   d1 x1, d5 x4           sp_unseen: nothing
Future<void> seedLogbook() async {
  await insertTestDiver('diver-a');
  await insertTestDiver('diver-b');
  await insertTestSite('s1', 'Blue Hole');
  await insertTestSite('s2', 'Shark Point');
  await insertTestDive(
    id: 'd1',
    at: DateTime(2024, 1, 10),
    diverId: 'diver-a',
    siteId: 's1',
    number: 101,
    maxDepth: 18.0,
  );
  await insertTestDive(
    id: 'd2',
    at: DateTime(2024, 2, 20),
    diverId: 'diver-a',
    siteId: 's1',
    number: 102,
    maxDepth: 22.0,
  );
  await insertTestDive(
    id: 'd3',
    at: DateTime(2024, 3, 5),
    diverId: 'diver-a',
    siteId: 's2',
    number: 103,
  );
  await insertTestDive(
    id: 'd4',
    at: DateTime(2024, 4, 1),
    diverId: 'diver-a',
    number: 104,
    maxDepth: 12.5,
  );
  await insertTestDive(
    id: 'd5',
    at: DateTime(2024, 5, 1),
    diverId: 'diver-b',
    siteId: 's2',
    number: 7,
  );
  await insertTestSpecies(
    id: 'sp_whale_shark',
    name: 'Whale Shark',
    scientific: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    builtIn: true,
  );
  await insertTestSpecies(
    id: 'sp_green_sea_turtle',
    name: 'Green Sea Turtle',
    category: SpeciesCategory.turtle,
    builtIn: true,
  );
  await insertTestSpecies(id: 'c1', name: 'My Nudibranch');
  await insertTestSpecies(id: 'sp_unseen', name: 'Unseen Fish', builtIn: true);
  await insertTestSighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp_whale_shark',
    count: 2,
    notes: 'Juvenile under the ledge',
  );
  await insertTestSighting(
    id: 'sg2',
    diveId: 'd2',
    speciesId: 'sp_whale_shark',
  );
  await insertTestSighting(
    id: 'sg3',
    diveId: 'd4',
    speciesId: 'sp_whale_shark',
    count: 3,
  );
  await insertTestSighting(
    id: 'sg4',
    diveId: 'd3',
    speciesId: 'sp_green_sea_turtle',
  );
  await insertTestSighting(id: 'sg5', diveId: 'd1', speciesId: 'c1');
  await insertTestSighting(id: 'sg6', diveId: 'd5', speciesId: 'c1', count: 4);
}

void main() {
  late SeenSpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SeenSpeciesRepository();
    await seedLogbook();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getSeenSpecies', () {
    test('returns only species with sightings, scoped to the diver', () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');

      expect(entries.map((e) => e.species.id).toSet(), {
        'sp_whale_shark',
        'sp_green_sea_turtle',
        'c1',
      });
    });

    test('sums sighting counts separately from the dive count', () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');
      final whale = entries.singleWhere(
        (e) => e.species.id == 'sp_whale_shark',
      );

      expect(whale.totalSightings, 6);
      expect(whale.diveCount, 3);
    });

    test('does not count a site-less dive as a site', () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');
      final whale = entries.singleWhere(
        (e) => e.species.id == 'sp_whale_shark',
      );

      // d1 and d2 are both at s1; d4 has no site.
      expect(whale.siteCount, 1);
    });

    test('reports first and last seen from the dive dates', () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');
      final whale = entries.singleWhere(
        (e) => e.species.id == 'sp_whale_shark',
      );

      expect(whale.firstSeen, DateTime(2024, 1, 10));
      expect(whale.lastSeen, DateTime(2024, 4, 1));
    });

    test('maps the species row including built-in flag and names', () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');
      final whale = entries.singleWhere(
        (e) => e.species.id == 'sp_whale_shark',
      );
      final custom = entries.singleWhere((e) => e.species.id == 'c1');

      expect(whale.species.isBuiltIn, isTrue);
      expect(whale.species.commonName, 'Whale Shark');
      expect(whale.species.scientificName, 'Rhincodon typus');
      expect(whale.species.category, SpeciesCategory.shark);
      expect(custom.species.isBuiltIn, isFalse);
    });

    test("excludes another diver's dives when a diver id is given", () async {
      final entries = await repository.getSeenSpecies(diverId: 'diver-a');
      final custom = entries.singleWhere((e) => e.species.id == 'c1');

      expect(custom.totalSightings, 1);
      expect(custom.diveCount, 1);
      expect(custom.siteCount, 1);
    });

    test("includes every diver's dives when no diver id is given", () async {
      final entries = await repository.getSeenSpecies();
      final custom = entries.singleWhere((e) => e.species.id == 'c1');

      expect(custom.totalSightings, 5);
      expect(custom.diveCount, 2);
      expect(custom.siteCount, 2);
      expect(custom.lastSeen, DateTime(2024, 5, 1));
    });

    test('returns an empty list for a diver with no sightings', () async {
      expect(await repository.getSeenSpecies(diverId: 'nobody'), isEmpty);
    });
  });
  group('getSightingsForSpecies', () {
    test("lists the diver's sightings newest dive first", () async {
      final records = await repository.getSightingsForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );

      expect(records.map((r) => r.diveId).toList(), ['d4', 'd2', 'd1']);
    });

    test('carries dive number, date, depth, count and notes', () async {
      final records = await repository.getSightingsForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );
      final first = records.last; // d1, the oldest

      expect(first.sightingId, 'sg1');
      expect(first.diveNumber, 101);
      expect(first.diveDateTime, DateTime(2024, 1, 10));
      expect(first.maxDepthMeters, 18.0);
      expect(first.count, 2);
      expect(first.notes, 'Juvenile under the ledge');
    });

    test(
      'resolves the site name and leaves it null for a site-less dive',
      () async {
        final records = await repository.getSightingsForSpecies(
          'sp_whale_shark',
          diverId: 'diver-a',
        );
        final atSite = records.singleWhere((r) => r.diveId == 'd1');
        final noSite = records.singleWhere((r) => r.diveId == 'd4');

        expect(atSite.siteId, 's1');
        expect(atSite.siteName, 'Blue Hole');
        expect(noSite.siteId, isNull);
        expect(noSite.siteName, isNull);
      },
    );

    test('scopes to the diver when given and to everyone otherwise', () async {
      final mine = await repository.getSightingsForSpecies(
        'c1',
        diverId: 'diver-a',
      );
      final everyone = await repository.getSightingsForSpecies('c1');

      expect(mine.map((r) => r.diveId).toList(), ['d1']);
      expect(everyone.map((r) => r.diveId).toList(), ['d5', 'd1']);
    });

    test('returns an empty list for a species never seen', () async {
      expect(await repository.getSightingsForSpecies('sp_unseen'), isEmpty);
    });
  });
}
