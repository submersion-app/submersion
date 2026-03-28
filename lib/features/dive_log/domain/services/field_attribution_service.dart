import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// Computes field-level attribution for multi-source dives.
///
/// Returns a `Map<String, String>` where keys are field names (e.g., 'maxDepth')
/// and values are the display name of the source that provided the value.
/// Returns empty map for single-source dives (badges not shown).
class FieldAttributionService {
  /// HR-capable source formats (wearables with heart rate sensors).
  static const _hrCapableSources = {'appleWatch', 'garmin'};

  /// GPS-capable source formats.
  static const _gpsCapableSources = {'appleWatch', 'garmin'};

  static Map<String, String> computeAttribution(
    List<DiveDataSource> sources, {
    String? viewedSourceId,
  }) {
    if (sources.length < 2) return {};

    final activeSource = viewedSourceId != null
        ? sources.firstWhere(
            (s) => s.id == viewedSourceId,
            orElse: () => sources.firstWhere(
              (s) => s.isPrimary,
              orElse: () => sources.first,
            ),
          )
        : sources.firstWhere((s) => s.isPrimary, orElse: () => sources.first);

    final attribution = <String, String>{};
    final name = activeSource.displayName;

    // Standard fields — attributed to active (primary or viewed) source
    if (activeSource.maxDepth != null) attribution['maxDepth'] = name;
    if (activeSource.avgDepth != null) attribution['avgDepth'] = name;
    if (activeSource.duration != null) attribution['bottomTime'] = name;
    if (activeSource.waterTemp != null) attribution['waterTemp'] = name;
    if (activeSource.cns != null) attribution['cns'] = name;
    if (activeSource.otu != null) attribution['otu'] = name;
    if (activeSource.surfaceInterval != null) {
      attribution['surfaceInterval'] = name;
    }

    // Best-available: heart rate — prefer HR-capable source
    final hrSource = sources.firstWhere(
      (s) => _hrCapableSources.contains(s.sourceFormat),
      orElse: () => activeSource,
    );
    attribution['heartRate'] = hrSource.displayName;

    // Best-available: GPS — prefer GPS-capable source
    final gpsSource = sources.firstWhere(
      (s) => _gpsCapableSources.contains(s.sourceFormat),
      orElse: () => activeSource,
    );
    attribution['gps'] = gpsSource.displayName;

    return attribution;
  }
}
