import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

/// Provider for dive activity heat map data.
/// Groups dives by site location and weights by dive count.
/// Respects the current dive filter settings.
final diveActivityHeatMapProvider = Provider<AsyncValue<List<HeatMapPoint>>>((
  ref,
) {
  final divesAsync = ref.watch(sortedFilteredDivesProvider);

  return divesAsync.whenData((dives) {
    // Group dives by site ID and count
    final siteCountMap = <String, int>{};
    final siteLocationMap = <String, LatLng>{};
    final siteNameMap = <String, String>{};

    for (final dive in dives) {
      // Skip dives without a site or coordinates
      if (dive.site == null || !dive.site!.hasCoordinates) continue;

      final site = dive.site!;
      final siteId = site.id;
      siteCountMap[siteId] = (siteCountMap[siteId] ?? 0) + 1;

      // Store location and name if not already stored
      if (!siteLocationMap.containsKey(siteId)) {
        siteLocationMap[siteId] = LatLng(
          site.location!.latitude,
          site.location!.longitude,
        );
        siteNameMap[siteId] = site.name;
      }
    }

    // Convert to heat map points
    return siteCountMap.entries.map((entry) {
      final location = siteLocationMap[entry.key]!;
      return HeatMapPoint(
        location: location,
        weight: entry.value.toDouble(),
        label: siteNameMap[entry.key],
      );
    }).toList();
  });
});

/// Provider for site coverage heat map data.
/// Shows all sites with coordinates, weighted by rating.
final siteCoverageHeatMapProvider = FutureProvider<List<HeatMapPoint>>((
  ref,
) async {
  final sitesWithCounts = await ref.watch(sitesWithCountsProvider.future);

  return sitesWithCounts.where((s) => s.site.hasCoordinates).map((s) {
    // Weight by rating if available, otherwise equal weight
    final weight = s.site.rating ?? 1.0;
    return HeatMapPoint(
      location: LatLng(s.site.location!.latitude, s.site.location!.longitude),
      weight: weight,
      label: s.site.name,
    );
  }).toList();
});

/// State for heat map display settings.
class HeatMapSettings {
  final double opacity;
  final double radius;
  final bool isVisible;

  const HeatMapSettings({
    this.opacity = 0.6,
    this.radius = 30.0,
    this.isVisible = true,
  });

  HeatMapSettings copyWith({double? opacity, double? radius, bool? isVisible}) {
    return HeatMapSettings(
      opacity: opacity ?? this.opacity,
      radius: radius ?? this.radius,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

/// Provider for heat map display settings.
final heatMapSettingsProvider = StateProvider<HeatMapSettings>((ref) {
  return const HeatMapSettings();
});

/// Combined provider that returns the active heat map data based on settings.
/// Can be extended to support different heat map types.
enum HeatMapType { diveActivity, siteCoverage }

/// Provider for selecting the active heat map type.
final activeHeatMapTypeProvider = StateProvider<HeatMapType>((ref) {
  return HeatMapType.diveActivity;
});

/// Provider for the currently active heat map data.
final activeHeatMapDataProvider = Provider<AsyncValue<List<HeatMapPoint>>>((
  ref,
) {
  final heatMapType = ref.watch(activeHeatMapTypeProvider);

  switch (heatMapType) {
    case HeatMapType.diveActivity:
      return ref.watch(diveActivityHeatMapProvider);
    case HeatMapType.siteCoverage:
      final siteCoverageAsync = ref.watch(siteCoverageHeatMapProvider);
      return siteCoverageAsync;
  }
});
