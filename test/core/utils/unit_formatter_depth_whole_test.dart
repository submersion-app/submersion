import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Long vertical distances (issue #4569) in whole display units with grouped
/// digits, like altitudes.
void main() {
  const metric = UnitFormatter(AppSettings(depthUnit: DepthUnit.meters));
  const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

  late String? previousLocale;
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  test('metres, grouped', () {
    expect(metric.formatDepthWhole(6380), '6,380 m');
    expect(metric.formatDepthWhole(100000), '100,000 m');
  });

  test('feet, converted before rounding', () {
    // 6,380 x 3.28084 = 20,931.8.
    expect(imperial.formatDepthWhole(6380), '20,932 ft');
  });

  test('rounds to the whole unit', () {
    expect(metric.formatDepthWhole(0.4), '0 m');
    expect(metric.formatDepthWhole(12.5), '13 m');
  });

  test('a distance still to go rounds up, so it never reads 0', () {
    expect(metric.formatDepthWhole(0.3, roundUp: true), '1 m');
    expect(metric.formatDepthWhole(580.2, roundUp: true), '581 m');
    expect(metric.formatDepthWhole(581, roundUp: true), '581 m');
    // 100 m = 328.08 ft.
    expect(imperial.formatDepthWhole(100, roundUp: true), '329 ft');
  });

  test('a tiny distance still to go reads 1, not 0', () {
    // A summed total can land a hair below a landmark.
    expect(metric.formatDepthWhole(1e-10, roundUp: true), '1 m');
    expect(
      metric.formatDepthWhole(8849 - 8848.9999999999, roundUp: true),
      '1 m',
    );
  });

  test('null renders a placeholder', () {
    expect(metric.formatDepthWhole(null), '--');
  });

  test('groups in the active locale', () {
    Intl.defaultLocale = 'de';
    expect(metric.formatDepthWhole(6380), '6.380 m');
  });
}
