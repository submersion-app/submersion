/// Verified Garmin FIT message/field numbers and scales (see design spec
/// `docs/superpowers/specs/2026-06-22-garmin-fit-import-design.md`, Appendix A).
///
/// fit_tool 1.0.5 has no named classes for the tank messages, so they are read
/// by global id + field number off a [GenericMessage] (which carries no profile
/// scale — callers apply the scales below manually).
class FitConstants {
  const FitConstants._();

  // Global message numbers.
  static const int tankUpdateMsg = 319;
  static const int tankSummaryMsg = 323;

  // tank_update (msg 319) field numbers.
  static const int tuTimestamp = 253;
  static const int tuSensor = 0;
  static const int tuPressure = 1;

  // tank_summary (msg 323) field numbers.
  static const int tsSensor = 0;
  static const int tsStartPressure = 1;
  static const int tsEndPressure = 2;
  static const int tsVolumeUsed = 3;

  // Scales: raw integer -> physical unit.
  static const double pressureScaleBar = 100.0; // raw / 100 = bar
  static const double volumeScaleLiters = 100.0; // raw / 100 = liters
  static const double semicircleToDegrees = 180.0 / 2147483648.0;

  /// Seconds between the Unix epoch (1970-01-01) and the FIT epoch
  /// (1989-12-31). A GenericMessage timestamp field is raw FIT-epoch seconds;
  /// add this and multiply by 1000 to get Unix milliseconds.
  static const int fitEpochToUnixSeconds = 631065600;
}
