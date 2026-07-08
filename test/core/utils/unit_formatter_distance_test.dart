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
    const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    test('metric scales meters to km', () {
      expect(metric.formatGeoDistance(120), '120 m');
      expect(metric.formatGeoDistance(999), '999 m');
      expect(metric.formatGeoDistance(1000), '1.0 km');
      expect(metric.formatGeoDistance(5560), '5.6 km');
      expect(metric.formatGeoDistance(23400), '23 km');
    });

    test('imperial scales feet to miles', () {
      expect(imperial.formatGeoDistance(120), '394 ft');
      expect(imperial.formatGeoDistance(1000), '3281 ft');
      expect(imperial.formatGeoDistance(3218.688), '2.0 mi');
      expect(imperial.formatGeoDistance(160934), '100 mi');
    });
  });
}
