import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

/// Issue #4398: the step a typed number is shown at, in storage units.
void main() {
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  test('a tenth of the typed unit, in storage units', () {
    expect(
      displayGrain(27.1, QueryUnit.ft, FieldDimension.depth, kMetricPrefs),
      closeTo(0.1 / 3.28084, 1e-12),
    );
    expect(
      displayGrain(12, QueryUnit.kg, FieldDimension.weight, imperial),
      closeTo(0.1, 1e-12),
    );
  });

  test('a bare number takes the diver unit', () {
    expect(
      displayGrain(12, null, FieldDimension.weight, imperial),
      closeTo(0.1 / 2.20462, 1e-12),
    );
    expect(
      displayGrain(8.3, null, FieldDimension.depth, kMetricPrefs),
      closeTo(0.1, 1e-12),
    );
  });

  test('an offset unit converts only the step', () {
    // 0.1 F is 0.0556 C wide, whatever the 32 F offset does to the value.
    expect(
      displayGrain(68, null, FieldDimension.temperature, imperial),
      closeTo(0.1 * 5 / 9, 1e-12),
    );
  });

  test('each dimension rounds as the app shows it', () {
    expect(
      displayGrain(200, QueryUnit.bar, FieldDimension.pressure, imperial),
      closeTo(1, 1e-12),
    );
    expect(
      displayGrain(3000, null, FieldDimension.pressure, imperial),
      closeTo(1 / 14.5038, 1e-6),
    );
    expect(
      displayGrain(
        1.5,
        QueryUnit.barMin,
        FieldDimension.pressureRate,
        imperial,
      ),
      closeTo(0.1, 1e-12),
    );
    expect(
      displayGrain(20, null, FieldDimension.pressureRate, imperial),
      closeTo(1 / 14.5038, 1e-6),
    );
    expect(
      displayGrain(32, null, FieldDimension.percent, imperial),
      closeTo(0.1, 1e-12),
    );
  });

  test('a number finer than the display compares exactly', () {
    expect(displayGrain(27.15, null, FieldDimension.depth, imperial), isNull);
    expect(
      displayGrain(200.5, QueryUnit.bar, FieldDimension.pressure, imperial),
      isNull,
    );
  });

  test('whole-number dimensions have no grain', () {
    for (final d in [
      FieldDimension.minutes,
      FieldDimension.count,
      FieldDimension.none,
    ]) {
      expect(displayGrain(12, null, d, imperial), isNull, reason: '$d');
    }
  });

  test('a negative number on the grid has one too', () {
    expect(
      displayGrain(-1.5, QueryUnit.c, FieldDimension.temperature, imperial),
      closeTo(0.1, 1e-12),
    );
  });
}
