import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Renders [value] the way the app renders it elsewhere. Never throws: a
/// value of an unexpected type (an older peer, a hand-edited row) prints as
/// stored, because a dialog that crashes leaves the conflict unresolvable.
String formatConflictValue({
  required AppLocalizations l10n,
  required UnitFormatter units,
  required ConflictField field,
  required Object? value,
}) {
  if (value == null) return l10n.settings_conflict_notSet;
  try {
    return _format(l10n, units, field, value);
  } on ArgumentError {
    // DateTime refuses epochs beyond +/-8.64e15 ms, which a corrupt or
    // seconds-for-millis value can reach.
    return value.toString();
  }
}

String _format(
  AppLocalizations l10n,
  UnitFormatter units,
  ConflictField field,
  Object value,
) {
  switch (field.kind) {
    case FieldKind.opaque:
      return l10n.settings_conflict_changed;
    case FieldKind.boolean:
      if (value is bool) return _yesNo(l10n, value);
      if (value is num) return _yesNo(l10n, value != 0);
      return value.toString();
    case FieldKind.enumValue:
      if (value is String) return field.enumLabel?.call(l10n, value) ?? value;
      return value.toString();
    case FieldKind.dateTime:
      final moment = _instant(value);
      if (moment == null) return value.toString();
      return units.formatDateTime(moment, l10n: l10n);
    case FieldKind.epochSeconds:
      if (value is! int) return value.toString();
      return units.formatDateTime(
        DateTime.fromMillisecondsSinceEpoch(value * 1000),
        l10n: l10n,
      );
    case FieldKind.wallClock:
      final clock = _wallClock(value);
      if (clock == null) return value.toString();
      return units.formatDateTime(clock, l10n: l10n);
    case FieldKind.date:
      final day = _instant(value);
      if (day == null) return value.toString();
      return units.formatDate(day);
    case FieldKind.utcDate:
      final day = _wallClock(value);
      if (day == null) return value.toString();
      return units.formatDate(day);
    case FieldKind.timeOfDay:
      if (value is int) return units.formatMinutesOfDay(value);
      return value.toString();
    case FieldKind.unknown:
      if (value is bool) return _yesNo(l10n, value);
      if (value is double) return formatDecimalForDisplay(value);
      return value.toString();
    case FieldKind.number:
      if (value is double) return formatDecimalForDisplay(value);
      return value.toString();
    case FieldKind.shortText:
    case FieldKind.longText:
    case FieldKind.reference:
      return value.toString();
    default:
      break;
  }

  if (value is! num) return value.toString();
  final number = value.toDouble();
  return switch (field.kind) {
    FieldKind.depth => units.formatDepth(number),
    FieldKind.distance => units.formatDistance(number),
    FieldKind.geoDistance => units.formatGeoDistance(number),
    FieldKind.pressure => units.formatPressure(number),
    FieldKind.surfacePressure => units.formatSurfacePressure(number),
    FieldKind.temperature => units.formatTemperature(number),
    FieldKind.weight => units.formatWeight(number),
    FieldKind.volume => units.formatVolume(number),
    FieldKind.speed => units.formatSpeed(number),
    FieldKind.windSpeed => units.formatWindSpeed(number),
    FieldKind.altitude => units.formatAltitude(number),
    FieldKind.heightCm => units.formatHeight(number),
    FieldKind.ascentRate => units.formatDepthRate(number),
    FieldKind.rmv => units.formatRmv(number),
    FieldKind.latitude => units.formatLatitude(number),
    FieldKind.longitude => units.formatLongitude(number),
    FieldKind.percent => '${_trim(number)}%',
    FieldKind.fraction => '${_trim(number * 100)}%',
    FieldKind.partialPressure =>
      '${formatFixedForDisplay(number, 2)} ${l10n.units_pressure_bar}',
    FieldKind.durationSeconds => formatConflictSeconds(number.round()),
    FieldKind.durationMinutes => formatConflictSeconds((number * 60).round()),
    FieldKind.durationHours => formatConflictSeconds((number * 3600).round()),
    _ => value.toString(),
  };
}

String _yesNo(AppLocalizations l10n, bool value) =>
    value ? l10n.common_action_yes : l10n.common_action_no;

/// A real instant in the device's zone. A zoned ISO string is moved to local
/// time through its epoch, which is what `toLocal` would do.
DateTime? _instant(Object value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is DateTime) return value;
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) return parsed;
  return DateTime.fromMillisecondsSinceEpoch(parsed.millisecondsSinceEpoch);
}

/// A stored dive clock, decoded the way every other dive-time reader does.
DateTime? _wallClock(Object value) {
  if (value is int) return wallClockUtcFromMillis(value);
  if (value is String) return parseExternalDateAsWallClockUtc(value);
  if (value is DateTime) return value;
  return null;
}

/// 32.0 -> "32", 32.5 -> "32.5" ("32,5" under de).
String _trim(double value) =>
    formatFixedForDisplay(value, value == value.roundToDouble() ? 0 : 1);

/// A stored count of seconds as "1h 5m" or "45min".
///
/// Anything under a minute keeps its seconds instead of collapsing to "0min":
/// two versions differing only in a sub-minute value would otherwise render
/// identically in the one dialog whose whole job is telling them apart. A
/// negative value takes the same path and shows itself rather than wrapping
/// into a plausible-looking positive minute count.
String formatConflictSeconds(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final totalMinutes = seconds ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}min';
}
