import 'package:meta/meta.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/registry/query_field.dart';

/// The diver's unit choices the parser and printer need. Built from
/// AppSettings by the provider layer so this file stays free of settings.
@immutable
class UnitPrefs {
  final DepthUnit depth;
  final TemperatureUnit temperature;
  final PressureUnit pressure;
  final WeightUnit weight;
  final VolumeUnit volume;
  const UnitPrefs({
    required this.depth,
    required this.temperature,
    required this.pressure,
    required this.weight,
    required this.volume,
  });

  @override
  bool operator ==(Object other) =>
      other is UnitPrefs &&
      other.depth == depth &&
      other.temperature == temperature &&
      other.pressure == pressure &&
      other.weight == weight &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(depth, temperature, pressure, weight, volume);
}

const kMetricPrefs = UnitPrefs(
  depth: DepthUnit.meters,
  temperature: TemperatureUnit.celsius,
  pressure: PressureUnit.bar,
  weight: WeightUnit.kilograms,
  volume: VolumeUnit.liters,
);

/// The dimension a typed unit belongs to, so `depth > 100f` is refused
/// rather than read in the diver's depth unit.
FieldDimension dimensionOfUnit(QueryUnit unit) => switch (unit) {
  QueryUnit.m || QueryUnit.ft => FieldDimension.depth,
  QueryUnit.c || QueryUnit.f => FieldDimension.temperature,
  QueryUnit.bar || QueryUnit.psi => FieldDimension.pressure,
  QueryUnit.kg || QueryUnit.lb => FieldDimension.weight,
  QueryUnit.l || QueryUnit.cuft => FieldDimension.volume,
  QueryUnit.min => FieldDimension.minutes,
};

/// The unit the diver sees for [dimension] under [prefs]: what a number
/// field's suffix shows and what a typed number without a suffix means.
/// Null for the unitless dimensions (percent, count, none).
QueryUnit? unitForDimension(FieldDimension dimension, UnitPrefs prefs) {
  switch (dimension) {
    case FieldDimension.depth:
      return prefs.depth == DepthUnit.feet ? QueryUnit.ft : QueryUnit.m;
    case FieldDimension.temperature:
      return prefs.temperature == TemperatureUnit.fahrenheit
          ? QueryUnit.f
          : QueryUnit.c;
    case FieldDimension.pressure:
      return prefs.pressure == PressureUnit.psi ? QueryUnit.psi : QueryUnit.bar;
    case FieldDimension.weight:
      return prefs.weight == WeightUnit.pounds ? QueryUnit.lb : QueryUnit.kg;
    case FieldDimension.volume:
      return prefs.volume == VolumeUnit.cubicFeet
          ? QueryUnit.cuft
          : QueryUnit.l;
    case FieldDimension.minutes:
      return QueryUnit.min;
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return null;
  }
}

/// Converts a typed number to storage units. An explicit [unit] wins; a bare
/// number takes the diver's unit for [dimension]; a unitless dimension is
/// returned unchanged whatever [unit] says.
double groundToStorage(
  num value,
  QueryUnit? unit,
  FieldDimension dimension,
  UnitPrefs prefs,
) {
  final v = value.toDouble();
  switch (dimension) {
    case FieldDimension.depth:
      final from = switch (unit) {
        QueryUnit.m => DepthUnit.meters,
        QueryUnit.ft => DepthUnit.feet,
        _ => prefs.depth,
      };
      return from.convert(v, DepthUnit.meters);
    case FieldDimension.temperature:
      final from = switch (unit) {
        QueryUnit.c => TemperatureUnit.celsius,
        QueryUnit.f => TemperatureUnit.fahrenheit,
        _ => prefs.temperature,
      };
      return from.convert(v, TemperatureUnit.celsius);
    case FieldDimension.pressure:
      final from = switch (unit) {
        QueryUnit.bar => PressureUnit.bar,
        QueryUnit.psi => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return from.convert(v, PressureUnit.bar);
    case FieldDimension.weight:
      final from = switch (unit) {
        QueryUnit.kg => WeightUnit.kilograms,
        QueryUnit.lb => WeightUnit.pounds,
        _ => prefs.weight,
      };
      return from.convert(v, WeightUnit.kilograms);
    case FieldDimension.volume:
      final from = switch (unit) {
        QueryUnit.l => VolumeUnit.liters,
        QueryUnit.cuft => VolumeUnit.cubicFeet,
        _ => prefs.volume,
      };
      return from.convert(v, VolumeUnit.liters);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return v;
  }
}

/// The inverse for display: the storage value in [typedUnit] when one was
/// typed (suffix echoed), else in the diver's unit (no suffix).
(double, QueryUnit?) storageToDisplay(
  double storage,
  QueryUnit? typedUnit,
  FieldDimension dimension,
  UnitPrefs prefs,
) {
  switch (dimension) {
    case FieldDimension.depth:
      final to = switch (typedUnit) {
        QueryUnit.m => DepthUnit.meters,
        QueryUnit.ft => DepthUnit.feet,
        _ => prefs.depth,
      };
      return (DepthUnit.meters.convert(storage, to), typedUnit);
    case FieldDimension.temperature:
      final to = switch (typedUnit) {
        QueryUnit.c => TemperatureUnit.celsius,
        QueryUnit.f => TemperatureUnit.fahrenheit,
        _ => prefs.temperature,
      };
      return (TemperatureUnit.celsius.convert(storage, to), typedUnit);
    case FieldDimension.pressure:
      final to = switch (typedUnit) {
        QueryUnit.bar => PressureUnit.bar,
        QueryUnit.psi => PressureUnit.psi,
        _ => prefs.pressure,
      };
      return (PressureUnit.bar.convert(storage, to), typedUnit);
    case FieldDimension.weight:
      final to = switch (typedUnit) {
        QueryUnit.kg => WeightUnit.kilograms,
        QueryUnit.lb => WeightUnit.pounds,
        _ => prefs.weight,
      };
      return (WeightUnit.kilograms.convert(storage, to), typedUnit);
    case FieldDimension.volume:
      final to = switch (typedUnit) {
        QueryUnit.l => VolumeUnit.liters,
        QueryUnit.cuft => VolumeUnit.cubicFeet,
        _ => prefs.volume,
      };
      return (VolumeUnit.liters.convert(storage, to), typedUnit);
    case FieldDimension.minutes:
    case FieldDimension.percent:
    case FieldDimension.count:
    case FieldDimension.none:
      return (storage, null);
  }
}
