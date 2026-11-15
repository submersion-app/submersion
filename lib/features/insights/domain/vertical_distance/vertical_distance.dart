/// How far the depth must move back from its running extreme before a change
/// of direction counts, in metres (issue #4569).
///
/// A depth sensor wobbles by a few tenths of a metre in swell and surge, and
/// a diver hovering at 20 m would otherwise collect phantom metres from every
/// wobble. This is the same idea hiking apps use for elevation gain. It is a
/// metric constant: a diver on feet gets the same counting, only displayed
/// in feet.
const double verticalDistanceDeadbandMeters = 1.0;

/// Bumped whenever [verticalDistanceMeters] would give a different answer for
/// the same samples (a new deadband, a changed rule). The cache fingerprint
/// carries it, so every cached figure is recomputed with no purge.
const int verticalDistanceAlgorithmVersion = 1;

/// One dive's vertical distance in metres: how far the diver travelled down,
/// which equals how far they travelled up.
///
/// [depths] are the profile's depths in time order. The path is taken to
/// start and end at the surface, even when the recording starts or stops
/// below it, so a computer that woke late or a cut-off download still counts
/// the whole way down and back.
///
/// A change of direction is confirmed only once depth has moved at least
/// [deadband] back from the running extreme. The surface at either end is
/// always a turning point. The result is the sum of the descending legs
/// between turning points; because the path starts and ends at 0 m, the
/// ascending legs sum to the same value.
///
/// Non-finite and negative depths are skipped. No usable depth gives 0.
double verticalDistanceMeters(
  Iterable<double> depths, {
  double deadband = verticalDistanceDeadbandMeters,
}) {
  var total = 0.0;
  // Depth of the last confirmed turning point, starting at the surface.
  var last = 0.0;
  // Deepest point while descending, shallowest while ascending.
  var extreme = 0.0;
  var descending = true;
  for (final d in depths) {
    if (!d.isFinite || d < 0) continue;
    if (descending) {
      if (d > extreme) {
        extreme = d;
      } else if (extreme - d >= deadband) {
        total += extreme - last;
        last = extreme;
        descending = false;
        extreme = d;
      }
    } else {
      if (d < extreme) {
        extreme = d;
      } else if (d - extreme >= deadband) {
        last = extreme;
        descending = true;
        extreme = d;
      }
    }
  }
  // The surface after the last sample closes the final descent, whatever
  // the deadband.
  if (descending) total += extreme - last;
  return total;
}
