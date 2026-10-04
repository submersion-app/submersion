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
  /// the dive's end) applies no decay rather than a negative elapsed span.
  ///
  /// The guard checks the true elapsed [Duration], not whole minutes: a
  /// `now` a few seconds after [lastDiveEnd] must not be mistaken for "at or
  /// before" just because it truncates to 0 minutes.
  static double currentCns({
    required double cnsAtDiveEnd,
    required DateTime lastDiveEnd,
    required DateTime now,
  }) {
    final elapsed = now.difference(lastDiveEnd);
    if (elapsed <= Duration.zero) return cnsAtDiveEnd;
    return CnsTable.cnsAfterSurfaceInterval(cnsAtDiveEnd, elapsed.inMinutes);
  }

  /// Today's OTU daily total, or [otuDailyAtDiveEnd] unchanged if [now] is
  /// still the same calendar day as [lastDiveEnd].
  ///
  /// Unlike CNS, OTU does not decay -- but [otuDailyAtDiveEnd] (the dive's
  /// own `O2Exposure.otuDaily`) is fixed to THAT dive's calendar day. Once
  /// "now" rolls into a later day, that total no longer describes today's
  /// exposure and must read as 0, not as a stale near-limit figure.
  ///
  /// Both [lastDiveEnd] and [now] are wall-clock-as-UTC (the dive-time
  /// frame; see `NoFlyService.wallClockNowUtc`), so comparing their calendar
  /// components directly is correct.
  static double currentOtuDaily({
    required double otuDailyAtDiveEnd,
    required DateTime lastDiveEnd,
    required DateTime now,
  }) {
    final sameDay =
        now.year == lastDiveEnd.year &&
        now.month == lastDiveEnd.month &&
        now.day == lastDiveEnd.day;
    return sameDay ? otuDailyAtDiveEnd : 0.0;
  }
}
