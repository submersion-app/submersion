import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

/// Reads one exposure interval field the way its unit demands: hour units
/// accept a decimal, count units (cold dives, deep dives, cycles) accept a
/// whole number only, matching the legacy dives field. A fraction in a count
/// field, a non-positive value or a blank all read as "no trigger" (null).
double? parseExposureInterval(ExposureUnit unit, String text) {
  final value = unit.isFractional
      ? parseUserDecimal(text)
      : parseUserInt(text)?.toDouble();
  if (value == null || value <= 0) return null;
  return value;
}

/// The map a dialog persists from its per-unit text fields: only units that
/// parsed to a positive value are present.
Map<ExposureUnit, double> parseExposureIntervals(
  Map<ExposureUnit, String> texts,
) => {
  for (final e in texts.entries) e.key: ?parseExposureInterval(e.key, e.value),
};
