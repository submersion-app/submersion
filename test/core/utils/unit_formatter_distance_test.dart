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
}
