import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_mapping.dart';

void main() {
  const full = CatalogueSite(
    id: 'osm_node_1',
    name: 'Salt Pier',
    location: GeoPoint(12.08, -68.28),
    countryCode: 'BQ',
    country: 'Caribbean Netherlands',
    region: 'Kralendijk',
    locality: 'Belnem',
    island: 'Bonaire',
    bodyOfWater: 'Caribbean Sea',
    waterType: WaterType.salt,
    minDepth: 5,
    maxDepth: 15,
    typeIds: ['reef', 'pier'],
    entryMethods: [EntryMethod.shore],
    features: ['drift'],
    difficulty: SiteDifficulty.beginner,
    hazards: 'boat traffic',
    description: 'Pillars.',
    website: 'https://example.org',
    source: 'osm',
    sourceRef: 'https://www.openstreetmap.org/node/1',
  );

  test('every catalogue detail reaches the site', () {
    final site = catalogueSiteToDiveSite(full, diverId: 'diver-1');

    expect(
      site,
      const DiveSite(
        id: '',
        diverId: 'diver-1',
        name: 'Salt Pier',
        description: 'Pillars.',
        location: GeoPoint(12.08, -68.28),
        minDepth: 5,
        maxDepth: 15,
        difficulty: SiteDifficulty.beginner,
        waterType: WaterType.salt,
        country: 'Caribbean Netherlands',
        countryCode: 'BQ',
        region: 'Kralendijk',
        city: 'Belnem',
        island: 'Bonaire',
        bodyOfWater: 'Caribbean Sea',
        hazards: 'boat traffic',
        entryMethods: [EntryMethod.shore],
        website: 'https://example.org',
        catalogueId: 'osm_node_1',
      ),
    );
  });

  test('the site types come from the catalogue record', () {
    final classification = catalogueSiteClassification(full);

    expect(classification.typeIds, ['reef', 'pier']);
    expect(classification.tagIds, isEmpty);
  });

  test('nothing is written beyond the catalogue\'s own text', () {
    const bare = CatalogueSite(
      id: 'osm_node_2',
      name: 'Angel City',
      features: ['drift', 'sharks'],
      source: 'osm',
    );

    final site = catalogueSiteToDiveSite(bare);

    // No "Imported from ..." note and no "Features: ..." line.
    expect(site.notes, '');
    expect(site.description, '');
  });

  test('what the catalogue does not hold is left empty', () {
    final site = catalogueSiteToDiveSite(full);

    expect(site.diverId, isNull);
    expect(site.exitMethods, isEmpty);
    expect(site.rating, isNull);
    expect(site.accessNotes, isNull);
    expect(site.parkingInfo, isNull);
    expect(site.mooringNumber, isNull);
    expect(site.altitude, isNull);
    expect(site.isShared, isFalse);
    expect(site.sharedLibraryId, isNull);
  });

  test('a site without coordinates maps to a site without a location', () {
    const unlocated = CatalogueSite(
      id: 'osm_way_3',
      name: 'Somewhere',
      countryCode: 'CW',
      country: 'Curaçao',
      source: 'osm',
    );

    final site = catalogueSiteToDiveSite(unlocated);

    expect(site.location, isNull);
    expect(site.country, 'Curaçao');
    expect(site.catalogueId, 'osm_way_3');
  });

  test('the record\'s web address comes along; anything else does not', () {
    const withWebsite = CatalogueSite(
      id: 'osm_node_9',
      name: 'Stoney Cove',
      website: 'https://stoneycove.com',
      source: 'osm',
    );
    expect(
      catalogueSiteToDiveSite(withWebsite).website,
      'https://stoneycove.com',
    );
    const withPhone = CatalogueSite(
      id: 'osm_node_10',
      name: 'Stoney Cove',
      website: 'tel:123',
      source: 'osm',
    );
    expect(catalogueSiteToDiveSite(withPhone).website, isNull);
  });

  // What the diver reads and what a tap opens must agree (review).
  test('a website with user info in front of its host is not adopted', () {
    expect(catalogueWebsiteText('https://shop.example@evil.example'), isNull);
    expect(catalogueWebsiteText('https://user:pw@stoneycove.com'), isNull);
    expect(
      catalogueWebsiteText(' https://stoneycove.com/dive '),
      'https://stoneycove.com/dive',
    );
  });
}
