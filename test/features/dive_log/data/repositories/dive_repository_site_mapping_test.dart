import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1187: `dive.site` used to be hydrated with 9 of the entity's 24
/// fields. Any caller that copied that entity and saved it wiped the rest.
void main() {
  late DiveRepository dives;
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    sites = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const richSite = DiveSite(
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
    altitude: 434,
    entryMethod: EntryMethod.shore,
    exitMethod: EntryMethod.ladder,
    isShared: true,
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

  void expectFullSite(DiveSite? site) {
    expect(site, isNotNull);
    // Photo ids are loaded separately by the site repository; everything
    // else on the row must be present on the dive's site.
    expect(site!.copyWith(photoIds: const []), richSite);
  }

  test('getDiveById hydrates every column of the linked site', () async {
    await sites.createSite(richSite);
    await dives.createDive(diveAt(richSite));

    final stored = await dives.getDiveById('d1');

    expectFullSite(stored!.site);
  });

  test('getAllDives hydrates every column of the linked site', () async {
    await sites.createSite(richSite);
    await dives.createDive(diveAt(richSite));

    final all = await dives.getAllDives();

    expect(all, hasLength(1));
    expectFullSite(all.single.site);
  });
}
