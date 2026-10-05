import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/new_site_seed.dart';

void main() {
  group('NewSiteSeed.fromRouteExtra', () {
    test('passes a NewSiteSeed through unchanged', () {
      const seed = NewSiteSeed(location: GeoPoint(1, 2), name: 'Blue Hole');
      expect(NewSiteSeed.fromRouteExtra(seed), seed);
    });

    test('reads a bare GeoPoint as a location-only seed', () {
      expect(
        NewSiteSeed.fromRouteExtra(const GeoPoint(1, 2)),
        const NewSiteSeed(location: GeoPoint(1, 2)),
      );
    });

    test('reads null or an unknown extra as an empty seed', () {
      expect(NewSiteSeed.fromRouteExtra(null), const NewSiteSeed());
      expect(NewSiteSeed.fromRouteExtra('nonsense'), const NewSiteSeed());
    });
  });

  test('copyWith replaces only the given fields', () {
    const seed = NewSiteSeed(location: GeoPoint(1, 2), name: 'Blue Hole');
    expect(
      seed.copyWith(name: 'Channel'),
      const NewSiteSeed(location: GeoPoint(1, 2), name: 'Channel'),
    );
    expect(
      seed.copyWith(location: const GeoPoint(3, 4)),
      const NewSiteSeed(location: GeoPoint(3, 4), name: 'Blue Hole'),
    );
  });
}
