import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Rule values read like the rest of the app (#3513): in the diver's
/// units and with the locale's digits.
void main() {
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  test('a plain number reads with the locale\'s decimal separator', () {
    Intl.defaultLocale = 'de';
    expect(ruleNumberLabel(metric, RuleUnit.none, 1.3), '1,3');
    expect(ruleNumberLabel(metric, RuleUnit.none, 2), '2');
  });

  test('surface pressure follows the diver\'s units', () {
    expect(ruleNumberLabel(metric, RuleUnit.millibar, 1.013), '1013 mbar');
    expect(
      ruleNumberLabel(imperial, RuleUnit.millibar, 1.013),
      contains('inHg'),
    );
  });

  test('a diluent reads as plain percentages', () {
    Intl.defaultLocale = 'de';
    expect(ruleDiluentLabel(21.0, 35.5), '21/35,5');
    expect(ruleDiluentLabel(null, 0), '-/0');
  });
}
