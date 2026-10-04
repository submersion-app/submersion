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
  final lastDive = await repository.getMostRecentDiveTimes(
    diverId: diverId,
    notAfter: now,
  );
  if (lastDive == null) return null;

  // Independent lookups, run concurrently rather than one after the other.
  final (analysis, weeklyOtu) = await (
    ref.watch(profileAnalysisProvider(lastDive.id).future),
    _currentWeeklyOtu(ref, repository, diverId, now),
  ).wait;
  if (analysis == null) return null;

  _scheduleMidnightRefresh(ref, now);

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
) async {
  final endOfDay = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

  final weekDives = await repository.getDiveTimesInRange(
    sevenDaysAgo,
    endOfDay,
    diverId: diverId,
  );

  double total = 0.0;
  for (final dive in weekDives) {
    // Read (not watch) to avoid cascading Riverpod invalidations, matching
    // the lookback pattern in profile_analysis_provider.dart.
    final analysis = await ref.read(profileAnalysisProvider(dive.id).future);
    if (analysis != null) total += analysis.o2Exposure.otu;
  }
  return total;
}

/// The weekly total above is only recomputed when this provider itself
/// reruns. Nothing writes to the dive table when a day simply ends, so
/// without this the 7-day window would keep showing a dive that has aged out
/// of it until the diver's next dive-table write. Mirrors
/// [noFlyStatusProvider]'s self-scheduled expiry, but on a day boundary
/// rather than a fixed guideline deadline.
void _scheduleMidnightRefresh(Ref ref, DateTime now) {
  final nextMidnight = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  final untilMidnight = nextMidnight.difference(now);
  final timer = Timer(
    untilMidnight + const Duration(seconds: 1),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
}
