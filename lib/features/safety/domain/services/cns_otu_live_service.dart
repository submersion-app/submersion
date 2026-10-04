import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Projects the CNS% at the end of the diver's last dive forward to the
/// current moment.
///
/// Unlike [NoFlyService], which anchors a fixed guideline deadline, this
/// recomputes the live value on every call: callers re-evaluate it on each
/// UI tick (see `CnsOtuPage`'s minute timer) rather than caching a stale
/// result from the moment the data was fetched.
///
/// OTU has no equivalent decay -- it is tracked purely as a daily/weekly
/// cumulative total against NOAA/REPEX limits, which the existing
/// `profileAnalysisProvider`/`weeklyOtuProvider` already compute correctly
/// for the most recent dive.
class CnsOtuLiveService {
  const CnsOtuLiveService._();

  /// CNS% remaining at [now], decayed from [cnsAtDiveEnd] over the time
  /// elapsed since [lastDiveEnd] using the same 90-minute half-time formula
  /// as the inter-dive residual lookback ([CnsTable.cnsAfterSurfaceInterval]).
  ///
  /// A [now] at or before [lastDiveEnd] (clock skew, or evaluating right at
  /// the dive's end) applies no decay rather than negative elapsed minutes.
  static double currentCns({
    required double cnsAtDiveEnd,
    required DateTime lastDiveEnd,
    required DateTime now,
  }) {
    final elapsedMinutes = now.difference(lastDiveEnd).inMinutes;
    if (elapsedMinutes <= 0) return cnsAtDiveEnd;
    return CnsTable.cnsAfterSurfaceInterval(cnsAtDiveEnd, elapsedMinutes);
  }
}
