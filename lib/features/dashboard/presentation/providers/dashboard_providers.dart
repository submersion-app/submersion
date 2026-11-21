import 'package:clock/clock.dart';

import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

/// Recent dives shown on the home tab (newest 3).
///
/// Self-invalidates on any `dives`-table write -- a dive computer import or an
/// iCloud sync applying remote changes directly to the DB -- so the home tab
/// reflects new dives without an app restart (issue #217).
///
/// Discovery is SQL-bounded (`getDiveSummaries(limit: 3)`); the three
/// winners then load in one batched read that decodes no samples (issue
/// #4251), the way the trip lists read theirs. Home's recent dives are a
/// table and its profile panel reads the newest dive on its own, so nothing
/// here reads a profile (issue #4824). The dashboard no longer forces
/// `getAllDives()` on the first home frame (WS4, large-DB performance).
final recentDivesProvider = FutureProvider<List<Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  // Includes the buddy link tables: the cards show buddy names, and a rename
  // or a synced buddy link never restamps the dive row (#1769, #3039).
  ref.invalidateSelfWhen(repository.watchDivesChangesWithBuddyLinks());

  final currentDiverId = ref.watch(currentDiverIdProvider);
  final summaries = await repository.getDiveSummaries(
    diverId: currentDiverId,
    limit: 3,
  );
  return _diveRowsInOrder(repository, [
    for (final summary in summaries) summary.id,
  ]);
});

/// The dives [ids] name, in [ids]' order, for a card that lists them rather
/// than drawing them (issue #4251).
///
/// One batched read with no series decoded, buddies included (#3039), where
/// a `getDiveById` per dive decoded each one's merged profile and tank
/// pressures. Values the row leaves to its samples still come from them:
/// [DiveRepository.getDivesByIdsWithoutSamples] reads those dives in full,
/// decoding off the UI isolate as `getDiveById` did. Its own order is newest first, which can break a tie differently from
/// the query that picked [ids], so this keeps theirs. A dive deleted since
/// [ids] was read is left out.
Future<List<Dive>> _diveRowsInOrder(
  DiveRepository repository,
  List<String> ids,
) async {
  if (ids.isEmpty) return const [];
  final byId = {
    for (final dive in await repository.getDivesByIdsWithoutSamples(
      ids,
      offUiIsolate: true,
    ))
      dive.id: dive,
  };
  return [for (final id in ids) ?byId[id]];
}

/// Current diver provider (re-exported for convenience)
final dashboardDiverProvider = FutureProvider<Diver?>((ref) async {
  return ref.watch(currentDiverProvider.future);
});

/// Days since last dive provider. Today is read once per build, so midnight
/// must rebuild it too, or the count holds yesterday's answer.
final daysSinceLastDiveProvider = FutureProvider<int?>((ref) async {
  ref.invalidateSelfWhen(localDayChanges());
  final recentDives = await ref.watch(recentDivesProvider.future);
  if (recentDives.isEmpty) return null;

  final lastDive = recentDives.first.effectiveEntryTime;
  final now = clock.now();
  final diveDay = DateTime(lastDive.year, lastDive.month, lastDive.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(diveDay).inDays;
});

/// A GPS pin for the recent-sites mini map.
class RecentSitePin {
  final String? siteName;
  final double latitude;
  final double longitude;

  const RecentSitePin({
    required this.siteName,
    required this.latitude,
    required this.longitude,
  });
}

/// Distinct GPS-bearing sites among the last 10 dives.
final recentSitesProvider = FutureProvider<List<RecentSitePin>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final summaries = await repository.getDiveSummaries(
    diverId: currentDiverId,
    limit: 10,
  );
  final seen = <String>{};
  final pins = <RecentSitePin>[];
  for (final summary in summaries) {
    final lat = summary.siteLatitude;
    final lng = summary.siteLongitude;
    if (lat == null || lng == null) continue;
    // Dedupe on name + coordinates rather than coordinates alone, so two
    // distinct sites that happen to share a GPS fix (nearby or renamed
    // sites) both keep a pin. DiveSummary carries no site id to key on.
    if (seen.add('${summary.siteName}|$lat,$lng')) {
      pins.add(
        RecentSitePin(
          siteName: summary.siteName,
          latitude: lat,
          longitude: lng,
        ),
      );
    }
  }
  return pins;
});

/// This year vs last year, for the year-in-review card.
class YearInReview {
  final int year;
  final YearStats current;
  final YearStats previous;

  const YearInReview({
    required this.year,
    required this.current,
    required this.previous,
  });
}

/// This year vs last year. Null when both years are empty.
final yearInReviewProvider = FutureProvider<YearInReview?>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  // The year is read once per build, so New Year must rebuild it too.
  ref.invalidateSelfWhen(localDayChanges());
  final diverId = ref.watch(currentDiverIdProvider);
  final year = clock.now().year;
  final current = await repository.getYearStats(year, diverId: diverId);
  final previous = await repository.getYearStats(year - 1, diverId: diverId);
  if (current.diveCount == 0 && previous.diveCount == 0) return null;
  return YearInReview(year: year, current: current, previous: previous);
});

/// Dives from this month/day in prior years ("on this day").
final onThisDayProvider = FutureProvider<List<Dive>>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDivesChanges());
  // Today is read once per build, so midnight must rebuild it too.
  ref.invalidateSelfWhen(localDayChanges());
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final now = clock.now();
  final ids = await repository.getOnThisDayDiveIds(
    month: now.month,
    day: now.day,
    excludeYear: now.year,
    diverId: currentDiverId,
  );
  // The card shows year, site or name, depth and runtime: row values.
  return _diveRowsInOrder(repository, ids);
});
