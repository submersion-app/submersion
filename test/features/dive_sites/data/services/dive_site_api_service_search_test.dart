import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';

/// Issue #4520: the Import Dive Site search finds countries by name in any
/// language, and lists no site only because the query contains the first
/// word of its name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExternalDiveSite site(String id, String name, {String? country}) =>
      ExternalDiveSite(
        externalId: id,
        name: name,
        country: country,
        source: 'test',
      );

  final sites = [
    site('th', 'Sail Rock', country: 'ประเทศไทย'),
    site('eg', 'Ras Mohammed', country: 'مصر'),
    site('ch', 'Lac Léman', country: 'Schweiz/Suisse/Svizzera/Svizra'),
    site('de', 'Kreidesee', country: 'DE'),
    site('co', 'La source', country: 'Colombia'),
    site('bz', 'Blue Hole', country: 'Belize'),
    site('id', 'Blue Fish Wall', country: 'Indonesia'),
  ];

  Future<List<String>> ids(Future<DiveSiteSearchResult> search) async =>
      (await search).sites.map((s) => s.externalId).toList();

  late DiveSiteApiService service;
  setUp(() => service = DiveSiteApiService(sites: sites));

  group('searchSites', () {
    test('finds a country stored in its own language by its English '
        'name', () async {
      expect(await ids(service.searchSites('Thailand')), ['th']);
      expect(await ids(service.searchSites('Egypt')), ['eg']);
    });

    test('finds a country by its name in the app language', () async {
      expect(await ids(service.searchSites('Thaïlande')), ['th']);
      expect(await ids(service.searchSites('Égypte')), ['eg']);
    });

    test('finds a country while its name is still being typed', () async {
      expect(await ids(service.searchSites('thai')), ['th']);
    });

    test('reads a country stored under several names', () async {
      expect(await ids(service.searchSites('Switzerland')), ['ch']);
    });

    test('reads a country stored as a code', () async {
      expect(await ids(service.searchSites('Germany')), ['de']);
    });

    test('lists no site only because the query holds its first word', () async {
      // "Thailand" contains "la", "Blue Hole" contains "blue".
      expect(await ids(service.searchSites('Thailand')), isNot(contains('co')));
      expect(await ids(service.searchSites('Blue Hole')), ['bz']);
    });

    test('still matches part of a site name', () async {
      expect(await ids(service.searchSites('hole')), ['bz']);
      expect(await ids(service.searchSites('blue')), ['bz', 'id']);
    });

    test('a site with no country is found by name only', () async {
      final noCountry = DiveSiteApiService(sites: [site('x', 'Thai Wall')]);
      expect(await ids(noCountry.searchSites('thai')), ['x']);
      expect(await ids(noCountry.searchSites('Thailand')), isEmpty);
    });
  });

  test('searchByCountry finds a country stored in its own language', () async {
    expect(await ids(service.searchByCountry('Egypt')), ['eg']);
  });

  group('country code', () {
    test('is read from a name in any language, a code, or several '
        'names', () {
      final codes = {for (final s in sites) s.externalId: s.countryCode};
      expect(codes, {
        'th': 'TH',
        'eg': 'EG',
        'ch': 'CH',
        'de': 'DE',
        'co': 'CO',
        'bz': 'BZ',
        'id': 'ID',
      });
    });

    test('is null when the names disagree or name no country', () {
      expect(site('a', 'A', country: 'France / Italia').countryCode, isNull);
      expect(site('b', 'B', country: 'Atlantis').countryCode, isNull);
      expect(site('c', 'C').countryCode, isNull);
    });

    test('is carried onto an imported site', () {
      expect(sites[2].toDiveSite().countryCode, 'CH');
    });
  });

  group('built-in data', () {
    // The queries from issue #4520, run over the shipped sites.
    for (final (query, code) in [
      ('Thailand', 'TH'),
      ('Egypt', 'EG'),
      ('Germany', 'DE'),
      ('Switzerland', 'CH'),
      ('Maldives', 'MV'),
      ('Greece', 'GR'),
      ('Spain', 'ES'),
      ('Italy', 'IT'),
    ]) {
      test('"$query" lists only sites in that country', () async {
        final found = (await DiveSiteApiService().searchSites(query)).sites;
        expect(found, isNotEmpty);
        expect(
          found.where((s) => s.countryCode != code).map((s) => s.name),
          isEmpty,
        );
      });
    }
  });
}
