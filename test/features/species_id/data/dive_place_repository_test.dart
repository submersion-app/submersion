import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/species_id/data/repositories/dive_place_repository.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';

/// Where a dive is, for a Find species run, read without the dive's
/// profile (issue #4727): the same points the full dive read gives.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> siteAt(String id, {double? lat, double? lon}) async {
    await insertTestSite(id, 'Salt Pier');
    await (db.update(db.diveSites)..where((t) => t.id.equals(id))).write(
      DiveSitesCompanion(latitude: Value(lat), longitude: Value(lon)),
    );
  }

  Future<void> diveAt(
    String id, {
    String? siteId,
    double? lat,
    double? lon,
  }) async {
    await insertTestDive(id: id, at: DateTime(2024, 1, 10), siteId: siteId);
    await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
      DivesCompanion(entryLatitude: Value(lat), entryLongitude: Value(lon)),
    );
  }

  test('a dive with a site and an entry point gives both', () async {
    await siteAt('s1', lat: 12.08, lon: -68.28);
    await diveAt('d1', siteId: 's1', lat: 12.09, lon: -68.29);

    final place = await DivePlaceRepository().placeOf('d1');

    expect(place.exists, isTrue);
    expect(place.site, const GeoPoint(12.08, -68.28));
    expect(place.entry, const GeoPoint(12.09, -68.29));
  });

  test('a dive with no site and no entry point is somewhere unknown', () async {
    await diveAt('d1');

    final place = await DivePlaceRepository().placeOf('d1');

    expect(place.exists, isTrue);
    expect(place.site, isNull);
    expect(place.entry, isNull);
  });

  test('half a position is no position, as the dive read has it', () async {
    await siteAt('s1', lat: 12.08);
    await diveAt('d1', siteId: 's1', lon: -68.29);

    final place = await DivePlaceRepository().placeOf('d1');

    expect(place.site, isNull);
    expect(place.entry, isNull);
  });

  test('a dive that is gone', () async {
    final place = await DivePlaceRepository().placeOf('gone');

    expect(place.exists, isFalse);
  });
}
