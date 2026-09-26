import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Reads one exposure interval field the way its unit demands: hour units
/// accept a decimal, count units (cold dives, deep dives, cycles) accept a
/// whole number only, matching the legacy dives field. A fraction in a count
/// field, a non-positive value or a blank all read as "no trigger" (null).
///
/// The dialogs validate each field with [numberValidator] first, so
/// unreadable text, which used to be a silent "no trigger" too, never gets
/// here (#1900).
double? parseExposureInterval(ExposureUnit unit, String text) {
  final value = serviceFieldNumber(text, integer: !unit.isFractional);
  if (value == null || value <= 0) return null;
  return value;
}

/// A number from one of the service dialogs' optional fields, read once the
/// dialog's form has validated: blank is "not set", and unreadable text
/// cannot reach here.
double? serviceFieldNumber(String text, {bool integer = false}) =>
    switch (readNumber(text, integer: integer)) {
      NumberValue(:final value) => value,
      NumberBlank() => null,
      NumberInvalid() => null, // unreachable: the form validated first
    };

/// The map a dialog persists from its per-unit text fields: only units that
/// parsed to a positive value are present.
Map<ExposureUnit, double> parseExposureIntervals(
  Map<ExposureUnit, String> texts,
) => {
  for (final e in texts.entries) e.key: ?parseExposureInterval(e.key, e.value),
};
