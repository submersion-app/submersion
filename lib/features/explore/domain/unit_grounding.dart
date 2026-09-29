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
    case FieldDimension.pressureRate:
      return rateUnitSaid(unit, prefs).convert(v, PressureUnit.bar);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return v;
  }
}

/// The pressure unit a SAC was said in. Divers often drop "per minute", so
/// a plain bar or psi on a rate means bar/min or psi/min; no unit means the
/// diver's own.
PressureUnit rateUnitSaid(ClauseUnit? unit, UnitPrefs prefs) => switch (unit) {
  ClauseUnit.bar || ClauseUnit.barMin => PressureUnit.bar,
  ClauseUnit.psi || ClauseUnit.psiMin => PressureUnit.psi,
  _ => prefs.pressure,
};

/// Whether [unit] can be read on a field of [dimension]. A unit of another
/// kind (20 c on a depth, l/min on a SAC, which is RMV) would otherwise be
/// ignored and the number read in the diver's own unit, searching for the
/// wrong thing without saying so. No unit always fits, and a unitless field
/// takes whatever it is given, as it always has.
bool unitFits(FieldDimension dimension, ClauseUnit? unit) {
  if (unit == null) return true;
  return switch (dimension) {
    FieldDimension.depth => unit == ClauseUnit.m || unit == ClauseUnit.ft,
    FieldDimension.temperature => unit == ClauseUnit.c || unit == ClauseUnit.f,
    FieldDimension.pressure => unit == ClauseUnit.bar || unit == ClauseUnit.psi,
    // Divers drop "per minute": a plain bar or psi on a rate fits.
    FieldDimension.pressureRate =>
      unit == ClauseUnit.bar ||
          unit == ClauseUnit.psi ||
          unit == ClauseUnit.barMin ||
          unit == ClauseUnit.psiMin,
    FieldDimension.minutes => unit == ClauseUnit.min,
    FieldDimension.percent ||
    FieldDimension.count ||
    FieldDimension.none => true,
  };
}
