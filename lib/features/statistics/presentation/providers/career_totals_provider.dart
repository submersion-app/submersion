import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';

/// Lifetime career totals for every surface that shows an unfiltered "total
/// dives": app-logged dives combined with the active diver's manually entered
/// prior-experience offset (issue #331).
///
/// Reads [diveStatisticsProvider], the UNFILTERED totals -- not
/// `filteredDiveStatisticsProvider` -- so a filter set on the Statistics tab
/// never leaks into the home dashboard.
///
/// Before this existed, only the Statistics overview combined the two, so the
/// home hero header and the milestones card reported a smaller total than the
/// Statistics page for any diver with a pre-app logbook (issue #808).
final careerTotalsProvider = FutureProvider<CareerTotals>((ref) async {
  // Both watches happen synchronously, before either await: the two reads are
  // independent, so this lets them resolve in parallel and registers both
  // dependencies without crossing an async gap.
  final statsFuture = ref.watch(diveStatisticsProvider.future);
  final diverFuture = ref.watch(currentDiverProvider.future);

  final stats = await statsFuture;
  final diver = await diverFuture;

  return CareerTotals.from(
    loggedDives: stats.totalDives,
    loggedTimeSeconds: stats.totalTimeSeconds,
    firstLoggedDive: stats.firstDiveDate,
    priorDives: diver?.priorDiveCount,
    priorTimeSeconds: diver?.priorDiveTimeSeconds,
    divingSince: diver?.divingSince,
  );
});
