import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

/// Page showing heat map of dive activity with site markers.
///
/// Displays a world map with clustered markers for dive sites and an optional
/// heat map overlay showing dive frequency. Uses [diveActivityHeatMapProvider]
/// which weights points by dive count per site.
class DiveActivityMapPage extends ConsumerStatefulWidget {
  const DiveActivityMapPage({super.key});

  @override
  ConsumerState<DiveActivityMapPage> createState() =>
      _DiveActivityMapPageState();
}

class _DiveActivityMapPageState extends ConsumerState<DiveActivityMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Default to a world view
  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;

  @override
  Widget build(BuildContext context) {
    final heatMapAsync = ref.watch(diveActivityHeatMapProvider);
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final divesAsync = ref.watch(sortedFilteredDivesProvider);
    final settings = ref.watch(heatMapSettingsProvider);
    final selectionState = ref.watch(mapListSelectionProvider('dives'));

    // Find selected dive from divesAsync using selectionState.selectedId
    final selectedDive = divesAsync.whenOrNull(
      data: (dives) {
        if (selectionState.selectedId == null) return null;
        final match = dives.where((d) => d.id == selectionState.selectedId);
        return match.isNotEmpty ? match.first : null;
      },
    );

    return MapListScaffold(
      sectionKey: 'dives',
      title: 'Dive Activity',
      onBackPressed: () => context.go('/dives'),
      listPane: DiveListContent(
        showAppBar: false,
        isMapMode: true,
        selectedId: selectionState.selectedId,
        onItemTapForMap: (dive) {
          if (dive.siteLatitude != null && dive.siteLongitude != null) {
            _animateToLocation(dive.siteLatitude!, dive.siteLongitude!);
          }
        },
        onItemSelected: (id) {
          if (id != null) {
            ref.read(mapListSelectionProvider('dives').notifier).select(id);
          } else {
            ref.read(mapListSelectionProvider('dives').notifier).deselect();
          }
        },
      ),
      mapPane: sitesAsync.when(
        data: (sitesWithCounts) =>
            _buildMap(context, sitesWithCounts, heatMapAsync, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading data: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.invalidate(sitesWithCountsProvider);
                  ref.invalidate(diveActivityHeatMapProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      infoCard: selectedDive != null
          ? _buildMapInfoCard(context, selectedDive)
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dives/new'),
        icon: const Icon(Icons.add),
        label: const Text('Log Dive'),
      ),
      actions: [
        const HeatMapToggleButton(),
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'List View',
          onPressed: () => context.go('/dives'),
        ),
        IconButton(
          icon: const Icon(Icons.my_location),
          tooltip: 'Fit All Sites',
          onPressed: () =>
              _fitAllSites(sitesAsync.value?.map((s) => s.site).toList() ?? []),
        ),
      ],
    );
  }

  Widget _buildMapInfoCard(BuildContext context, Dive dive) {
    final colorScheme = Theme.of(context).colorScheme;
    final appSettings = ref.read(settingsProvider);
    final units = UnitFormatter(appSettings);

    // Title: Site name (matching DiveListTile)
    final title = dive.site?.name ?? 'Unknown Site';

    // Build subtitle with date, depth, duration, water temp (matching DiveListTile)
    final parts = <String>[];
    parts.add(units.formatDateTime(dive.dateTime));
    if (dive.maxDepth != null) {
      parts.add(units.formatDepth(dive.maxDepth!));
    }
    if (dive.duration != null) {
      parts.add('${dive.duration!.inMinutes} min');
    }
    if (dive.waterTemp != null) {
      parts.add(units.formatTemperature(dive.waterTemp));
    }
    final subtitle = parts.join(' \u2022 ');

    // Dive number for the leading badge (matching DiveListTile)
    final diveNumber = dive.diveNumber ?? 0;

    return MapInfoCard(
      title: title,
      subtitle: subtitle,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          '#$diveNumber',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      onDetailsTap: () => context.push('/dives/${dive.id}'),
    );
  }

  Future<void> _animateToLocation(double lat, double lng) async {
    final target = LatLng(lat, lng);
    final startCamera = _mapController.camera;
    final targetZoom = startCamera.zoom < 10 ? 12.0 : startCamera.zoom;

    final animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    animation.addListener(() {
      final t = animation.value;
      final animLat =
          startCamera.center.latitude +
          (target.latitude - startCamera.center.latitude) * t;
      final animLng =
          startCamera.center.longitude +
          (target.longitude - startCamera.center.longitude) * t;
      final zoom = startCamera.zoom + (targetZoom - startCamera.zoom) * t;
      _mapController.move(LatLng(animLat, animLng), zoom);
    });

    await animationController.forward();
    animationController.dispose();
  }

  Widget _buildMap(
    BuildContext context,
    List<SiteWithDiveCount> sitesWithCounts,
    AsyncValue<List<HeatMapPoint>> heatMapAsync,
    HeatMapSettings settings,
  ) {
    final selectionState = ref.watch(mapListSelectionProvider('dives'));

    // Filter sites with valid coordinates and at least one dive
    final sitesWithDives = sitesWithCounts.where((s) {
      if (!s.site.hasCoordinates) return false;
      if (s.diveCount == 0) return false;
      final lat = s.site.location!.latitude;
      final lng = s.site.location!.longitude;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate initial bounds if we have sites
    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (sitesWithDives.isNotEmpty) {
      final bounds = _calculateBounds(
        sitesWithDives.map((s) => s.site).toList(),
      );
      center = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
      // Start at a reasonable zoom
      zoom = 4.0;
    }

    // Get selected dive's site ID for highlighting
    final selectedSiteId = _getSelectedSiteId(selectionState.selectedId);

    // Build a lookup map from marker location to dive count for cluster summing
    final diveCountByLocation = <LatLng, int>{};
    for (final siteWithCount in sitesWithDives) {
      final site = siteWithCount.site;
      final point = LatLng(site.location!.latitude, site.location!.longitude);
      diveCountByLocation[point] = siteWithCount.diveCount;
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            minZoom: 2.0,
            maxZoom: 18.0,
            onTap: (_, _) {
              ref.read(mapListSelectionProvider('dives').notifier).deselect();
            },
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-90, -180),
                const LatLng(90, 180),
              ),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.submersion.app',
              maxZoom: 19,
              tileProvider: TileCacheService.instance.isInitialized
                  ? TileCacheService.instance.getTileProvider()
                  : null,
            ),
            // Markers layer - shows sites with dives
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                size: const Size(50, 50),
                markers: sitesWithDives.map((siteWithCount) {
                  final site = siteWithCount.site;
                  final diveCount = siteWithCount.diveCount;
                  final isSelected = selectedSiteId == site.id;
                  return Marker(
                    point: LatLng(
                      site.location!.latitude,
                      site.location!.longitude,
                    ),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () => _onMarkerTapped(site),
                      child: _buildMarker(context, site, diveCount, isSelected),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  // Sum up dive counts for all markers in this cluster
                  final totalDives = markers.fold<int>(
                    0,
                    (sum, marker) =>
                        sum + (diveCountByLocation[marker.point] ?? 0),
                  );
                  return _buildClusterMarker(context, totalDives);
                },
                zoomToBoundsOnClick: false,
                onClusterTap: (node) {
                  // Animate to cluster bounds with generous padding
                  _animateToCluster(node.bounds);
                },
              ),
            ),
            // Heat map layer - rendered on top of markers when visible
            if (settings.isVisible)
              heatMapAsync.when(
                data: (points) => HeatMapLayer(
                  points: points,
                  radius: settings.radius,
                  opacity: settings.opacity,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
          ],
        ),

        // Loading indicator
        if (heatMapAsync.isLoading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),

        // Empty state
        if (sitesWithDives.isEmpty)
          Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.scuba_diving,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No dive activity to display',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log dives with location data to see your activity on the map',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Get the site ID for the currently selected dive
  String? _getSelectedSiteId(String? selectedDiveId) {
    if (selectedDiveId == null) return null;
    final divesAsync = ref.read(sortedFilteredDivesProvider);
    return divesAsync.whenOrNull(
      data: (dives) {
        final match = dives.where((d) => d.id == selectedDiveId);
        if (match.isEmpty) return null;
        return match.first.site?.id;
      },
    );
  }

  Widget _buildMarker(
    BuildContext context,
    DiveSite site,
    int diveCount,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = _getMarkerColor(diveCount);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : markerColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.onPrimary : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          diveCount.toString(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSelected ? 14 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildClusterMarker(BuildContext context, int count) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: TextStyle(
            color: colorScheme.onSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getMarkerColor(int diveCount) {
    // Color intensity based on dive count
    if (diveCount >= 20) return Colors.red.shade700;
    if (diveCount >= 10) return Colors.orange.shade700;
    if (diveCount >= 5) return Colors.amber.shade700;
    if (diveCount >= 3) return Colors.blue.shade700;
    return Colors.blue.shade500;
  }

  void _onMarkerTapped(DiveSite site) {
    // When a site marker is tapped, find the first dive at that site
    // and select it in the list
    final divesAsync = ref.read(sortedFilteredDivesProvider);
    divesAsync.whenData((dives) {
      final divesAtSite = dives.where((d) => d.site?.id == site.id);
      if (divesAtSite.isNotEmpty) {
        final firstDive = divesAtSite.first;
        final currentId = ref
            .read(mapListSelectionProvider('dives'))
            .selectedId;
        if (currentId == firstDive.id) {
          ref.read(mapListSelectionProvider('dives').notifier).deselect();
        } else {
          ref
              .read(mapListSelectionProvider('dives').notifier)
              .select(firstDive.id);
        }
      }
    });

    // Smooth animate to the tapped marker location
    _animateToLocation(site.location!.latitude, site.location!.longitude);
  }

  Future<void> _animateToCluster(LatLngBounds bounds) async {
    // Calculate target camera position
    final targetCamera = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(120),
      maxZoom: 14.0,
    ).fit(_mapController.camera);

    final startCamera = _mapController.camera;
    final animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );

    animation.addListener(() {
      final t = animation.value;
      final lat =
          startCamera.center.latitude +
          (targetCamera.center.latitude - startCamera.center.latitude) * t;
      final lng =
          startCamera.center.longitude +
          (targetCamera.center.longitude - startCamera.center.longitude) * t;
      final zoom =
          startCamera.zoom + (targetCamera.zoom - startCamera.zoom) * t;

      _mapController.move(LatLng(lat, lng), zoom);
    });

    await animationController.forward();
    animationController.dispose();
  }

  void _fitAllSites(List<DiveSite> sites) {
    // Filter sites with valid coordinates
    final sitesWithLocation = sites.where((s) {
      if (!s.hasCoordinates) return false;
      final lat = s.location!.latitude;
      final lng = s.location!.longitude;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();

    if (sitesWithLocation.isEmpty) return;

    if (sitesWithLocation.length == 1) {
      final site = sitesWithLocation.first;
      _mapController.move(
        LatLng(site.location!.latitude, site.location!.longitude),
        12.0,
      );
      return;
    }

    final bounds = _calculateBounds(sitesWithLocation);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  LatLngBounds _calculateBounds(List<DiveSite> sites) {
    double minLat = 90, maxLat = -90;
    double minLng = 180, maxLng = -180;

    for (final site in sites) {
      if (site.location != null) {
        final lat = site.location!.latitude;
        final lng = site.location!.longitude;

        // Skip invalid coordinates
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          continue;
        }

        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    // Clamp bounds to valid coordinate ranges
    final south = (minLat - latPadding).clamp(-90.0, 90.0);
    final north = (maxLat + latPadding).clamp(-90.0, 90.0);
    final west = (minLng - lngPadding).clamp(-180.0, 180.0);
    final east = (maxLng + lngPadding).clamp(-180.0, 180.0);

    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }
}
