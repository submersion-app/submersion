import 'package:submersion/core/deco/entities/dive_environment.dart';
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

/// The surface value of a quantity proportional to ambient pressure -- partial
/// pressures and gas density -- given its value at [depthMeters] in
/// [environment], the dive's own water and surface pressure.
///
/// These lead-ins are calculated rather than held flat, because they are a
/// deterministic function of depth. Dividing by the ambient pressure at the
/// sample recovers the gas fraction without resolving which cylinder was
/// breathed, and the surface pressure scales it back up. Reduces to the sampled
/// value when the diver is still at the surface, which is the usual case one
/// sample into a dive.
double valueAtSurface(
  double valueAtDepth,
  double depthMeters, {
  DiveEnvironment environment = DiveEnvironment.standard,
}) =>
    valueAtDepth /
    environment.pressureAtDepth(depthMeters) *
    environment.surfacePressureBar;
