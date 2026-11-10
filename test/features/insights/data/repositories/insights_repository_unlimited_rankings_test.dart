import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4385: the Insights rankings load every row when asked for no
/// limit, so a card can show the whole ranking behind "Show all". Without
/// a limit argument each query still stops at ten.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  /// More rows than any default limit.
  const rows = 12;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
    for (var i = 0; i < rows; i++) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 'site$i',
              name: 'Site $i',
              country: Value('Country $i'),
              region: Value('Region $i'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: 'trip$i',
              name: 'Trip $i',
              startDate: 1,
              endDate: 2,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: 'center$i',
              name: 'Center $i',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive$i',
              diveDateTime: 1,
              siteId: Value('site$i'),
              tripId: Value('trip$i'),
              diveCenterId: Value('center$i'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: 'buddy$i',
              name: 'Buddy $i',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion.insert(
              id: 'link$i',
              diveId: 'dive$i',
              buddyId: 'buddy$i',
              createdAt: 1,
            ),
          );
      await db
          .into(db.species)
          .insert(
            SpeciesCompanion.insert(
              id: 'species$i',
              commonName: 'Species $i',
              category: 'fish',
            ),
          );
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 'sighting$i',
              diveId: 'dive$i',
              speciesId: 'species$i',
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  final rankings =
      <String, Future<List<RankingItem>> Function(InsightsRepository, int?)>{
        'top buddies': (r, limit) => r.getTopBuddies(limit: limit),
        'top dive centers': (r, limit) => r.getTopDiveCenters(limit: limit),
        'countries visited': (r, limit) => r.getCountriesVisited(limit: limit),
        'regions explored': (r, limit) => r.getRegionsExplored(limit: limit),
        'dives per trip': (r, limit) => r.getDivesPerTrip(limit: limit),
        'most common sightings': (r, limit) =>
            r.getMostCommonSightings(limit: limit),
        'best sites for marine life': (r, limit) =>
            r.getBestSitesForMarineLife(limit: limit),
      };

  for (final MapEntry(key: name, value: load) in rankings.entries) {
    test('$name returns every row when the limit is null', () async {
      final ranking = await load(repository, null);

      expect(ranking, hasLength(rows));
    });

    test('$name still honours a limit', () async {
      final ranking = await load(repository, 3);

      expect(ranking, hasLength(3));
    });
  }
}
