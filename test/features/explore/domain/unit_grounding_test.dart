import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/domain/unit_grounding.dart';

void main() {
  const metric = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );
  const imperial = (
    depth: DepthUnit.feet,
    temperature: TemperatureUnit.fahrenheit,
    pressure: PressureUnit.psi,
  );

  test('an explicit unit wins over the diver preference', () {
    expect(
      groundToMetric(20, ClauseUnit.m, FieldDimension.depth, imperial),
      20,
    );
    expect(
      groundToMetric(66, ClauseUnit.ft, FieldDimension.depth, metric),
      closeTo(20.1, 0.05),
    );
    expect(
      groundToMetric(50, ClauseUnit.f, FieldDimension.temperature, metric),
      10,
    );
    expect(
      groundToMetric(3000, ClauseUnit.psi, FieldDimension.pressure, metric),
      closeTo(206.8, 0.1),
    );
  });

  test('a bare number takes the diver preference for the dimension', () {
    expect(groundToMetric(20, null, FieldDimension.depth, metric), 20);
    expect(
      groundToMetric(20, null, FieldDimension.depth, imperial),
      closeTo(6.1, 0.01),
    );
    expect(
      groundToMetric(60, null, FieldDimension.temperature, imperial),
      closeTo(15.56, 0.01),
    );
    expect(groundToMetric(200, null, FieldDimension.pressure, metric), 200);
  });

  test('dimensionless fields ignore any unit', () {
    expect(groundToMetric(4, ClauseUnit.m, FieldDimension.count, metric), 4);
    expect(
      groundToMetric(45, ClauseUnit.f, FieldDimension.minutes, imperial),
      45,
    );
    expect(groundToMetric(32, null, FieldDimension.percent, imperial), 32);
  });

  test('a unit fits only a field measured in its kind', () {
    expect(unitFits(FieldDimension.depth, ClauseUnit.ft), isTrue);
    expect(unitFits(FieldDimension.depth, ClauseUnit.c), isFalse);
    expect(unitFits(FieldDimension.temperature, ClauseUnit.f), isTrue);
    expect(unitFits(FieldDimension.temperature, ClauseUnit.m), isFalse);
    expect(unitFits(FieldDimension.pressure, ClauseUnit.psi), isTrue);
    expect(unitFits(FieldDimension.pressure, ClauseUnit.min), isFalse);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.bar), isTrue);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.psiMin), isTrue);
    expect(unitFits(FieldDimension.pressureRate, ClauseUnit.lMin), isFalse);
    expect(unitFits(FieldDimension.minutes, ClauseUnit.min), isTrue);
    expect(unitFits(FieldDimension.minutes, ClauseUnit.bar), isFalse);
    // No unit always fits; a unitless field takes what it is given.
    expect(unitFits(FieldDimension.depth, null), isTrue);
    expect(unitFits(FieldDimension.count, ClauseUnit.m), isTrue);
    expect(unitFits(FieldDimension.none, ClauseUnit.c), isTrue);
    expect(unitFits(FieldDimension.percent, ClauseUnit.ft), isTrue);
  });

  test('a SAC unit said without per minute is per minute', () {
    expect(rateUnitSaid(ClauseUnit.bar, metric), PressureUnit.bar);
    expect(rateUnitSaid(ClauseUnit.barMin, metric), PressureUnit.bar);
    expect(rateUnitSaid(ClauseUnit.psi, metric), PressureUnit.psi);
    expect(rateUnitSaid(ClauseUnit.psiMin, metric), PressureUnit.psi);
    expect(rateUnitSaid(null, metric), PressureUnit.bar);
    expect(
      groundToMetric(1.5, ClauseUnit.bar, FieldDimension.pressureRate, metric),
      1.5,
    );
  });
}
