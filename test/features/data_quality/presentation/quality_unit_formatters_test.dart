import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_unit_formatters.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // formatRmv localises the decimal separator from the process-global
  // Intl.defaultLocale, so pin English for the dot-separated expectations.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('qualityUnitFormattersFor sac (#1823)', () {
    test('metric renders an RMV in L/min at 1 decimal', () {
      final fmt = qualityUnitFormattersFor(const UnitFormatter(AppSettings()));

      expect(fmt.sac(16.84), '16.8 L/min');
    });

    test('imperial renders an RMV in cuft/min at 2 decimals', () {
      final fmt = qualityUnitFormattersFor(
        const UnitFormatter(AppSettings(volumeUnit: VolumeUnit.cubicFeet)),
      );

      // 16.84 L/min is 0.5947 cuft/min; at 1 decimal it read "0.6", which
      // hides most of the spread between typical imperial RMVs.
      expect(fmt.sac(16.84), '0.59 cuft/min');
    });
  });
}
