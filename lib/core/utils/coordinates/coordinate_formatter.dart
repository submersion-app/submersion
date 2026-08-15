import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// Renders a coordinate pair in the diver's chosen notation.
///
/// Grid formats degrade to decimal degrees outside the UTM latitude band
/// rather than returning an error string, so a polar site still shows a
/// usable position.
String formatCoordinates(
  double latitude,
  double longitude,
  CoordinateFormat format,
) {
  switch (format) {
    case CoordinateFormat.decimalDegrees:
    case CoordinateFormat.degreesDecimalMinutes:
    case CoordinateFormat.degreesMinutesSeconds:
      return '${formatLatitude(latitude, format)}, '
          '${formatLongitude(longitude, format)}';
    case CoordinateFormat.utm:
      final utm = latLngToUtm(latitude, longitude);
      if (utm == null) {
        return formatCoordinates(
          latitude,
          longitude,
          CoordinateFormat.decimalDegrees,
        );
      }
      return '${utm.zone}${utm.band} ${utm.easting.round()}E '
          '${utm.northing.round()}N';
    case CoordinateFormat.mgrs:
      final mgrs = latLngToMgrs(latitude, longitude);
      return mgrs ??
          formatCoordinates(
            latitude,
            longitude,
            CoordinateFormat.decimalDegrees,
          );
  }
}

/// Renders a single latitude. Grid formats degrade to decimal degrees.
String formatLatitude(double latitude, CoordinateFormat format) =>
    _formatAxis(latitude, format, isLatitude: true);

/// Renders a single longitude. Grid formats degrade to decimal degrees.
String formatLongitude(double longitude, CoordinateFormat format) =>
    _formatAxis(longitude, format, isLatitude: false);

/// The hemisphere letter for an axis value.
String hemisphereFor(double value, {required bool isLatitude}) =>
    isLatitude ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');

/// Decimal places used when rendering minutes in degrees-decimal-minutes.
const int degreesDecimalMinutesPrecision = 3;

/// Decimal places used when rendering seconds in degrees-minutes-seconds.
const int degreesMinutesSecondsPrecision = 1;

/// One axis split into degrees and decimal minutes, ready to render.
///
/// The carry is applied here rather than at each call site: rounding minutes
/// for display can reach exactly 60, and "60.000'" is not a real value. The
/// parser rejects it, so a stored coordinate rendered that way would read
/// back as invalid.
({int degrees, double minutes, String hemisphere}) axisAsDegreesDecimalMinutes(
  double value, {
  required bool isLatitude,
}) {
  final hemisphere = hemisphereFor(value, isLatitude: isLatitude);
  final magnitude = value.abs();
  var degrees = magnitude.floor();
  var minutes = (magnitude - degrees) * 60;
  if (double.parse(minutes.toStringAsFixed(degreesDecimalMinutesPrecision)) >=
      60) {
    minutes = 0;
    degrees += 1;
  }
  return (degrees: degrees, minutes: minutes, hemisphere: hemisphere);
}

/// One axis split into degrees, minutes and seconds, ready to render.
///
/// See [axisAsDegreesDecimalMinutes] on why the carry lives here. Seconds can
/// round to 60 and then carry the minutes to 60 in turn.
({int degrees, int minutes, double seconds, String hemisphere})
axisAsDegreesMinutesSeconds(double value, {required bool isLatitude}) {
  final hemisphere = hemisphereFor(value, isLatitude: isLatitude);
  final magnitude = value.abs();
  var degrees = magnitude.floor();
  final minutesFull = (magnitude - degrees) * 60;
  var minutes = minutesFull.floor();
  var seconds = (minutesFull - minutes) * 60;
  if (double.parse(seconds.toStringAsFixed(degreesMinutesSecondsPrecision)) >=
      60) {
    seconds = 0;
    minutes += 1;
  }
  if (minutes >= 60) {
    minutes = 0;
    degrees += 1;
  }
  return (
    degrees: degrees,
    minutes: minutes,
    seconds: seconds,
    hemisphere: hemisphere,
  );
}

String _formatAxis(
  double value,
  CoordinateFormat format, {
  required bool isLatitude,
}) {
  switch (format) {
    case CoordinateFormat.degreesDecimalMinutes:
      final parts = axisAsDegreesDecimalMinutes(value, isLatitude: isLatitude);
      final minutes = parts.minutes
          .toStringAsFixed(degreesDecimalMinutesPrecision)
          .padLeft(6, '0');
      return '${parts.degrees}° $minutes\' ${parts.hemisphere}';

    case CoordinateFormat.degreesMinutesSeconds:
      final parts = axisAsDegreesMinutesSeconds(value, isLatitude: isLatitude);
      final minutes = parts.minutes.toString().padLeft(2, '0');
      final seconds = parts.seconds
          .toStringAsFixed(degreesMinutesSecondsPrecision)
          .padLeft(4, '0');
      return '${parts.degrees}° $minutes\' $seconds" ${parts.hemisphere}';

    case CoordinateFormat.decimalDegrees:
    case CoordinateFormat.utm:
    case CoordinateFormat.mgrs:
      return '${value.abs().toStringAsFixed(6)}° '
          '${hemisphereFor(value, isLatitude: isLatitude)}';
  }
}
