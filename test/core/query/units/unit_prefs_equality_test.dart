import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';

void main() {
  const imperial = UnitPrefs(
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
    weight: WeightUnit.pounds,
    volume: VolumeUnit.cubicFeet,
  );

  test('two prefs with the same units are equal', () {
    expect(
      const UnitPrefs(
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
        weight: WeightUnit.kilograms,
        volume: VolumeUnit.liters,
      ),
      equals(kMetricPrefs),
    );
    expect(imperial, isNot(equals(kMetricPrefs)));
    expect(imperial.hashCode, isNot(kMetricPrefs.hashCode));
  });

  test('unitForDimension names the unit the diver sees', () {
    expect(unitForDimension(FieldDimension.depth, kMetricPrefs), QueryUnit.m);
    expect(unitForDimension(FieldDimension.depth, imperial), QueryUnit.ft);
    expect(unitForDimension(FieldDimension.temperature, imperial), QueryUnit.f);
    expect(unitForDimension(FieldDimension.pressure, imperial), QueryUnit.psi);
    expect(unitForDimension(FieldDimension.weight, imperial), QueryUnit.lb);
    expect(unitForDimension(FieldDimension.volume, imperial), QueryUnit.cuft);
    expect(unitForDimension(FieldDimension.minutes, imperial), QueryUnit.min);
    expect(unitForDimension(FieldDimension.percent, imperial), isNull);
    expect(unitForDimension(FieldDimension.count, imperial), isNull);
    expect(unitForDimension(FieldDimension.none, imperial), isNull);
  });

  test('a value grounded in the display unit round-trips', () {
    final unit = unitForDimension(FieldDimension.depth, imperial);
    final storage = groundToStorage(100, unit, FieldDimension.depth, imperial);
    final (shown, _) = storageToDisplay(
      storage,
      unit,
      FieldDimension.depth,
      imperial,
    );
    expect(storage, closeTo(30.48, 0.001));
    expect(shown, closeTo(100, 0.0001));
  });
}
