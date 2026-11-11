import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';

/// Whether a dive or Insights filter reads the computed deco cache (#4461):
/// the Deco filter, or a query naming `deco`. Only these two, for the
/// reasons `serviceStatusDemandProvider` gives: the paged dive list is a
/// notifier that re-runs on the cache table's tick rather than holding the
/// writer, and Insights stays filtered while its tab is away. Every other
/// reader holds the writer itself while it is shown.
final diveDecoStatusDemandProvider = Provider<bool>((ref) {
  bool reads(Set<String> tables) => tables.contains(kDiveDecoStatusTable);
  return reads(diveFilterTablesTouched(ref.watch(diveFilterProvider))) ||
      reads(diveFilterTablesTouched(ref.watch(insightsFilterProvider)));
});

/// Keeps the computed deco cache writer running while
/// [diveDecoStatusDemandProvider] says a filter reads it, and idle
/// otherwise. The app root listens to this all session; readers that can
/// wait also await the write themselves (`awaitQueryCachesIfRead`).
final diveDecoStatusKeeperProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(diveDecoStatusDemandProvider)) return;
  await ref.watch(diveDecoStatusCacheProvider.future);
});
