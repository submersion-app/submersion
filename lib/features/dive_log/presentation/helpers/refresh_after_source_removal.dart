import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// Re-reads everything that shows [diveId] once [sourceId] has left it, and
/// again once an Undo brings it back (issue #4393). Shared by the dive
/// page's Data Sources menu, the data quality inbox's Remove source and the
/// profile editor's Cleanup tab (#4972).
///
/// A source the chart was showing or overlaying stops being asked for, the
/// dive's findings, sensor summaries and derived metrics are recomputed, and
/// the dive's samples, sources, revisions and list rows are read again.
///
/// Takes the container rather than a ref: the removal finishes after a
/// confirmation the diver can leave the page during, and an Undo can run
/// after the page that started it is gone.
void refreshAfterSourceRemoval(
  ProviderContainer container, {
  required String diveId,
  required String sourceId,
}) {
  final active = container.read(activeDiveSourceProvider(diveId).notifier);
  if (active.state == sourceId) active.state = null;
  final overlays = container.read(overlaySourcesProvider(diveId).notifier);
  if (overlays.state.contains(sourceId)) {
    overlays.state = {...overlays.state}..remove(sourceId);
  }
  scheduleQualityScan([diveId]);
  scheduleSensorSummaryRefresh([diveId], force: true);
  scheduleDerivedMetricsRefresh([diveId], force: true);
  container
    ..invalidate(diveProvider(diveId))
    ..invalidate(diveProfileProvider(diveId))
    ..invalidate(sourceProfilesProvider(diveId))
    ..invalidate(diveDataSourcesProvider(diveId))
    // A promoted source starts the dive's revision lineage over.
    ..invalidate(profileSeriesHistoryProvider(diveId))
    ..invalidate(paginatedDiveListProvider)
    ..invalidate(divesProvider);
}
