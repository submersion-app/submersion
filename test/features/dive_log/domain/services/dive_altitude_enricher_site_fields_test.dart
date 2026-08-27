import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

import '../../../../helpers/test_database.dart';

/// Regression for issue #1187: the site altitude write-back used to push a
/// partial `dive.site` entity through `updateSite`, which writes every
/// column, so difficulty, water type, city, island, body of water, hazards
/// and the shared flag were nulled on every import at a site with no stored
/// altitude. The wipe then synced to the diver's other devices.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late SiteRepository sites;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ElevationService fixedElevation() => ElevationService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'elevation': [740.2],
        }),
        200,
      ),
    ),
  );

  Future<DiveSite> createRichSite() => sites.createSite(
    const DiveSite(
      id: 'site-rich',
      name: 'Hertenstein',
      description: 'Steep wall off the peninsula',
      location: GeoPoint(47.027631, 8.400640),
      minDepth: 5,
      maxDepth: 40,
      difficulty: SiteDifficulty.advanced,
      waterType: WaterType.fresh,
      country: 'Switzerland',
      region: 'Lucerne',
      city: 'Weggis',
      island: 'None',
      bodyOfWater: 'Lake Lucerne',
      rating: 4,
      notes: 'Bring a torch',
      hazards: 'Boat traffic',
      accessNotes: 'Steps down from the road',
      mooringNumber: 'M7',
      parkingInfo: 'Lay-by 100 m north',
      entryMethod: EntryMethod.shore,
      exitMethod: EntryMethod.ladder,
      isShared: true,
    ),
  );

  Dive diveAt(DiveSite site) => Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 8, 25, 10, 0),
    site: site,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  test('site altitude write-back keeps every other site field intact even '
      'when the dive carries a partial site entity', () async {
    await createRichSite();
    // Mimic the sparse site the dive repository used to hydrate: id, name
    // and coordinates only. Everything else is null on this entity.
    const partialSite = DiveSite(
      id: 'site-rich',
      name: 'Hertenstein',
      location: GeoPoint(47.027631, 8.400640),
    );
    final dive = await dives.createDive(diveAt(partialSite));
    final enricher = DiveAltitudeEnricher(
      elevationService: fixedElevation(),
      diveRepository: dives,
      siteRepository: sites,
    );

    final applied = await enricher.applyForImportedDive(dive);

    expect(applied, isTrue);
    final stored = await sites.getSiteById('site-rich');
    expect(stored, isNotNull);
    expect(stored!.altitude, 740.0, reason: 'the write-back must land');
    expect(stored.difficulty, SiteDifficulty.advanced);
    expect(stored.waterType, WaterType.fresh);
    expect(stored.minDepth, 5);
    expect(stored.maxDepth, 40);
    expect(stored.country, 'Switzerland');
    expect(stored.region, 'Lucerne');
    expect(stored.city, 'Weggis');
    expect(stored.island, 'None');
    expect(stored.bodyOfWater, 'Lake Lucerne');
    expect(stored.rating, 4);
    expect(stored.notes, 'Bring a torch');
    expect(stored.hazards, 'Boat traffic');
    expect(stored.accessNotes, 'Steps down from the road');
    expect(stored.mooringNumber, 'M7');
    expect(stored.parkingInfo, 'Lay-by 100 m north');
    expect(stored.entryMethod, EntryMethod.shore);
    expect(stored.exitMethod, EntryMethod.ladder);
    expect(stored.isShared, isTrue);
    expect(stored.description, 'Steep wall off the peninsula');
  });

  test('site altitude write-back marks the site pending for sync', () async {
    await createRichSite();
    final dive = await dives.createDive(
      diveAt(
        const DiveSite(
          id: 'site-rich',
          name: 'Hertenstein',
          location: GeoPoint(47.027631, 8.400640),
        ),
      ),
    );
    final enricher = DiveAltitudeEnricher(
      elevationService: fixedElevation(),
      diveRepository: dives,
      siteRepository: sites,
    );

    await enricher.applyForImportedDive(dive);

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals('site-rich'))).get();
    expect(pending, isNotEmpty, reason: 'the altitude change must sync');
  });
}
