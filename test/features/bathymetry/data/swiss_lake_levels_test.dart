import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_lake_levels.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('findSwissLake', () {
    test('matches a coordinate inside Zürichsee', () {
      final lake = findSwissLake(const GeoPoint(47.25, 8.65));
      expect(lake, isNotNull);
      expect(lake!.name, contains('Zürichsee'));
      expect(lake.meanLevelMeters, greaterThan(0));
    });

    test('matches a coordinate inside Genfersee', () {
      final lake = findSwissLake(const GeoPoint(46.40, 6.60));
      expect(lake, isNotNull);
      expect(lake!.name, contains('Genfersee'));
    });

    test('returns null for a coordinate far outside Switzerland', () {
      expect(findSwissLake(const GeoPoint(12.16, -68.29)), isNull);
    });

    test('returns null for dry Swiss land between lakes', () {
      // A point in the Bernese Alps, nowhere near a mapped lake bounding box.
      expect(findSwissLake(const GeoPoint(46.55, 7.98)), isNull);
    });

    test('every lake has a plausible mean level and a non-inverted bbox', () {
      for (final lake in swissLakeLevels) {
        expect(
          lake.meanLevelMeters,
          inInclusiveRange(190.0, 800.0),
          reason: lake.name,
        );
        expect(lake.minLat, lessThan(lake.maxLat), reason: lake.name);
        expect(lake.minLon, lessThan(lake.maxLon), reason: lake.name);
      }
    });
  });
}
