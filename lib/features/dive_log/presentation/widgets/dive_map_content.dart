import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// Map content widget for displaying dives on a map.
///
/// Designed to be embedded in the master-detail right pane when map view is
/// active. This widget handles:
/// - Loading sites with dive counts from the provider
/// - Building the FlutterMap with clustered markers (by site)
/// - Showing info card overlay for selected dive
/// - Handling marker and cluster taps
/// - Displaying loading/error states
/// - Optional heat map overlay
class DiveMapContent extends ConsumerStatefulWidget {
  /// Currently selected dive ID (for highlighting marker and info card).
  final String? selectedId;

  /// Callback when a marker is tapped.
  final void Function(String?) onItemSelected;

  /// Callback when info card details button is tapped.
  /// If null, navigates to dive detail page.
  final void Function(String diveId)? onDetailsTap;

  const DiveMapContent({
    super.key,
    this.selectedId,
    required this.onItemSelected,
    this.onDetailsTap,
  });

  @override
  ConsumerState<DiveMapContent> createState() => _DiveMapContentState();
}

class _DiveMapContentState extends ConsumerState<DiveMapContent>
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

    // Find selected dive from divesAsync using widget.selectedId
    final selectedDive = divesAsync.whenOrNull(
      data: (dives) {
        if (widget.selectedId == null) return null;
        final match = dives.where((d) => d.id == widget.selectedId);
        return match.isNotEmpty ? match.first : null;
      },
    );

    return sitesAsync.when(
      data: (sitesWithCounts) => _buildMapWithInfoCard(
        context,
        sitesWithCounts,
        heatMapAsync,
        settings,
        selectedDive,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildMapWithInfoCard(
    BuildContext context,
    List<SiteWithDiveCount> sitesWithCounts,
    AsyncValue<List<HeatMapPoint>> heatMapAsync,
    HeatMapSettings settings,
    Dive? selectedDive,
  ) {
    return Stack(
      children: [
        _buildMap(context, sitesWithCounts, heatMapAsync, settings),
        // Heat map toggle control
        Positioned(
          top: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HeatMapToggleButton(),
                  IconButton(
                    icon: const Icon(Icons.my_location, size: 20),
                    tooltip: 'Fit All Sites',
                    onPressed: () => _fitAllSites(
                      sitesWithCounts.map((s) => s.site).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectedDive != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildMapInfoCard(context, selectedDive),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<SiteWithDiveCount> sitesWithCounts,
    AsyncValue<List<HeatMapPoint>> heatMapAsync,
    HeatMapSettings settings,
  ) {
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
    final selectedSiteId = _getSelectedSiteId(widget.selectedId);

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
              widget.onItemSelected(null);
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
                  return _buildClusterMarker(context, markers.length);
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

  Widget _buildMapInfoCard(BuildContext context, Dive dive) {
    final colorScheme = Theme.of(context).colorScheme;
    final appSettings = ref.read(settingsProvider);
    final units = UnitFormatter(appSettings);

    // Build title: Dive #N or date
    final diveNumber = dive.diveNumber;
    final title = diveNumber != null
        ? 'Dive #$diveNumber'
        : DateFormat.yMMMd().format(dive.dateTime);

    // Build subtitle with site name, depth, duration
    final parts = <String>[];
    if (dive.site != null) {
      parts.add(dive.site!.name);
    }
    if (dive.maxDepth != null) {
      parts.add(units.formatDepth(dive.maxDepth!));
    }
    if (dive.duration != null) {
      parts.add('${dive.duration!.inMinutes} min');
    }
    final subtitle = parts.isNotEmpty ? parts.join(' \u2022 ') : null;

    return MapInfoCard(
      title: title,
      subtitle: subtitle,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.scuba_diving, color: colorScheme.primary),
      ),
      onDetailsTap: widget.onDetailsTap != null
          ? () => widget.onDetailsTap!(dive.id)
          : () => context.push('/dives/${dive.id}'),
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
    // and select it
    final divesAsync = ref.read(sortedFilteredDivesProvider);
    divesAsync.whenData((dives) {
      final divesAtSite = dives.where((d) => d.site?.id == site.id);
      if (divesAtSite.isNotEmpty) {
        final firstDive = divesAtSite.first;
        if (widget.selectedId == firstDive.id) {
          widget.onItemSelected(null);
        } else {
          widget.onItemSelected(firstDive.id);
        }
      }
    });

    _mapController.move(
      LatLng(site.location!.latitude, site.location!.longitude),
      _mapController.camera.zoom,
    );
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

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading dive data: $error'),
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
    );
  }
}
