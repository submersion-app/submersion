import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_offer.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';

/// A record that carries every detail the catalogue can hold.
const _full = CatalogueSite(
  id: 'r1',
  name: 'Salt Pier',
  location: GeoPoint(12.0000, -68.0000),
  countryCode: 'BQ',
  country: 'Caribbean Netherlands',
  region: 'Bonaire',
  locality: 'Kralendijk',
  island: 'Bonaire',
  bodyOfWater: 'Caribbean Sea',
  waterType: WaterType.salt,
  minDepth: 5,
  maxDepth: 15,
  typeIds: ['reef'],
  entryMethods: [EntryMethod.shore],
  difficulty: SiteDifficulty.beginner,
  hazards: 'Boat traffic',
  description: 'Pillars.',
  source: 'osm',
);

/// A record that has only a name.
const _bare = CatalogueSite(id: 'r2', name: 'Salt Pier', source: 'osm');

/// A site at the record's place with nothing else filled in.
const _atRecord = DiveSite(
  id: 's1',
  name: 'Salt Pier',
  location: GeoPoint(12.0000, -68.0000),
);

Set<CatalogueGapField> _offer(
  DiveSite site, {
  CatalogueSite record = _full,
  bool siteHasTypes = false,
}) => catalogueOfferFor(site, siteHasTypes: siteHasTypes, record: record);

void main() {
  test('an empty site at the record takes everything but a position', () {
    expect(_offer(_atRecord), {
      CatalogueGapField.depth,
      CatalogueGapField.country,
      CatalogueGapField.region,
      CatalogueGapField.city,
      CatalogueGapField.island,
      CatalogueGapField.bodyOfWater,
      CatalogueGapField.waterType,
      CatalogueGapField.siteTypes,
      CatalogueGapField.entry,
      CatalogueGapField.difficulty,
      CatalogueGapField.hazards,
      CatalogueGapField.description,
    });
  });

  test('a record with only a name offers nothing', () {
    expect(_offer(_atRecord, record: _bare), isEmpty);
    expect(
      _offer(
        const DiveSite(id: 's1', name: 'X'),
        record: _bare,
      ),
      isEmpty,
    );
  });

  test('a filled site is offered nothing', () {
    const filled = DiveSite(
      id: 's1',
      name: 'Salt Pier',
      location: GeoPoint(12.0000, -68.0000),
      minDepth: 3,
      maxDepth: 30,
      country: 'Bonaire',
      region: 'South',
      city: 'Town',
      island: 'Isle',
      bodyOfWater: 'Sea',
      waterType: WaterType.fresh,
      entryMethods: [EntryMethod.boat],
      difficulty: SiteDifficulty.advanced,
      hazards: 'None',
      description: 'Mine.',
    );

    expect(_offer(filled, siteHasTypes: true), isEmpty);
  });

  group('each field is offered only where the site has nothing', () {
    void check(
      CatalogueGapField field, {
      required DiveSite filled,
      bool siteHasTypes = false,
    }) {
      expect(_offer(_atRecord), contains(field), reason: 'empty: $field');
      expect(
        _offer(filled, siteHasTypes: siteHasTypes),
        isNot(contains(field)),
        reason: 'filled: $field',
      );
    }

    test('depth', () {
      check(CatalogueGapField.depth, filled: _atRecord.copyWith(maxDepth: 30));
      check(CatalogueGapField.depth, filled: _atRecord.copyWith(minDepth: 3));
    });
    test('country', () {
      check(
        CatalogueGapField.country,
        filled: _atRecord.copyWith(country: 'X'),
      );
    });
    test('region', () {
      check(CatalogueGapField.region, filled: _atRecord.copyWith(region: 'X'));
    });
    test('town', () {
      check(CatalogueGapField.city, filled: _atRecord.copyWith(city: 'X'));
    });
    test('island', () {
      check(CatalogueGapField.island, filled: _atRecord.copyWith(island: 'X'));
    });
    test('body of water', () {
      check(
        CatalogueGapField.bodyOfWater,
        filled: _atRecord.copyWith(bodyOfWater: 'X'),
      );
    });
    test('water type', () {
      check(
        CatalogueGapField.waterType,
        filled: _atRecord.copyWith(waterType: WaterType.fresh),
      );
    });
    test('site types', () {
      check(CatalogueGapField.siteTypes, filled: _atRecord, siteHasTypes: true);
    });
    test('entry', () {
      check(
        CatalogueGapField.entry,
        filled: _atRecord.copyWith(entryMethods: const [EntryMethod.boat]),
      );
    });
    test('difficulty', () {
      check(
        CatalogueGapField.difficulty,
        filled: _atRecord.copyWith(difficulty: SiteDifficulty.advanced),
      );
    });
    test('hazards', () {
      check(
        CatalogueGapField.hazards,
        filled: _atRecord.copyWith(hazards: 'X'),
      );
    });
    test('description', () {
      check(
        CatalogueGapField.description,
        filled: _atRecord.copyWith(description: 'X'),
      );
    });
  });

  test('text that is only spaces counts as empty', () {
    final site = _atRecord.copyWith(
      country: '  ',
      hazards: ' ',
      description: '\n',
    );

    expect(
      _offer(site),
      containsAll([
        CatalogueGapField.country,
        CatalogueGapField.hazards,
        CatalogueGapField.description,
      ]),
    );
  });

  test('a record whose text is only spaces does not carry that field', () {
    const record = CatalogueSite(
      id: 'r3',
      name: 'Salt Pier',
      location: GeoPoint(12.0000, -68.0000),
      country: ' ',
      hazards: '',
      description: '  ',
      source: 'osm',
    );

    expect(_offer(_atRecord, record: record), isEmpty);
  });

  test('a record with one depth still offers depth', () {
    const record = CatalogueSite(
      id: 'r3',
      name: 'Wreck',
      location: GeoPoint(12.0000, -68.0000),
      maxDepth: 28,
      source: 'ukho',
    );

    expect(_offer(_atRecord, record: record), {CatalogueGapField.depth});
  });

  group('position', () {
    test('is offered to a site that has none', () {
      const site = DiveSite(id: 's1', name: 'Salt Pier');

      expect(_offer(site), contains(CatalogueGapField.position));
    });

    test('is never offered to a site that has one', () {
      expect(_offer(_atRecord), isNot(contains(CatalogueGapField.position)));
    });

    test('is not offered by a record that has none', () {
      const site = DiveSite(id: 's1', name: 'Salt Pier');
      const record = CatalogueSite(
        id: 'r3',
        name: 'Salt Pier',
        description: 'Pillars.',
        source: 'osm',
      );

      expect(_offer(site, record: record), {CatalogueGapField.description});
    });
  });

  group('place fields follow the place', () {
    // About 111 m per 0.001 degree of latitude.
    test('a site 100 m from the record takes its place names', () {
      final site = _atRecord.copyWith(location: const GeoPoint(12.0009, -68));

      expect(
        _offer(site),
        containsAll(
          CatalogueGapField.place.difference({CatalogueGapField.position}),
        ),
      );
    });

    test('a site 400 m away takes none of them, and still the rest', () {
      final site = _atRecord.copyWith(location: const GeoPoint(12.0036, -68));

      final offer = _offer(site);
      expect(offer.intersection(CatalogueGapField.place), isEmpty);
      expect(
        offer,
        containsAll([CatalogueGapField.depth, CatalogueGapField.description]),
      );
    });

    test('a site with no position takes every place field', () {
      const site = DiveSite(id: 's1', name: 'Salt Pier');

      expect(_offer(site), containsAll(CatalogueGapField.place));
    });

    test(
      'a located site is given no place names by a record with no position',
      () {
        const record = CatalogueSite(
          id: 'r3',
          name: 'Salt Pier',
          country: 'Caribbean Netherlands',
          description: 'Pillars.',
          source: 'osm',
        );

        expect(_offer(_atRecord, record: record), {
          CatalogueGapField.description,
        });
      },
    );
  });

  group('details the diver turned down', () {
    test('are left out for that record', () {
      final site = _atRecord.copyWith(
        catalogueAnswers: const SiteCatalogueAnswers(
          declined: {
            'r1': {'depth', 'description'},
          },
        ),
      );

      final offer = _offer(site);
      expect(offer, isNot(contains(CatalogueGapField.depth)));
      expect(offer, isNot(contains(CatalogueGapField.description)));
      expect(offer, contains(CatalogueGapField.hazards));
    });

    test('turned down for another record still count as offered', () {
      final site = _atRecord.copyWith(
        catalogueAnswers: const SiteCatalogueAnswers(
          declined: {
            'other': {'depth'},
          },
        ),
      );

      expect(_offer(site), contains(CatalogueGapField.depth));
    });

    test('a name this build does not know is ignored', () {
      final site = _atRecord.copyWith(
        catalogueAnswers: const SiteCatalogueAnswers(
          declined: {
            'r1': {'visibility'},
          },
        ),
      );

      expect(_offer(site), contains(CatalogueGapField.depth));
    });
  });

  test('the offer comes in the order the fields are shown', () {
    const site = DiveSite(id: 's1', name: 'Salt Pier');

    expect(_offer(site).toList(), CatalogueGapField.values);
  });
}
