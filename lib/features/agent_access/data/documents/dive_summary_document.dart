import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// The compact, agent-facing row for a dive. Metric, unit-named keys.
Map<String, Object?> diveSummaryDocument(DiveSummary s) {
  return {
    'id': s.id,
    'dive_number': s.diveNumber,
    'name': s.name,
    'date_time': s.dateTime.toIso8601String(),
    'max_depth_m': s.maxDepth,
    'bottom_time_s': s.bottomTime?.inSeconds,
    'runtime_s': s.runtime?.inSeconds,
    'water_temp_c': s.waterTemp,
    'rating': s.rating,
    'is_favorite': s.isFavorite,
    'excluded_from_stats': s.excludedFromStats,
    'is_planned': s.isPlanned,
    'dive_mode': s.diveMode.name,
    'site_name': s.siteName,
    'site_country': s.siteCountry,
    'trip_id': s.tripId,
    'trip_name': s.tripName,
    'tags': [for (final tag in s.tags) tag.name],
    'safety_finding_count': s.safetyFindingCount,
  };
}
