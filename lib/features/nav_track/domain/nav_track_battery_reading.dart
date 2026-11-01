import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// The recording console's battery over one track: its first and last
/// plausible reading and the change between them.
///
/// Plausible, not literal: the first sample can read 0V before the sensor
/// settles, which once showed "0.00 V -> 3.78 V" for a pack never near
/// empty (see [NavTrackPoint.plausibleBatteryVolts]).
class NavTrackBatteryReading {
  const NavTrackBatteryReading({required this.start, required this.end});

  /// Null when no sample carries a plausible reading. A track with a
  /// single reading starts and ends on it.
  static NavTrackBatteryReading? of(List<NavTrackPoint> points) {
    double? start;
    for (final p in points) {
      start = p.plausibleBatteryVolts;
      if (start != null) break;
    }
    if (start == null) return null;
    double? end;
    for (final p in points.reversed) {
      end = p.plausibleBatteryVolts;
      if (end != null) break;
    }
    // A start reading guarantees an end one: the backward scan reaches it.
    return NavTrackBatteryReading(start: start, end: end!);
  }

  final double start;
  final double end;

  /// Negative while the battery drains.
  double get change => end - start;
}
