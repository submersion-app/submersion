import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/planner/domain/services/plan_series_calculator.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

/// A repetitive series taken as a whole (issue #3565).
class SeriesSummary {
  /// Dives and the surface intervals between them, in seconds.
  final int totalSeconds;

  /// The highest CNS% any dive ends on.
  final double highestCns;

  /// The highest rolling 24-hour OTU any dive reaches.
  final double dailyOtu;

  /// How long to wait after the last dive before flying.
  final Duration noFlyWait;

  /// When that wait ends, as clock digits stamped UTC; null when the series
  /// has no start to count from.
  final DateTime? noFlyUntil;

  const SeriesSummary({
    required this.totalSeconds,
    required this.highestCns,
    required this.dailyOtu,
    required this.noFlyWait,
    this.noFlyUntil,
  });
}

/// The summary of a computed series of at least one dive. The no-fly wait is
/// the published interval for repetitive diving, or for deco when any dive
/// has stops, not a tissue calculation, the same as the rest of the app.
SeriesSummary seriesSummary(
  List<SeriesDiveResult> results, {
  required NoFlyPreset preset,
}) {
  var total = 0;
  var cns = 0.0;
  var otu = 0.0;
  var deco = false;
  for (final (index, result) in results.indexed) {
    final outcome = result.outcome;
    if (index > 0) total += result.state.surfaceInterval?.inSeconds ?? 0;
    total += outcome.runtimeSeconds;
    if (outcome.cnsEnd > cns) cns = outcome.cnsEnd;
    if (outcome.otuTotal > otu) otu = outcome.otuTotal;
    deco = deco || outcome.stops.isNotEmpty;
  }

  final wait = NoFlyService.intervalFor(
    preset,
    deco ? NoFlyCategory.deco : NoFlyCategory.repetitive,
  );
  final last = results.last;
  final start = last.state.startDateTime;
  return SeriesSummary(
    totalSeconds: total,
    highestCns: cns,
    dailyOtu: otu,
    noFlyWait: wait,
    noFlyUntil: start == null
        ? null
        : asWallClockUtc(
            fromWallClockUtc(
              start,
            ).add(Duration(seconds: last.outcome.runtimeSeconds)).add(wait),
          ),
  );
}
