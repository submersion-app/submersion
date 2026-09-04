import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';

void main() {
  const found = PlaceLookup(
    country: 'Switzerland',
    region: 'Lucerne',
    locality: 'Weggis',
    bodyOfWater: 'Lake Lucerne',
  );

  test('fills every empty field', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(),
      found: found,
      overwrite: false,
    );
    expect(merged, isNotNull);
    expect(merged!.country, 'Switzerland');
    expect(merged.region, 'Lucerne');
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('leaves filled fields alone and returns only the empty ones', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(country: 'Schweiz', region: 'Luzern'),
      found: found,
      overwrite: false,
    );
    expect(merged!.country, isNull);
    expect(merged.region, isNull);
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('treats whitespace-only as empty', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(city: '   '),
      found: const PlaceLookup(locality: 'Weggis'),
      overwrite: false,
    );
    expect(merged!.city, 'Weggis');
  });

  test('ignores blank found values', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup(country: '', locality: ' '),
      overwrite: false,
    );
    expect(merged, isNull);
  });

  test('returns null when every field is already filled', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
      ),
      found: found,
      overwrite: false,
    );
    expect(merged, isNull);
  });

  test('returns null when the lookup found nothing', () {
    final merged = mergeLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup.empty(),
      overwrite: false,
    );
    expect(merged, isNull);
  });

  test('ofSite reads the four location columns', () {
    const site = DiveSite(
      id: 's',
      name: 'n',
      country: 'Switzerland',
      city: 'Weggis',
    );
    final details = SiteLocationDetails.ofSite(site);
    expect(details.country, 'Switzerland');
    expect(details.region, isNull);
    expect(details.city, 'Weggis');
    expect(details.bodyOfWater, isNull);
  });

  group('overwrite', () {
    test('replaces a filled field with the newly found value', () {
      final merged = mergeLocationDetails(
        current: const SiteLocationDetails(
          country: 'Schweiz',
          region: 'Luzern',
        ),
        found: found,
        overwrite: true,
      );
      expect(merged!.country, 'Switzerland');
      expect(merged.region, 'Lucerne');
      expect(merged.city, 'Weggis');
      expect(merged.bodyOfWater, 'Lake Lucerne');
    });

    test('leaves a field alone when the found value already matches', () {
      final merged = mergeLocationDetails(
        current: const SiteLocationDetails(country: 'Switzerland'),
        found: const PlaceLookup(country: 'Switzerland', locality: 'Weggis'),
        overwrite: true,
      );
      expect(merged!.country, isNull, reason: 'no pointless write');
      expect(merged.city, 'Weggis');
    });

    test('ignores surrounding whitespace when comparing', () {
      final merged = mergeLocationDetails(
        current: const SiteLocationDetails(country: ' Switzerland '),
        found: const PlaceLookup(country: 'Switzerland'),
        overwrite: true,
      );
      expect(merged, isNull);
    });

    test('never clears a field the lookup did not find', () {
      final merged = mergeLocationDetails(
        current: const SiteLocationDetails(
          country: 'Schweiz',
          region: 'Luzern',
          city: 'Weggis',
          bodyOfWater: 'Vierwaldstattersee',
        ),
        found: const PlaceLookup(country: 'Switzerland'),
        overwrite: true,
      );
      expect(merged!.country, 'Switzerland');
      expect(merged.region, isNull);
      expect(merged.city, isNull);
      expect(merged.bodyOfWater, isNull);
    });

    test('returns null when every field already matches', () {
      final merged = mergeLocationDetails(
        current: const SiteLocationDetails(
          country: 'Switzerland',
          region: 'Lucerne',
          city: 'Weggis',
          bodyOfWater: 'Lake Lucerne',
        ),
        found: found,
        overwrite: true,
      );
      expect(merged, isNull);
    });
  });
}
