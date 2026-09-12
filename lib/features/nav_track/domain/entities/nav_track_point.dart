import 'package:equatable/equatable.dart';

/// One sample of a measured underwater route, as read from a navigation
/// console log (e.g. a Seacraft ENC3 CSV export) or an IMU-equipped dive
/// computer's route data.
///
/// [north] and [east] are metres relative to the recording's own origin --
/// there is no absolute coordinate anywhere in the raw data. Georeferencing
/// (placing the origin on a map) and drift correction (rubber-banding onto
/// a known end point) are applied later, on read, by
/// `NavTrackGeoref`/`NavTrackCorrector`; this type always holds the
/// recording exactly as the device produced it.
class NavTrackPoint extends Equatable {
  /// Wall-clock-as-UTC epoch seconds (the same convention `dives.entryTime`
  /// uses): the recording device's own wall-clock components reinterpreted
  /// as UTC, so a sample compares directly against a dive's timestamps on
  /// any device.
  final int timestamp;

  /// Metres north of the recording's own origin (positive north).
  final double north;

  /// Metres east of the recording's own origin (positive east).
  final double east;

  /// Metres below the surface (positive down). Never negative: a small
  /// negative reading from the source is clamped to zero at parse time.
  final double depth;

  /// Compass heading in degrees, 0 to 360, or null when the source omitted
  /// it or reported a value outside that range.
  final double? course;

  /// Device pitch in degrees.
  final double? pitch;

  /// Device roll in degrees.
  final double? roll;

  /// Cumulative distance in metres, as logged by the device itself.
  final double? distance;

  /// Speed in metres per second (SI, matching the app's other speed
  /// fields), converted at parse time from whatever unit the source used.
  final double? speed;

  /// Water temperature in degrees Celsius.
  final double? temperature;

  /// Device battery voltage, or null when the source logged a status code
  /// instead of a real reading (e.g. a negative value).
  final double? batteryVolts;

  const NavTrackPoint({
    required this.timestamp,
    required this.north,
    required this.east,
    required this.depth,
    this.course,
    this.pitch,
    this.roll,
    this.distance,
    this.speed,
    this.temperature,
    this.batteryVolts,
  });

  @override
  List<Object?> get props => [
    timestamp,
    north,
    east,
    depth,
    course,
    pitch,
    roll,
    distance,
    speed,
    temperature,
    batteryVolts,
  ];
}
