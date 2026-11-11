import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// A site's stored ISO country code (issue #4426) survives a write and a
/// read, and the flag prefers it to reading the country text.
void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  test('create and update round-trip the code', () async {
    await sites.createSite(
      const DiveSite(
        id: 's1',
        name: 'Reef',
        country: 'Korea',
        countryCode: 'KR',
      ),
    );
    expect((await sites.getSiteById('s1'))!.countryCode, 'KR');

    final site = (await sites.getSiteById('s1'))!;
    await sites.updateSite(site.copyWith(clearCountryCode: true));
    expect((await sites.getSiteById('s1'))!.countryCode, isNull);
  });

  group('flagCountryCode', () {
    test('prefers the stored code', () {
      const site = DiveSite(
        id: 's',
        name: 'n',
        country: 'Korea',
        countryCode: 'KR',
      );
      expect(site.flagCountryCode, 'KR');
    });

    test('falls back to reading the country text', () {
      const site = DiveSite(id: 's', name: 'n', country: 'Mexico');
      expect(site.flagCountryCode, 'MX');
    });

    test('is null when neither names a country', () {
      const site = DiveSite(id: 's', name: 'n', country: 'Atlantis');
      expect(site.flagCountryCode, isNull);
    });
  });

  test('copyWith keeps, replaces and clears the code', () {
    const site = DiveSite(id: 's', name: 'n', countryCode: 'MX');
    expect(site.copyWith(name: 'm').countryCode, 'MX');
    expect(site.copyWith(countryCode: 'BZ').countryCode, 'BZ');
    expect(site.copyWith(clearCountryCode: true).countryCode, isNull);
    expect(site, isNot(site.copyWith(countryCode: 'BZ')));
  });
}
