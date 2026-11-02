import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The depth of [profile] at [timestamp] (seconds from the dive's start):
/// the sample's own depth at a sample time, linear interpolation between the
/// bracketing samples, and null for an empty profile or a time outside its
/// span. [profile] is in time order, as the dive stores it.
double? profileDepthAt(List<DiveProfilePoint> profile, int timestamp) {
  if (profile.isEmpty) return null;
  if (timestamp < profile.first.timestamp) return null;
  if (timestamp > profile.last.timestamp) return null;
  for (var i = 1; i < profile.length; i++) {
    final a = profile[i - 1];
    final b = profile[i];
    if (timestamp <= b.timestamp) {
      final span = b.timestamp - a.timestamp;
      if (span <= 0) return b.depth;
      final f = (timestamp - a.timestamp) / span;
      return a.depth + (b.depth - a.depth) * f;
    }
  }
  return profile.last.depth;
}
