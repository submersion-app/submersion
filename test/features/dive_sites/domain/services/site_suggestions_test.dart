import 'package:flutter_test/flutter_test.dart';
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
      final result = suggestedCountries(sites);
      expect(result.take(2), ['Egypt', 'Indonesia']);
      // ISO extras follow and exclude already-used countries.
      expect(result, contains('Mexico'));
      expect(result.where((c) => c == 'Egypt').length, 1);
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
      _site(
        id: '2',
        name: 'B',
        country: 'Australia',
        bodyOfWater: 'Coral Sea',
      ),
    ];

    test('filters by country', () {
      expect(suggestedBodiesOfWater(bowSites, 'Australia'), ['Coral Sea']);
    });

    test('all distinct when country empty', () {
      expect(suggestedBodiesOfWater(bowSites, ''), ['Coral Sea', 'Visayan Sea']);
    });
  });
}
