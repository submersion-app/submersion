import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// Cumulative distance per point, in metres, from the route's own first
/// sample -- presentation-local wrapper because the trust slider is the
/// only reader that needs it purely as a distance axis.
///
/// Delegates to [NavTrackCorrector.cumulativeDistances] instead of
/// recomputing geometric path length here: on an ENC log the device's own
/// `distance` channel and the 2D path length can disagree (a route that
/// loops back near itself keeps accumulating device distance from the
/// speed log while its geometric path length barely grows), and the
/// corrector itself prefers the device channel when it is present and
/// monotone (see [NavTrackCorrector.apply]). Recomputing path length
/// independently here would let the slider's trusted metres, cutoff
/// marker and duration point at a different sample than the correction
/// actually freezes.
///
/// Callers that feed this the trust slider's axis must first truncate
/// [points] to the active range
/// ([NavTrackCorrector.activeRangeStartIndex]..[NavTrackCorrector.activeRangeEndIndex]):
/// passing the whole raw recording would let a GPS-fix event's jump and
/// post-surfacing wobble (or a pre-dive calibration) dominate the total,
/// so the slider's "trusted up to" position would disagree with where
/// [NavTrackCorrector.apply] actually freezes the route -- the prefix
/// would look like it keeps moving as the diver drags the slider, when
/// the correction itself has already stopped touching it.
List<double> cumulativeDistances(List<NavTrackPoint> points) =>
    NavTrackCorrector.cumulativeDistances(points);

/// The index of the first point whose cumulative distance reaches
/// [trustedDistance] -- the point the trust slider's cutoff marker sits on
/// -- or the last index when none does (the whole route is within the
/// trusted range). Shared by the trust readout's duration and the map
/// marker so the two never disagree about which sample the slider points
/// at.
int trustCutoffIndex(List<double> cumulative, double trustedDistance) {
  for (var i = 0; i < cumulative.length; i++) {
    if (cumulative[i] >= trustedDistance) return i;
  }
  return cumulative.isEmpty ? 0 : cumulative.length - 1;
}
