import 'package:flutter/foundation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How a synced column's stored value is shown. Units are always the stored
/// (metric) ones: depth in metres, pressure in bar, temperature in Celsius,
/// weight in kg, volume in litres, speed in m/s.
enum FieldKind {
  depth,

  /// Short horizontal metres in the depth unit (visibility, surface drift).
  distance,

  /// Metres that may run to kilometres (track totals), auto-scaled.
  geoDistance,
  pressure,

  /// Atmospheric pressure in bar, shown the way the dive screen shows it.
  surfacePressure,
  temperature,
  weight,
  volume,
  speed,
  windSpeed,
  altitude,
  heightCm,
  ascentRate,

  /// A gas rate in litres per minute (SAC, RMV).
  rmv,
  latitude,
  longitude,
  percent,
  fraction,
  partialPressure,
  durationSeconds,
  durationMinutes,
  durationHours,

  /// A real instant, shown in the device's time zone.
  dateTime,

  /// A real instant stored as Unix seconds rather than milliseconds.
  epochSeconds,

  /// A dive computer's clock stored flagged UTC (`dives.dive_date_time`):
  /// shown as the stored digits, never shifted to the device's zone.
  wallClock,

  /// A calendar day the app wrote from a local DateTime (trips,
  /// certifications, service dates): decoded in the device's zone, the way
  /// the repositories read it back.
  date,

  /// A calendar day stored as UTC midnight (a trip day's weather, an
  /// incident date): shown as that day in every zone.
  utcDate,

  /// Minutes after local midnight (opening hours).
  timeOfDay,
  boolean,
  number,
  shortText,
  longText,
  enumValue,
  reference,
  opaque,

  /// Not in the catalogue; formatted by the value's runtime type.
  unknown,
}

/// The stored value's localized label, or null for a value this build does
/// not know (a newer peer wrote it).
typedef ConflictEnumLabeler =
    String? Function(AppLocalizations l10n, String stored);

/// What the conflict dialog knows about one column.
@immutable
class ConflictField {
  const ConflictField(this.label, this.kind, {this.enumLabel});

  final String Function(AppLocalizations l10n) label;
  final FieldKind kind;

  /// Required for [FieldKind.enumValue], ignored otherwise.
  final ConflictEnumLabeler? enumLabel;
}
