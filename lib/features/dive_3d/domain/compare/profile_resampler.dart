import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';

/// Linear interpolation of a profile's depth at an arbitrary time. Shared by
/// the scrub readout and DivergenceBuilder. Mirrors the interpolation idiom in
/// ProfileLookupOverPressure (scene_geometry_service.dart).
class ProfileResampler {
  static double depthAt(ComparisonProfile p, double timeSeconds) {
    final t = p.times;
    if (t.isEmpty) return 0;
    if (timeSeconds <= t.first) return p.depths.first;
    if (timeSeconds >= t.last) return p.depths.last;
    var lo = 0, hi = t.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (t[mid] <= timeSeconds) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = t[hi] - t[lo];
    if (span <= 0) return p.depths[lo];
    final f = (timeSeconds - t[lo]) / span;
    return p.depths[lo] + (p.depths[hi] - p.depths[lo]) * f;
  }
}
