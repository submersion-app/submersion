import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/lv95_transform.dart';

void main() {
  group('Lv95Transform', () {
    const swissPoints = [
      (name: 'Bern', lat: 46.9480, lon: 7.4474),
      (name: 'Zürich', lat: 47.3769, lon: 8.5417),
      (name: 'Genève', lat: 46.2044, lon: 6.1432),
      (name: 'Lugano', lat: 46.0037, lon: 8.9511),
    ];

    for (final p in swissPoints) {
      test('${p.name}: WGS84 -> LV95 lands within the Swiss extent', () {
        final lv95 = Lv95Transform.fromWgs84(p.lat, p.lon);
        // LV95 covers roughly E 2'480'000-2'840'000, N 1'070'000-1'300'000.
        expect(lv95.easting, inInclusiveRange(2480000, 2840000));
        expect(lv95.northing, inInclusiveRange(1070000, 1300000));
      });

      test('${p.name}: WGS84 -> LV95 -> WGS84 round-trips within a few m', () {
        final lv95 = Lv95Transform.fromWgs84(p.lat, p.lon);
        final back = Lv95Transform.toWgs84(lv95.easting, lv95.northing);
        // The forward and reverse formulas are independent ~1 m-accuracy
        // approximations, so a round trip can compound to a few meters;
        // 3e-5 deg is about 3 m at these latitudes.
        expect(back.latitude, closeTo(p.lat, 3e-5));
        expect(back.longitude, closeTo(p.lon, 3e-5));
      });
    }

    test('LV95 -> WGS84 -> LV95 round-trips within ~1 m', () {
      const easting = 2683000.0;
      const northing = 1247000.0;
      final wgs84 = Lv95Transform.toWgs84(easting, northing);
      final back = Lv95Transform.fromWgs84(wgs84.latitude, wgs84.longitude);
      expect(back.easting, closeTo(easting, 1.0));
      expect(back.northing, closeTo(northing, 1.0));
    });
  });
}
