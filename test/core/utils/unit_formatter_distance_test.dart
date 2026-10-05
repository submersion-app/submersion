import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('formatDistance respects depth unit (meters/feet)', () {
    const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
    expect(metric.formatDistance(120), '120m');

    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    expect(imperial.formatDistance(120), '394ft');
  });

  group('formatGeoDistance', () {
    const km = UnitFormatter(AppSettings());
    const mi = UnitFormatter(AppSettings(distanceUnit: DistanceUnit.miles));

    test('kilometres scale metres to km', () {
      expect(km.formatGeoDistance(120), '120 m');
      expect(km.formatGeoDistance(999), '999 m');
      expect(km.formatGeoDistance(1000), '1.0 km');
      expect(km.formatGeoDistance(5560), '5.6 km');
      expect(km.formatGeoDistance(23400), '23 km');
    });

    test('miles scale feet to miles', () {
      expect(mi.formatGeoDistance(120), '394 ft');
      expect(mi.formatGeoDistance(1000), '3281 ft');
      expect(mi.formatGeoDistance(3218.688), '2.0 mi');
      expect(mi.formatGeoDistance(160934), '100 mi');
    });

    // Issue #2030: the distance unit, not the depth unit, decides.
    test('feet for depth with kilometres for distance reads km', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.feet,
          distanceUnit: DistanceUnit.kilometers,
        ),
      );
      expect(f.formatGeoDistance(420), '420 m');
      expect(f.formatGeoDistance(5560), '5.6 km');
    });

    test('metres for depth with miles for distance reads mi', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.meters,
          distanceUnit: DistanceUnit.miles,
        ),
      );
      expect(f.formatGeoDistance(120), '394 ft');
      expect(f.formatGeoDistance(3218.688), '2.0 mi');
    });

    test('surface drift keeps the depth unit', () {
      const f = UnitFormatter(
        AppSettings(
          depthUnit: DepthUnit.meters,
          distanceUnit: DistanceUnit.miles,
        ),
      );
      expect(f.formatDistance(120), '120m');
    });
  });
}
