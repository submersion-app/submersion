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
}
