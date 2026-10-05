import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

/// Mixes closer than this in both fO2 and fHe are the same gas. Recorded air
/// segments carry airN2Fraction (0.7902) while cylinders derive 0.79, and
/// real mixes differ by at least a percent.
const double mixMatchTolerance = 0.005;

/// The recorded segment active at [timestamp]: the last one starting at or
/// before it, else the first. Mirrors BuhlmannAlgorithm's own lookup so a
/// replay breathes exactly what the analysis breathed.
ProfileGasSegment activeSegmentAt(
  List<ProfileGasSegment> segments,
  int timestamp,
) {
  var active = segments.first;
  for (final segment in segments) {
    if (segment.startTimestamp <= timestamp) {
      active = segment;
    } else {
      break;
    }
  }
  return active;
}

double segmentFO2(ProfileGasSegment segment) => 1.0 - segment.fN2 - segment.fHe;

bool sameMix(double fO2a, double fHeA, double fO2b, double fHeB) =>
    (fO2a - fO2b).abs() <= mixMatchTolerance &&
    (fHeA - fHeB).abs() <= mixMatchTolerance;
