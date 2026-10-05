import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/entities/cns_otu_snapshot.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

/// Static inputs for the current diver's CNS/OTU readout, or null when
/// there is no executed dive on record.
///
/// Self-invalidates on dive-table writes (import, sync, edit), same pattern
/// as [noFlyStatusProvider]. The live CNS% is re-derived from this snapshot
/// on every UI tick by [CnsOtuLiveService] rather than cached, so pure
/// elapsed time never makes CNS% stale. [CnsOtuSnapshot.weeklyOtu] is a
/// summed total, not a formula -- it cannot be re-derived from a stale
/// snapshot the way CNS% can, so this provider also self-schedules a refetch
/// at the next local midnight, the only moment the rolling 7-day window can
/// change without a dive being written.
final cnsOtuSnapshotProvider = FutureProvider<CnsOtuSnapshot?>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());

  final diverId = ref.watch(currentDiverIdProvider);
  // No active diver yet (transient at startup, or a fresh install): report no
  // snapshot rather than folding every diver's dives into one readout.
  if (diverId == null) return null;

  // Dive end times are stored wall-clock-as-UTC, so the "at or before now"
  // bound must be evaluated in the same frame (see wallClockNowUtc's doc and
  // issue #2587 for why DateTime.now().toUtc() is wrong here).
  final now = NoFlyService.wallClockNowUtc();
  final nextMidnight = _nextMidnight(now);
  // Scheduled before the first await, while this ref is certainly live: a
  // dive write landing mid-build disposes it, and registering the timer's
  // onDispose afterwards would throw and leave the timer running.
  _scheduleMidnightRefresh(ref, now, nextMidnight);

  final lastDive = await repository.getMostRecentDiveTimes(
    diverId: diverId,
    notAfter: now,
  );
  if (lastDive == null) return null;

  // Independent lookups, run concurrently rather than one after the other.
  final (analysis, weeklyOtu) = await (
    ref.watch(profileAnalysisProvider(lastDive.id).future),
    _currentWeeklyOtu(ref, repository, diverId, now, nextMidnight),
  ).wait;
  if (analysis == null) return null;

  return CnsOtuSnapshot(
    lastDiveId: lastDive.id,
    lastDiveEnd: lastDive.effectiveExitTime,
    exposure: analysis.o2Exposure,
    weeklyOtu: weeklyOtu,
  );
});

/// Rolling 7-day OTU total ending "now", not a dive's own calendar day.
///
/// [weeklyOtuProvider] (profile_analysis_provider.dart) computes the window
/// relative to a specific dive's date -- correct for that dive's own detail
/// view, but wrong here: once "now" has moved past the last dive's day, that
/// total no longer reflects which dives are still inside the 7-day window.
/// This mirrors its DB query, anchored to [now] and scoped to [diverId]
/// instead.
Future<double> _currentWeeklyOtu(
  Ref ref,
  DiveRepository repository,
  String diverId,
  DateTime now,
  DateTime endOfDay,
) async {
  final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

  // Planner rows are excluded: a saved plan has not been dived.
  final weekDives = await repository.getExecutedDiveTimesInRange(
    sevenDaysAgo,
    endOfDay,
    diverId: diverId,
  );

  // The window runs to the end of today, so it can hold a dive that starts
  // later than now (logged ahead of time); its OTU has not been accrued yet.
  // The now-anchored form of weeklyOtuProvider's later-dive guard (#407).
  final accrued = weekDives.where(
    (dive) => !(dive.entryTime ?? dive.dateTime).isAfter(now),
  );

  // Read (not watch) to avoid cascading Riverpod invalidations, matching
  // the lookback pattern in profile_analysis_provider.dart. The analyses
  // are independent, so they are awaited together rather than one by one.
  final analyses = await Future.wait([
    for (final dive in accrued)
      ref.read(profileAnalysisProvider(dive.id).future),
  ]);
  return analyses.fold<double>(
    0.0,
    (total, analysis) => total + (analysis?.o2Exposure.otu ?? 0.0),
  );
}

/// Start of the calendar day after [now], in the same wall-clock-as-UTC
/// frame.
DateTime _nextMidnight(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));

/// The weekly total above is only recomputed when this provider itself
/// reruns. Nothing writes to the dive table when a day simply ends, so
/// without this the 7-day window would keep showing a dive that has aged out
/// of it until the diver's next dive-table write. Mirrors
/// [noFlyStatusProvider]'s self-scheduled expiry, but on a day boundary
/// rather than a fixed guideline deadline.
void _scheduleMidnightRefresh(Ref ref, DateTime now, DateTime nextMidnight) {
  final untilMidnight = nextMidnight.difference(now);
  final timer = Timer(
    untilMidnight + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
}
