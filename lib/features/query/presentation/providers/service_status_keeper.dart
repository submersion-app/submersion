import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_filter_query.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_service_status_providers.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/query/query_tables_touched.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/query/trip_filter_query.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

/// Whether any live filter reads the service-due cache (#2365): a dive,
/// Insights, site, trip or equipment query that names `serviceDue`, directly
/// or through a relation (`gear.serviceDue`, `dives.gear.serviceDue`).
final serviceStatusDemandProvider = Provider<bool>((ref) {
  bool reads(Set<String> tables) => tables.contains(serviceStatusTable);
  return reads(diveFilterTablesTouched(ref.watch(diveFilterProvider))) ||
      reads(diveFilterTablesTouched(ref.watch(insightsFilterProvider))) ||
      reads(
        tablesTouchedOrRoot(
          ref.watch(siteFilterProvider).toQuery(),
          siteQueryEntity,
        ),
      ) ||
      reads(
        tablesTouchedOrRoot(
          ref.watch(tripFilterProvider).toQuery(),
          tripQueryEntity,
        ),
      ) ||
      reads(
        tablesTouchedOrRoot(
          ref.watch(equipmentFilterProvider).toQuery(),
          equipmentQueryEntity,
        ),
      );
});

/// Keeps the service-due cache writer running while [serviceStatusDemandProvider]
/// says a filter reads it, and idle otherwise. The app root listens to this
/// all session. Providers that can wait also await the write themselves
/// ([awaitServiceStatusIfRead]); this covers the list notifiers, which
/// re-run on the cache table's tick instead.
final serviceStatusKeeperProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(serviceStatusDemandProvider)) return;
  await ref.watch(equipmentServiceStatusCacheProvider.future);
});
