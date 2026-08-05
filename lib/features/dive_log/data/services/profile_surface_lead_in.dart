import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether a profile chart should be extended back to the surface at t=0.
///
/// Dive computers do not sample at t=0, so a profile whose first sample sits
/// one interval in leaves a gap between the chart's t=0 origin and the start of
/// every plotted line. Closing it is truthful: the diver was at the surface
/// before the first reading was taken (issue #684).
///
/// Deliberately limited to a gap of at most one sample interval. A profile that
/// starts later than that has been trimmed or merged, and drawing across it
/// would fabricate dive time that was never recorded -- worse than the gap it
/// would close.
///
/// Shared by the full profile chart and the compact profile widgets so they
/// cannot disagree about where a dive begins.
bool shouldDrawSurfaceLeadIn(List<DiveProfilePoint> profile) {
  if (profile.length < 2) return false;
  final firstSample = profile.first.timestamp;
  if (firstSample <= 0) return false;
  final interval = profile[1].timestamp - firstSample;
  return interval > 0 && firstSample <= interval;
}

/// Ambient pressure in bar at [depthMeters]: 1 bar at the surface, plus 1 bar
/// per 10 m of seawater.
double ambientPressureBar(double depthMeters) => 1.0 + depthMeters / 10.0;

/// The surface value of a quantity proportional to ambient pressure -- partial
/// pressures and gas density -- given its value at [depthMeters].
///
/// These lead-ins are calculated rather than held flat, because they are a
/// deterministic function of depth: at the surface the ambient pressure is
/// 1 bar, so each reduces to its gas fraction. Dividing by the ambient pressure
/// at the sample recovers that fraction without resolving which cylinder was
/// breathed. Reduces to the sampled value when the diver is still at the
/// surface, which is the usual case one sample into a dive.
double surfaceValueAtOneBar(double valueAtDepth, double depthMeters) =>
    valueAtDepth / ambientPressureBar(depthMeters);
