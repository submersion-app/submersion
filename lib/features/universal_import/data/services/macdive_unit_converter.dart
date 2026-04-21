import 'package:submersion/features/universal_import/data/services/macdive_xml_models.dart';

/// Converts MacDive-raw numeric values (in the document's declared unit
/// system) to Submersion's canonical internal units: meters, Celsius,
/// bar, kilograms, liters. Called at the reader boundary so everything
/// downstream (parser, payload, importer, UI) sees one unit system.
///
/// For [MacDiveUnitSystem.unknown] (declaration missing or unparseable),
/// values pass through unchanged. This is a best-effort fallback: most
/// MacDive files declare their units, and silently converting when we
/// aren't sure risks worse corruption than letting the value through.
class MacDiveUnitConverter {
  final MacDiveUnitSystem units;
  const MacDiveUnitConverter(this.units);

  bool get _isImperial => units == MacDiveUnitSystem.imperial;

  /// Feet → meters when imperial; passthrough otherwise.
  double? depthToMeters(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.3048 : raw;
  }

  /// Fahrenheit → Celsius when imperial; passthrough otherwise.
  double? tempToCelsius(double? raw) {
    if (raw == null) return null;
    return _isImperial ? (raw - 32.0) * 5.0 / 9.0 : raw;
  }

  /// PSI → bar when imperial; passthrough otherwise.
  double? pressureToBar(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.0689476 : raw;
  }

  /// Pounds → kilograms when imperial; passthrough otherwise.
  double? weightToKg(double? raw) {
    if (raw == null) return null;
    return _isImperial ? raw * 0.453592 : raw;
  }

  /// Tank size conversion is not a scalar under imperial:
  /// MacDive Imperial tank size is expressed as cubic feet at the tank's
  /// working pressure (e.g. AL80 = 77.4 cft @ 3000 psi). To get a water
  /// capacity in liters we use:
  ///   litresAtSurface   = cft * 28.3168
  ///   workingPressureBar = psi * 0.0689476
  ///   waterCapacityL    = litresAtSurface / workingPressureBar
  ///
  /// Metric MacDive already stores water capacity in liters directly —
  /// passthrough.
  ///
  /// Returns null when [rawSize] is null, or (imperial only) when
  /// [rawWorkingPressure] is null or zero, since we can't complete the
  /// computation without both values.
  double? tankSizeLiters(double? rawSize, double? rawWorkingPressure) {
    if (rawSize == null) return null;
    if (!_isImperial) return rawSize;
    if (rawWorkingPressure == null || rawWorkingPressure <= 0) return null;
    final litresAtSurface = rawSize * 28.3168;
    final workingPressureBar = rawWorkingPressure * 0.0689476;
    return litresAtSurface / workingPressureBar;
  }
}
