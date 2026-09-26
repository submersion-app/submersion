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

  test('an explicit unit wins over the preference', () {
    expect(
      groundToStorage(30, QueryUnit.m, FieldDimension.depth, imperial),
      30,
    );
  });

  test('a bare number takes the preference for its dimension', () {
    expect(
      groundToStorage(100, null, FieldDimension.depth, imperial),
      closeTo(30.48, 0.001),
    );
    expect(
      groundToStorage(50, null, FieldDimension.temperature, imperial),
      closeTo(10, 0.001),
    );
    expect(
      groundToStorage(10, null, FieldDimension.weight, imperial),
      closeTo(4.5359, 0.001),
    );
  });

  test('a unitless dimension is never converted', () {
    expect(groundToStorage(32, null, FieldDimension.percent, imperial), 32);
    expect(
      groundToStorage(32, QueryUnit.ft, FieldDimension.percent, imperial),
      32,
    );
  });

  test('display converts back to the typed unit or the preference', () {
    final (v1, u1) = storageToDisplay(
      30.48,
      QueryUnit.ft,
      FieldDimension.depth,
      kMetricPrefs,
    );
    expect(v1, closeTo(100, 0.001));
    expect(u1, QueryUnit.ft);
    final (v2, u2) = storageToDisplay(30, null, FieldDimension.depth, imperial);
    expect(v2, closeTo(98.425, 0.001));
    expect(u2, isNull);
  });

  test('every dimension grounds and displays in both unit systems', () {
    const cases = <(FieldDimension, QueryUnit, QueryUnit, double, double)>[
      // dimension, metric unit, imperial unit, one imperial, in storage
      (FieldDimension.depth, QueryUnit.m, QueryUnit.ft, 100, 30.48),
      (FieldDimension.temperature, QueryUnit.c, QueryUnit.f, 50, 10),
      (FieldDimension.pressure, QueryUnit.bar, QueryUnit.psi, 145.038, 10),
      (FieldDimension.weight, QueryUnit.kg, QueryUnit.lb, 22.0462, 10),
      (FieldDimension.volume, QueryUnit.l, QueryUnit.cuft, 0.353147, 10),
    ];
    for (final (dim, metric, imp, typedImperial, storage) in cases) {
      expect(dimensionOfUnit(metric), dim);
      expect(dimensionOfUnit(imp), dim);
      // Explicit imperial suffix grounds to storage whatever the prefs say.
      expect(
        groundToStorage(typedImperial, imp, dim, kMetricPrefs),
        closeTo(storage, 0.01),
        reason: '$dim ground',
      );
      // A metric suffix is the identity.
      expect(groundToStorage(storage, metric, dim, imperial), storage);
      // Bare numbers take the preference; display echoes the typed unit.
      expect(
        groundToStorage(typedImperial, null, dim, imperial),
        closeTo(storage, 0.01),
        reason: '$dim bare imperial',
      );
      final (shown, unit) = storageToDisplay(storage, imp, dim, kMetricPrefs);
      expect(shown, closeTo(typedImperial, 0.01), reason: '$dim display');
      expect(unit, imp);
      final (bare, noUnit) = storageToDisplay(storage, null, dim, imperial);
      expect(bare, closeTo(typedImperial, 0.01), reason: '$dim bare display');
      expect(noUnit, isNull);
    }
    expect(dimensionOfUnit(QueryUnit.min), FieldDimension.minutes);
    expect(
      storageToDisplay(12, QueryUnit.min, FieldDimension.minutes, imperial),
      (12.0, null),
    );
  });
}
