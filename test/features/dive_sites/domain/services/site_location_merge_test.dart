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
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: found,
    );
    expect(merged, isNotNull);
    expect(merged!.country, 'Switzerland');
    expect(merged.region, 'Lucerne');
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('leaves filled fields alone and returns only the empty ones', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(country: 'Schweiz', region: 'Luzern'),
      found: found,
    );
    expect(merged!.country, isNull);
    expect(merged.region, isNull);
    expect(merged.city, 'Weggis');
    expect(merged.bodyOfWater, 'Lake Lucerne');
  });

  test('treats whitespace-only as empty', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(city: '   '),
      found: const PlaceLookup(locality: 'Weggis'),
    );
    expect(merged!.city, 'Weggis');
  });

  test('ignores blank found values', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup(country: '', locality: ' '),
    );
    expect(merged, isNull);
  });

  test('returns null when every field is already filled', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(
        country: 'a',
        region: 'b',
        city: 'c',
        bodyOfWater: 'd',
      ),
      found: found,
    );
    expect(merged, isNull);
  });

  test('returns null when the lookup found nothing', () {
    final merged = mergeMissingLocationDetails(
      current: const SiteLocationDetails(),
      found: const PlaceLookup.empty(),
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
}
