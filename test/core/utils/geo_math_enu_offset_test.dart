import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('enuOffsetMeters points due north/east correctly', () {
    const a = GeoPoint(12.16, -68.29);
    final north = enuOffsetMeters(a, const GeoPoint(12.17, -68.29));
    expect(north.north, closeTo(1110, 15)); // ~0.01 deg lat
    expect(north.east.abs(), lessThan(1));
    final east = enuOffsetMeters(a, const GeoPoint(12.16, -68.28));
    expect(east.east, closeTo(1088, 15)); // ~0.01 deg lon at 12 N
    expect(east.north.abs(), lessThan(5));
  });

  test('metersPerDegreeLongitude tracks latitude and floors at the poles', () {
    expect(metersPerDegreeLongitude(0), closeTo(111320, 1));
    expect(metersPerDegreeLongitude(60), closeTo(55660, 5));
    // cos(90) == 0: the floor keeps the scale strictly positive.
    expect(metersPerDegreeLongitude(90), greaterThan(1000));
  });

  test('enuOffsetMeters is zero for identical points', () {
    const a = GeoPoint(12.16, -68.29);
    final o = enuOffsetMeters(a, a);
    expect(o.east, 0);
    expect(o.north, 0);
  });
}
