import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_import/data/services/dive_health_metrics_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_health_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

/// Reads heart rate, recovery and sleep from Apple Health onto dives (issue
/// #637), or null where Health is not available. It does nothing while the
/// switch is off.
// no-tick: builds the DiveHealthMetricsService SERVICE, not a query result;
// every read happens when it runs.
final diveHealthMetricsServiceProvider = Provider<DiveHealthMetricsService?>((
  ref,
) {
  final health = ref.watch(healthImportServiceProvider);
  if (health == null) return null;
  return DiveHealthMetricsService(
    health: health,
    dives: ref.watch(diveRepositoryProvider),
    records: ref.watch(diveHealthRecordRepositoryProvider),
    metricsDiverId: () => ref.read(healthSettingsProvider).metricsDiverId,
  );
});
