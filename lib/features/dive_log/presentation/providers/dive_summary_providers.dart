import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';

/// Overview totals for the Dive Log Summary pane, scoped by the dive list's
/// filter (issue #1078): the pane sits beside the list, so it describes the
/// dives the list shows. With no filter active it covers the whole log.
///
/// Kept apart from [diveStatisticsProvider], which the home dashboard and the
/// career totals read and which must stay lifetime, and from the Insights
/// tab's filtered totals, which follow that tab's own independent filter.
final diveListScopedStatisticsProvider = FutureProvider<DiveStatistics>((
  ref,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(diveFilterProvider);
  await _refreshOnFilterTables(ref, repository, filter);
  // "Dives This Year" reads the clock once per build (#2600), so a date
  // change has to rebuild it too.
  ref.invalidateSelfWhen(localDayChanges());
  return repository.getStatistics(diverId: currentDiverId, filter: filter);
});

/// Personal records for the Dive Log Summary pane, scoped by the dive list's
/// filter for the same reason as [diveListScopedStatisticsProvider]: a
/// deepest or longest dive the list has filtered out would contradict the
/// totals shown above it.
final diveListScopedRecordsProvider = FutureProvider<DiveRecords>((ref) async {
  final repository = ref.watch(diveRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(diveFilterProvider);
  await _refreshOnFilterTables(ref, repository, filter);
  return repository.getRecords(diverId: currentDiverId, filter: filter);
});

/// ONE debounced tick over every table the query reads (`dives` and the
/// `dive_sites` name join) plus every table [filter] joins (#2365), so a site
/// rename, or an attribute-only or junction-only write (a buddy link under a
/// buddy filter, a gear attribute under an attribute condition), refreshes
/// the summary once, never twice, and never leaves it stale.
Future<void> _refreshOnFilterTables(
  Ref ref,
  DiveRepository repository,
  DiveFilterState filter,
) async {
  final touched = diveFilterTablesTouched(filter);
  await awaitServiceStatusIfRead(ref, touched);
  ref.invalidateSelfWhen(
    repository.watchTables({
      ...DiveRepository.statisticsTickTables,
      ...touched,
    }),
  );
}
