import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/place_name_language.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/geography/country_display_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/constants/iso_countries.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';

DiveSite _site({
  required String id,
  required String name,
  String? country,
  String? region,
  String? city,
  String? island,
  String? bodyOfWater,
}) {
  return DiveSite(
    id: id,
    name: name,
    country: country,
    region: region,
    city: city,
    island: island,
    bodyOfWater: bodyOfWater,
  );
}

void main() {
  final sites = [
    _site(id: '1', name: 'Manta Point', country: 'Indonesia', region: 'Bali'),
    _site(id: '2', name: 'Blue Hole', country: 'Egypt', region: 'Dahab'),
    _site(
      id: '3',
      name: 'Crystal Bay',
      country: 'Indonesia',
      region: 'Nusa Penida',
    ),
  ];

  group('suggestedSiteNames', () {
    test('returns distinct names sorted case-insensitively', () {
      expect(suggestedSiteNames(sites), [
        'Blue Hole',
        'Crystal Bay',
        'Manta Point',
      ]);
    });

    test('excludes the site with excludeId', () {
      expect(suggestedSiteNames(sites, excludeId: '1'), [
        'Blue Hole',
        'Crystal Bay',
      ]);
    });
  });

  group('suggestedCountries', () {
    test('lists the user countries first (alpha), then ISO extras', () {
      final result = suggestedCountries(sites, language: 'en');
      expect(result.take(2), ['Egypt', 'Indonesia']);
      // ISO extras follow and exclude already-used countries.
      expect(result, contains('Mexico'));
      expect(result.where((c) => c == 'Egypt').length, 1);
    });

    test('offers the extras in the place-name language (issue #5019)', () {
      final result = suggestedCountries(sites, language: 'de');
      expect(result.take(2), ['Egypt', 'Indonesia']);
      expect(result, containsAll(['Mexiko', 'Niederlande']));
      expect(result, isNot(contains('Mexico')));
      // Egypt is used, so its German name is not offered beside it.
      expect(result, isNot(contains('Ägypten')));
    });
  });

  group('suggestedCountryNames', () {
    test('used names come first, once each, then ISO names not used', () {
      final result = suggestedCountryNames([
        'Malta',
        'malta',
        null,
        ' ',
        'Bonaire',
      ], language: 'en');
      expect(result.take(2), ['Bonaire', 'Malta']);
      expect(result.where((c) => c.toLowerCase() == 'malta').length, 1);
      expect(result, contains('Italy'));
    });

    test('a country used in another language is not offered again '
        '(issue #5019)', () {
      final result = suggestedCountryNames([
        'Frankreich',
        'Deutschland',
        'Schweiz/Suisse/Svizzera/Svizra',
        'Holland',
      ], language: 'en');
      expect(result.take(4), [
        'Deutschland',
        'Frankreich',
        'Holland',
        'Schweiz/Suisse/Svizzera/Svizra',
      ]);
      expect(
        result,
        isNot(
          anyOf(
            [
              'France',
              'Germany',
              'Switzerland',
              'Netherlands',
            ].map(contains).toList(),
          ),
        ),
      );
      expect(result, contains('Austria'));
    });

    test('offers every extra once, in the place-name language, sorted '
        '(issue #5019)', () {
      final german = suggestedCountryNames(['Frankreich'], language: 'de');
      expect(german.first, 'Frankreich');
      final extras = german.skip(1).toList();
      expect(extras, containsAll(['Deutschland', 'Niederlande', 'Österreich']));
      expect(
        extras,
        isNot(
          anyOf(['Frankreich', 'France', 'Germany'].map(contains).toList()),
        ),
      );
      expect(extras.toSet().length, extras.length);
      expect(extras, [...extras]..sort((a, b) => compareTextForSort(a, b)));
      // Every country the English list offers is offered in German too.
      expect(extras.length, isoCountryNames.length - 1);
    });

    test('offers the extras in every place-name language', () {
      for (final language in PlaceNameLanguage.supportedCodes) {
        final result = suggestedCountryNames(const [], language: language);
        expect(result.length, isoCountryNames.length, reason: language);
        expect(result.toSet().length, result.length, reason: language);
      }
      expect(suggestedCountryNames(const [], language: 'ja'), contains('フランス'));
    });

    test('an unknown language falls back to the English names', () {
      expect(
        suggestedCountryNames(const [], language: 'xx'),
        suggestedCountryNames(const [], language: 'en'),
      );
    });
  });

  group('isoCountryNames', () {
    test('each names one distinct country (issue #5019)', () {
      final codes = [for (final name in isoCountryNames) countryCodeFor(name)];
      expect([
        for (var i = 0; i < codes.length; i++)
          if (codes[i] == null) isoCountryNames[i],
      ], isEmpty);
      expect(codes.toSet().length, codes.length);
    });

    test('has a name for each country in every place-name language', () {
      for (final MapEntry(key: language, value: names)
          in cldrCountryDisplayNames.entries) {
        final missing = [
          for (final name in isoCountryNames)
            if (!names.containsKey(countryCodeFor(name))) name,
        ];
        expect(missing, isEmpty, reason: language);
      }
    });
  });

  group('suggestedRegions', () {
    test('scopes regions to the given country', () {
      expect(suggestedRegions(sites, 'Indonesia'), ['Bali', 'Nusa Penida']);
      expect(suggestedRegions(sites, 'Egypt'), ['Dahab']);
    });

    test('returns all distinct regions when country is empty', () {
      expect(suggestedRegions(sites, ''), ['Bali', 'Dahab', 'Nusa Penida']);
    });

    test('country match is case-insensitive', () {
      expect(suggestedRegions(sites, 'indonesia'), ['Bali', 'Nusa Penida']);
    });
  });

  group('suggestedCities', () {
    final citySites = [
      _site(
        id: '1',
        name: 'A',
        country: 'Philippines',
        region: 'Cebu',
        city: 'Cebu City',
      ),
      _site(
        id: '2',
        name: 'B',
        country: 'Philippines',
        region: 'Bohol',
        city: 'Panglao',
      ),
      _site(
        id: '3',
        name: 'C',
        country: 'Greece',
        region: 'Cyclades',
        city: 'Naxos',
      ),
    ];

    test('filters by country and region when both set', () {
      expect(suggestedCities(citySites, 'Philippines', 'Cebu'), ['Cebu City']);
    });

    test('returns all distinct cities when parent empty', () {
      expect(suggestedCities(citySites, '', ''), [
        'Cebu City',
        'Naxos',
        'Panglao',
      ]);
    });
  });

  group('suggestedIslands', () {
    final islandSites = [
      _site(id: '1', name: 'A', country: 'Philippines', island: 'Malapascua'),
      _site(id: '2', name: 'B', country: 'Greece', island: 'Santorini'),
    ];

    test('filters by country', () {
      expect(suggestedIslands(islandSites, 'Philippines'), ['Malapascua']);
    });

    test('all distinct when country empty', () {
      expect(suggestedIslands(islandSites, ''), ['Malapascua', 'Santorini']);
    });
  });

  group('suggestedBodiesOfWater', () {
    final bowSites = [
      _site(
        id: '1',
        name: 'A',
        country: 'Philippines',
        bodyOfWater: 'Visayan Sea',
      ),
      _site(id: '2', name: 'B', country: 'Australia', bodyOfWater: 'Coral Sea'),
    ];

    test('filters by country', () {
      expect(suggestedBodiesOfWater(bowSites, 'Australia'), ['Coral Sea']);
    });

    test('all distinct when country empty', () {
      expect(suggestedBodiesOfWater(bowSites, ''), [
        'Coral Sea',
        'Visayan Sea',
      ]);
    });
  });
}
