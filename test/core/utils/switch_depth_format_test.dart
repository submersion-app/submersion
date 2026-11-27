import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/switch_depth_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  group('formatSwitchDepth (#3793)', () {
    test('a whole depth shows without a decimal', () {
      expect(formatSwitchDepth(metric, 10.0), '10m');
      expect(formatSwitchDepth(metric, 6.0), '6m');
    });

    test('a fractional depth shows one decimal', () {
      expect(formatSwitchDepth(metric, 10.5), '10.5m');
    });

    test('a depth that rounds to a whole number never shows .0', () {
      expect(formatSwitchDepth(metric, 9.96), '10m');
      expect(formatSwitchDepth(metric, 10.04), '10m');
    });

    test('a depth typed in feet reads back in whole feet', () {
      // 30 ft is 9.144 m.
      expect(formatSwitchDepth(imperial, 9.144), '30ft');
      // 10 m is 32.81 ft.
      expect(formatSwitchDepth(imperial, 10.0), '32.8ft');
    });
  });
}
