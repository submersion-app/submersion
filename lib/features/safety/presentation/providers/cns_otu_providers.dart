import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/otu_window_totals.dart';
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
/// elapsed time never makes CNS% stale. The daily and weekly OTU totals are
/// sums, not formulas: they cannot be re-derived from a stale snapshot the
/// way CNS% can, so this provider also self-schedules a refetch at the next
/// local midnight, the only moment either window can move without a dive
/// being written.
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
  final (analysis, totals) = await (
    ref.watch(profileAnalysisProvider(lastDive.id).future),
    _currentOtuTotals(ref, repository, diverId, now, nextMidnight),
  ).wait;

  return CnsOtuSnapshot(
    lastDiveId: lastDive.id,
    lastDiveEnd: lastDive.effectiveExitTime,
    // Null when the last dive has no profile: the readout then warns that
    // its exposure is unknown rather than reporting "no load".
    exposure: analysis?.o2Exposure,
    dailyOtu: totals.daily,
    weeklyOtu: totals.weekly,
    computedAt: now,
  );
});

/// Today's OTU and the rolling 7-day OTU, both ending at the end of today.
///
/// [weeklyOtuProvider] anchors its window to a specific dive's date, which is
/// right for that dive's own detail view but not here: once "now" has moved
/// past the last dive's day, that window no longer reflects which dives are
/// still inside the 7 days. Both totals go through [sumOtuInWindow], so a
/// dive that crossed midnight counts only its part on each day.
Future<({double daily, double weekly})> _currentOtuTotals(
  Ref ref,
  DiveRepository repository,
  String diverId,
  DateTime now,
  DateTime endOfDay,
) async {
  final startOfDay = endOfDay.subtract(const Duration(days: 1));
  final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

  // Planner rows are excluded: a saved plan has not been dived.
  final weekDives = await repository.getExecutedDiveTimesInRange(
    sevenDaysAgo.subtract(otuWindowLookback),
    endOfDay,
    diverId: diverId,
  );

  // The window runs to the end of today, so it can hold a dive that starts
  // later than now (logged ahead of time); its OTU has not been accrued yet.
  // The now-anchored form of weeklyOtuProvider's later-dive guard (#407).
  final accrued = weekDives
      .where((dive) => !(dive.entryTime ?? dive.dateTime).isAfter(now))
      .toList();

  // Read (not watch) to avoid cascading Riverpod invalidations, matching
  // the lookback pattern in profile_analysis_provider.dart. Both sums read
  // the same keep-alive analyses, so the second reuses the first's results.
  Future<ProfileAnalysis?> analysisOf(String id) =>
      ref.read(profileAnalysisProvider(id).future);

  final (daily, weekly) = await (
    sumOtuInWindow(
      dives: accrued,
      from: startOfDay,
      to: endOfDay,
      analysisOf: analysisOf,
    ),
    sumOtuInWindow(
      dives: accrued,
      from: sevenDaysAgo,
      to: endOfDay,
      analysisOf: analysisOf,
    ),
  ).wait;
  return (daily: daily, weekly: weekly);
}

/// Start of the calendar day after [now], in the same wall-clock-as-UTC
/// frame.
DateTime _nextMidnight(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));

/// The OTU totals above are only recomputed when this provider itself
/// reruns. Nothing writes to the dive table when a day simply ends, so
/// without this the daily total would carry over and the 7-day window would
/// keep showing a dive that has aged out of it until the diver's next
/// dive-table write. Mirrors [noFlyStatusProvider]'s self-scheduled expiry,
/// but on a day boundary rather than a fixed guideline deadline.
void _scheduleMidnightRefresh(Ref ref, DateTime now, DateTime nextMidnight) {
  final untilMidnight = nextMidnight.difference(now);
  final timer = Timer(
    untilMidnight + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
}
