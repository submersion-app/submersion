import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/geography/country_code.dart';
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
    await sites.updateSite(site.copyWith(countryCode: 'KP'));
    expect((await sites.getSiteById('s1'))!.countryCode, 'KP');

    await sites.updateSite(
      (await sites.getSiteById('s1'))!.copyWith(clearCountry: true),
    );
    expect((await sites.getSiteById('s1'))!.countryCode, isNull);
  });

  group('the repository keeps the code in step with the text', () {
    test('a changed country with a carried-over code is re-read', () async {
      await sites.createSite(
        const DiveSite(
          id: 's2',
          name: 'Reef',
          country: 'France',
          countryCode: 'FR',
        ),
      );
      final site = (await sites.getSiteById('s2'))!;

      // A writer that changes only the text (copyWith keeps the old code).
      await sites.updateSite(site.copyWith(country: 'Spain'));
      expect((await sites.getSiteById('s2'))!.countryCode, 'ES');

      await sites.updateSite(
        (await sites.getSiteById('s2'))!.copyWith(country: 'Atlantis'),
      );
      expect((await sites.getSiteById('s2'))!.countryCode, isNull);
    });

    test('a code set together with the text is kept', () async {
      await sites.createSite(
        const DiveSite(id: 's3', name: 'Reef', country: 'France'),
      );
      final site = (await sites.getSiteById('s3'))!;

      await sites.updateSite(
        site.copyWith(country: 'Korea', countryCode: 'KR'),
      );
      expect((await sites.getSiteById('s3'))!.countryCode, 'KR');
    });

    test('an unchanged country keeps its code', () async {
      await sites.createSite(
        const DiveSite(
          id: 's4',
          name: 'Reef',
          country: 'Korea',
          countryCode: 'KR',
        ),
      );
      final site = (await sites.getSiteById('s4'))!;

      await sites.updateSite(site.copyWith(name: 'Munseom'));
      expect((await sites.getSiteById('s4'))!.countryCode, 'KR');
    });

    test('a writer that drops the code keeps the stored one', () async {
      await sites.createSite(
        const DiveSite(
          id: 's6',
          name: 'Reef',
          country: 'Korea',
          countryCode: 'KR',
        ),
      );
      // A full rebuild that never heard of countryCode (same text, no code).
      await sites.updateSite(
        const DiveSite(id: 's6', name: 'Munseom', country: 'Korea'),
      );
      expect((await sites.getSiteById('s6'))!.countryCode, 'KR');
    });

    test('a new site without a code gets one from its text', () async {
      await sites.createSite(
        const DiveSite(id: 's5', name: 'Reef', country: 'Mexico'),
      );
      expect((await sites.getSiteById('s5'))!.countryCode, 'MX');
    });
  });

  group('siteFlagCode', () {
    test('prefers the stored code', () {
      const site = DiveSite(
        id: 's',
        name: 'n',
        country: 'Korea',
        countryCode: 'KR',
      );
      expect(siteFlagCode(country: site.country, code: site.countryCode), 'KR');
    });

    test('falls back to reading the country text', () {
      const site = DiveSite(id: 's', name: 'n', country: 'Mexico');
      expect(siteFlagCode(country: site.country, code: site.countryCode), 'MX');
    });

    test('is null when neither names a country', () {
      const site = DiveSite(id: 's', name: 'n', country: 'Atlantis');
      expect(
        siteFlagCode(country: site.country, code: site.countryCode),
        isNull,
      );
    });
  });

  test('clearing the country clears its code too', () {
    const site = DiveSite(
      id: 's',
      name: 'n',
      country: 'Korea',
      countryCode: 'KR',
    );
    final cleared = site.copyWith(clearCountry: true);
    expect(cleared.country, isNull);
    expect(cleared.countryCode, isNull);
  });

  test('copyWith keeps, replaces and clears the code', () {
    const site = DiveSite(id: 's', name: 'n', countryCode: 'MX');
    expect(site.copyWith(name: 'm').countryCode, 'MX');
    expect(site.copyWith(countryCode: 'BZ').countryCode, 'BZ');
    expect(site.copyWith(clearCountryCode: true).countryCode, isNull);
    expect(site, isNot(site.copyWith(countryCode: 'BZ')));
  });
}
