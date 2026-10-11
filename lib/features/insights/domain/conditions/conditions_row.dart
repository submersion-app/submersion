import 'package:submersion/core/constants/enums.dart';

/// The enum value stored under [name], or null when [name] is null, blank or
/// not a value of the enum. An import that wrote display text instead of the
/// enum name counts as not recorded rather than failing the whole chart.
T? parseStoredEnum<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : values.asNameMap()[name];

/// One in-scope dive's condition fields, as the Conditions statistics read
/// them (issue #3118). Units are the stored ones: Celsius, m/s, bar, metres.
class ConditionsRow {
  const ConditionsRow({
    required this.diveId,
    required this.dateTime,
    this.airTemp,
    this.cloudCover,
    this.precipitation,
    this.windSpeed,
    this.windDirection,
    this.humidity,
    this.surfacePressure,
    this.currentStrength,
    this.currentDirection,
    this.swellHeight,
    this.altitude,
    this.exitMethod,
  });

  final String diveId;
  final DateTime dateTime;
  final double? airTemp;
  final CloudCover? cloudCover;
  final Precipitation? precipitation;
  final double? windSpeed;
  final CurrentDirection? windDirection;
  final double? humidity;
  final double? surfacePressure;
  final CurrentStrength? currentStrength;
  final CurrentDirection? currentDirection;
  final double? swellHeight;
  final double? altitude;
  final EntryMethod? exitMethod;
}
