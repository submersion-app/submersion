import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';

/// Whether a dive or Insights filter reads the service-due cache (#2365):
/// a query naming `gear.serviceDue`. Only these two: the paged dive list is
/// a notifier that re-runs on the cache table's tick rather than holding
/// the writer, and Insights stays filtered while its tab is away. The site,
/// trip and equipment id sets hold the writer themselves exactly while their
/// list is shown, so a filter left on those does not keep clocks running.
final serviceStatusDemandProvider = Provider<bool>((ref) {
  bool reads(Set<String> tables) => tables.contains(serviceStatusTable);
  return reads(diveFilterTablesTouched(ref.watch(diveFilterProvider))) ||
      reads(diveFilterTablesTouched(ref.watch(insightsFilterProvider)));
});

/// Keeps the service-due cache writer running while [serviceStatusDemandProvider]
/// says a filter reads it, and idle otherwise. The app root listens to this
/// all session; readers that can wait also await the write themselves
/// ([awaitServiceStatusIfRead]).
final serviceStatusKeeperProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(serviceStatusDemandProvider)) return;
  await ref.watch(equipmentServiceStatusCacheProvider.future);
});
