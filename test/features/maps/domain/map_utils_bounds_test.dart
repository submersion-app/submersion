import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

void main() {
  test('one point yields a zero-span box at that point', () {
    final bounds = boundsForPoints([const LatLng(10, 20)])!;
    expect(bounds.south, 10);
    expect(bounds.north, 10);
    expect(bounds.west, 20);
    expect(bounds.east, 20);
  });

  test('many points are padded by ten percent of each span', () {
    final bounds = boundsForPoints([const LatLng(0, 0), const LatLng(10, 20)])!;
    expect(bounds.south, closeTo(-1, 1e-9));
    expect(bounds.north, closeTo(11, 1e-9));
    expect(bounds.west, closeTo(-2, 1e-9));
    expect(bounds.east, closeTo(22, 1e-9));
  });

  test('an out-of-range point is skipped', () {
    final bounds = boundsForPoints([
      const LatLng(5, 5),
      const LatLng(6, 6),
      // latlong2 0.9 does not assert its ranges, so a bad point is easy to
      // build; flutter_map is what chokes on one, which is why we skip it.
      const LatLng(95, 200),
    ])!;
    expect(bounds.north, lessThan(90));
    expect(bounds.east, lessThan(180));
  });

  test('padding is clamped at the poles and the antimeridian', () {
    final bounds = boundsForPoints([
      const LatLng(-89, -179),
      const LatLng(89, 179),
    ])!;
    expect(bounds.south, -90);
    expect(bounds.north, 90);
    expect(bounds.west, -180);
    expect(bounds.east, 180);
  });

  test('no usable point yields null', () {
    expect(boundsForPoints(const []), isNull);
  });

  test('a non-finite point is skipped, not folded into the bounds', () {
    expect(boundsForPoints([const LatLng(double.nan, 0)]), isNull);
    final bounds = boundsForPoints([
      const LatLng(5, 5),
      const LatLng(double.nan, double.infinity),
    ])!;
    expect(bounds.south, 5);
    expect(bounds.north, 5);
    expect(bounds.west, 5);
    expect(bounds.east, 5);
  });
}
