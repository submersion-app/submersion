import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Projects the CNS% at the end of the diver's last dive forward to the
/// current moment.
///
/// Unlike [NoFlyService], which anchors a fixed guideline deadline, this
/// recomputes the live value on every call: callers re-evaluate it on each
/// UI tick (see `CnsOtuPage`'s minute timer) rather than caching a stale
/// result from the moment the data was fetched.
///
/// OTU has no equivalent decay: it is tracked as daily and weekly totals
/// against NOAA/REPEX limits, summed by `sumOtuInWindow` when the snapshot
/// is fetched. This service only keeps the daily total from outliving its
/// calendar day.
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

  /// [dailyOtu] while [now] is still the calendar day it was computed on
  /// ([computedAt]), else 0.
  ///
  /// Unlike CNS, OTU does not decay, but a daily total belongs to one
  /// calendar day. The snapshot refetches itself at midnight; this keeps the
  /// readout from showing yesterday's total as today's in the moments before
  /// that refetch lands (or while a suspended app catches up).
  ///
  /// Both [computedAt] and [now] are wall-clock-as-UTC (the dive-time frame;
  /// see `NoFlyService.wallClockNowUtc`), so comparing their calendar
  /// components directly is correct.
  static double currentOtuDaily({
    required double dailyOtu,
    required DateTime computedAt,
    required DateTime now,
  }) {
    final sameDay =
        now.year == computedAt.year &&
        now.month == computedAt.month &&
        now.day == computedAt.day;
    return sameDay ? dailyOtu : 0.0;
  }
}
