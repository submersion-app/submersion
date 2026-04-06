import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// Extension providing display string formatting for [DiveField] raw values.
extension DiveFieldFormatter on DiveField {
  /// Format a raw value (from [extractFromDive] or [extractFromSummary])
  /// as a display string, applying unit conversions as needed.
  String formatValue(dynamic value, UnitFormatter units) {
    if (value == null) return '--';

    switch (this) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.swellHeight:
        return units.formatDepth(value as double?);

      case DiveField.waterTemp:
      case DiveField.airTemp:
        return units.formatTemperature(value as double?);

      case DiveField.altitude:
        return units.formatAltitude(value as double?);

      case DiveField.surfacePressure:
        return units.formatBarometricPressure(value as double?);

      case DiveField.startPressure:
      case DiveField.endPressure:
        return units.formatPressure(value as double?);

      case DiveField.sacRate:
        if (value is double) {
          return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
        }
        return '--';

      case DiveField.gasConsumed:
        return units.formatVolume(value as double?);

      case DiveField.totalWeight:
        return units.formatWeight(value as double?);

      case DiveField.windSpeed:
        return units.formatWindSpeed(value as double?);

      case DiveField.humidity:
        if (value is double) {
          return '${value.toStringAsFixed(0)}%';
        }
        return '--';

      case DiveField.bottomTime:
      case DiveField.runtime:
      case DiveField.surfaceInterval:
        return _formatDuration(value);

      case DiveField.dateTime:
        return units.formatDateTimeBullet(value as DateTime?);

      case DiveField.gradientFactorLow:
      case DiveField.gradientFactorHigh:
        if (value is int) {
          return '$value%';
        }
        return '--';

      case DiveField.setpointLow:
      case DiveField.setpointHigh:
      case DiveField.setpointDeco:
        if (value is double) {
          return '${value.toStringAsFixed(2)} bar';
        }
        return '--';

      case DiveField.cnsStart:
      case DiveField.cnsEnd:
        if (value is double) {
          return '${value.toStringAsFixed(1)}%';
        }
        return '--';

      case DiveField.isFavorite:
        if (value is bool) {
          return value ? 'Yes' : 'No';
        }
        return '--';

      case DiveField.tags:
        if (value is List) {
          return value.isEmpty ? '--' : value.join(', ');
        }
        return '--';

      case DiveField.tankCount:
        return '$value';

      case DiveField.diveNumber:
        return '#$value';

      default:
        return '$value';
    }
  }
}

/// Format a [Duration] value as a human-readable string.
///
/// Produces "Xh Ym" for durations >= 1 hour, or "Xmin" otherwise.
String _formatDuration(dynamic value) {
  if (value == null) return '--';
  if (value is! Duration) return '--';

  final totalMinutes = value.inMinutes;
  if (totalMinutes <= 0) return '--';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}min';
}
