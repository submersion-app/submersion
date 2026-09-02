/// Depth below which a diver counts as being on the surface, in meters.
///
/// Matches Subsurface's long-standing `SURFACE_THRESHOLD` of 750 mm, so a
/// dive imported from either app agrees on where the dive ended.
const double kSurfaceThresholdMeters = 0.75;

/// How far a reported end pressure may sit from the last post-surfacing
/// reading and still count as having come from it, in bar.
///
/// Sources quantize pressure before converting it: Shearwater logs units of
/// 2 psi (about 0.14 bar), and exported files often round to whole psi or bar.
/// The artifact this guards against is measured in tens of bar, so a tolerance
/// this small cannot let one through.
const double kPressureMatchToleranceBar = 0.5;

/// One profile sample, reduced to what the surfacing rule needs: when it was
/// taken, how deep the diver was, and what each cylinder read at that instant.
///
/// [tankPressuresBar] is keyed by cylinder index and is empty for a sample that
/// carries no transmitter reading.
class SurfacingProfilePoint {
  const SurfacingProfilePoint({
    required this.timeSeconds,
    required this.depthMeters,
    this.tankPressuresBar = const {},
  });

  final int timeSeconds;
  final double depthMeters;
  final Map<int, double> tankPressuresBar;
}

/// What one cylinder read on either side of the surfacing moment.
class SurfacingTankReading {
  const SurfacingTankReading({
    required this.atSurfacing,
    required this.lastAfterSurfacing,
  });

  /// The cylinder's most recent reading at or before surfacing: the pressure
  /// it actually held at the end of the dive.
  final double atSurfacing;

  /// The cylinder's last reading in the post-surfacing tail, or null when the
  /// recording stopped at the surface.
  final double? lastAfterSurfacing;
}

/// What each cylinder read on either side of the moment the diver surfaced,
/// keyed by cylinder index.
///
/// Dive computers keep recording for a while after the diver reaches the
/// surface, so the last reading in the profile is not the reading at the end of
/// the dive. On a rebreather whose oxygen cylinder feeds a constant mass flow
/// orifice, closing the valve topside leaves the hose bleeding down through
/// that orifice, and the tail of the recording can shed most of the cylinder's
/// apparent contents (issue #1092).
///
/// Surfacing is the last sample deeper than [kSurfaceThresholdMeters], so a
/// diver who drops back down after a surface break is measured from the final
/// descent. Each cylinder is read independently and carries its most recent
/// value forward, because transmitters report on their own cadence and the
/// surfacing sample may hold no reading for a given cylinder.
///
/// Cylinders with no reading at or before surfacing are left out: there is
/// nothing to correct a reported end pressure with. Returns an empty map when
/// the profile never went below the threshold or carries no pressure at all.
/// Sample order in [points] does not matter.
Map<int, SurfacingTankReading> surfacingTankReadings(
  List<SurfacingProfilePoint> points,
) {
  int? surfacingTime;
  for (final p in points) {
    if (p.depthMeters > kSurfaceThresholdMeters &&
        (surfacingTime == null || p.timeSeconds > surfacingTime)) {
      surfacingTime = p.timeSeconds;
    }
  }
  if (surfacingTime == null) {
    return const {};
  }

  final atSurfacing = <int, double>{};
  final atSurfacingTime = <int, int>{};
  final afterSurfacing = <int, double>{};
  final afterSurfacingTime = <int, int>{};
  for (final p in points) {
    final surfaced = p.timeSeconds > surfacingTime;
    final values = surfaced ? afterSurfacing : atSurfacing;
    final times = surfaced ? afterSurfacingTime : atSurfacingTime;
    for (final entry in p.tankPressuresBar.entries) {
      final seen = times[entry.key];
      if (seen == null || p.timeSeconds >= seen) {
        values[entry.key] = entry.value;
        times[entry.key] = p.timeSeconds;
      }
    }
  }

  return {
    for (final entry in atSurfacing.entries)
      entry.key: SurfacingTankReading(
        atSurfacing: entry.value,
        lastAfterSurfacing: afterSurfacing[entry.key],
      ),
  };
}

/// The end pressure to record for a cylinder, given what the source reported
/// and what the profile read around surfacing.
///
/// Only a reported pressure that matches the last post-surfacing reading is
/// corrected. That match is the evidence that the source simply took the last
/// sample it saw and so inherited the post-surfacing bleed-down. A source that
/// read its end pressure from anywhere else -- a log header, or a transmitter
/// that dropped out before the diver surfaced -- is left alone, because its
/// value has an origin this rule knows nothing about.
///
/// Beyond that, the correction only ever raises [reportedBar], and a source
/// that reported nothing keeps reporting nothing rather than gaining a
/// fabricated value.
double? trimEndPressureBar({
  required double? reportedBar,
  required SurfacingTankReading? reading,
}) {
  if (reportedBar == null || reading == null) {
    return reportedBar;
  }
  final tail = reading.lastAfterSurfacing;
  if (tail == null ||
      (tail - reportedBar).abs() > kPressureMatchToleranceBar ||
      reading.atSurfacing <= reportedBar) {
    return reportedBar;
  }
  return reading.atSurfacing;
}
