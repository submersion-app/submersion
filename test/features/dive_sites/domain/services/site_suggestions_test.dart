import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';

DiveSite _site({
  required String id,
  required String name,
  String? country,
  String? region,
}) {
  return DiveSite(id: id, name: name, country: country, region: region);
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
}
