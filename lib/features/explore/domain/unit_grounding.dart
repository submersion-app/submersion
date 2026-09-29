import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// The diver's unit choices the compiler needs; built from AppSettings by the
/// provider so this file stays free of the settings layer.
typedef UnitPrefs = ({
  DepthUnit depth,
  TemperatureUnit temperature,
  PressureUnit pressure,
});

/// Converts a clause value to storage units (metres, celsius, bar).
///
/// An explicit [unit] wins. A bare number on a dimensioned field takes the
/// diver's unit for that dimension. Dimensionless fields return the value
/// unchanged whatever [unit] says.
double groundToMetric(
  num value,
  ClauseUnit? unit,
  FieldDimension dimension,
  UnitPrefs prefs,
) {
  final v = value.toDouble();
  switch (dimension) {
    case FieldDimension.depth:
      final from = switch (unit) {
        ClauseUnit.m => DepthUnit.meters,
        ClauseUnit.ft => DepthUnit.feet,
        _ => prefs.depth,
      };
      return from.convert(v, DepthUnit.meters);
    case FieldDimension.temperature:
      final from = switch (unit) {
        ClauseUnit.c => TemperatureUnit.celsius,
        ClauseUnit.f => TemperatureUnit.fahrenheit,
        _ => prefs.temperature,
      };
      return from.convert(v, TemperatureUnit.celsius);
    case FieldDimension.pressure:
      final from = switch (unit) {
        ClauseUnit.bar => PressureUnit.bar,
        ClauseUnit.psi => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return from.convert(v, PressureUnit.bar);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return v;
  }
}
