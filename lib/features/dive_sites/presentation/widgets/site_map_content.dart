import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// Map content widget for displaying dive sites on a map.
///
/// Designed to be embedded in the master-detail right pane when map view is
/// active. This widget handles:
/// - Loading dive sites from the provider
/// - Building the FlutterMap with clustered markers
/// - Showing info card overlay for selected site
/// - Handling marker and cluster taps
/// - Displaying loading/error states
class SiteMapContent extends ConsumerStatefulWidget {
  /// Currently selected dive site ID (for highlighting marker).
  final String? selectedId;

  /// Callback when a marker is tapped.
  final void Function(String?) onItemSelected;

  /// Callback when info card details button is tapped.
  /// If null, navigates to dive site detail page.
  final void Function(String siteId)? onDetailsTap;

  const SiteMapContent({
    super.key,
    this.selectedId,
    required this.onItemSelected,
    this.onDetailsTap,
  });

  @override
  ConsumerState<SiteMapContent> createState() => _SiteMapContentState();
}

class _SiteMapContentState extends ConsumerState<SiteMapContent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  void didUpdateWidget(SiteMapContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When selectedId changes from an external source (e.g., list selection),
    // zoom the map to the selected site's location
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        _mapReady) {
      _zoomToSelectedSite(widget.selectedId!);
    }
  }

  /// Animate the map to center on the selected site's location
  void _zoomToSelectedSite(String siteId) {
    final sitesAsync = ref.read(sitesWithCountsProvider);
    sitesAsync.whenData((sitesWithCounts) {
      final siteWithCount = sitesWithCounts
          .where((s) => s.site.id == siteId)
          .firstOrNull;
      if (siteWithCount?.site.hasCoordinates == true) {
        final site = siteWithCount!.site;
        _animateToLocation(
          LatLng(site.location!.latitude, site.location!.longitude),
        );
      }
    });
  }

  /// Smoothly animate the map to a specific location
  Future<void> _animateToLocation(LatLng target) async {
    final startCamera = _mapController.camera;
    // Use a reasonable zoom level for viewing a single site
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
      final lat =
          startCamera.center.latitude +
          (target.latitude - startCamera.center.latitude) * t;
      final lng =
          startCamera.center.longitude +
          (target.longitude - startCamera.center.longitude) * t;
      final zoom = startCamera.zoom + (targetZoom - startCamera.zoom) * t;

      _mapController.move(LatLng(lat, lng), zoom);
    });

    await animationController.forward();
    animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final heatMapAsync = ref.watch(siteCoverageHeatMapProvider);
    final heatMapSettings = ref.watch(heatMapSettingsProvider);

    return sitesAsync.when(
      data: (sitesWithCounts) => _buildMapWithInfoCard(
        context,
        sitesWithCounts,
        heatMapAsync,
        heatMapSettings,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildMapWithInfoCard(
    BuildContext context,
    List<SiteWithDiveCount> sitesWithCounts,
    AsyncValue<List<HeatMapPoint>> heatMapAsync,
    HeatMapSettings heatMapSettings,
  ) {
    final selectedSite = widget.selectedId != null
        ? sitesWithCounts
              .where((s) => s.site.id == widget.selectedId)
              .firstOrNull
              ?.site
        : null;

    return Stack(
      children: [
        _buildMap(context, sitesWithCounts, heatMapAsync, heatMapSettings),
        // Heat map toggle and fit all sites controls
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
                    tooltip: context.l10n.diveSites_map_tooltip_fitAllSites,
                    onPressed: () => _fitAllSites(
                      sitesWithCounts.map((s) => s.site).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectedSite != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildMapInfoCard(
                  context,
                  selectedSite,
                  sitesWithCounts,
                ),
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
    HeatMapSettings heatMapSettings,
  ) {
    // Filter sites with valid coordinates
    final sitesWithLocation = sitesWithCounts.where((s) {
      if (!s.site.hasCoordinates) return false;
      final lat = s.site.location!.latitude;
      final lng = s.site.location!.longitude;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate initial center and zoom
    // If there's a selected site with location, start centered on it
    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (widget.selectedId != null) {
      // Find the selected site's location
      final selectedSite = sitesWithLocation
          .where((s) => s.site.id == widget.selectedId)
          .firstOrNull
          ?.site;
      if (selectedSite?.hasCoordinates == true) {
        center = LatLng(
          selectedSite!.location!.latitude,
          selectedSite.location!.longitude,
        );
        zoom = 12.0; // Reasonable zoom for viewing a single site
      }
    } else if (sitesWithLocation.isNotEmpty) {
      // No selection - fit all sites
      final bounds = _calculateBounds(
        sitesWithLocation.map((s) => s.site).toList(),
      );
      center = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
      zoom = 4.0;
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
            onMapReady: () {
              _mapReady = true;
            },
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
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                size: const Size(50, 50),
                markers: sitesWithLocation.map((siteWithCount) {
                  final site = siteWithCount.site;
                  final diveCount = siteWithCount.diveCount;
                  final isSelected = widget.selectedId == site.id;
                  return Marker(
                    point: LatLng(
                      site.location!.latitude,
                      site.location!.longitude,
                    ),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: Semantics(
                      button: true,
                      label: context.l10n
                          .diveSites_map_semantics_diveSiteMarker(site.name),
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(site),
                        child: _buildMarker(
                          context,
                          site,
                          diveCount,
                          isSelected,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                builder: (context, markers) {
                  return _buildClusterMarker(context, markers.length);
                },
                zoomToBoundsOnClick: false,
                onClusterTap: (node) {
                  _animateToCluster(node.bounds);
                },
              ),
            ),
            // Heat map layer - rendered on top of markers when visible
            if (heatMapSettings.isVisible)
              heatMapAsync.when(
                data: (points) => HeatMapLayer(
                  points: points,
                  radius: heatMapSettings.radius,
                  opacity: heatMapSettings.opacity,
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
          ],
        ),

        // Empty state overlay
        if (sitesWithLocation.isEmpty)
          Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.diveSites_map_empty_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.diveSites_map_empty_description,
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

  Widget _buildMapInfoCard(
    BuildContext context,
    DiveSite site,
    List<SiteWithDiveCount> sitesWithCounts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCount =
        sitesWithCounts
            .where((s) => s.site.id == site.id)
            .firstOrNull
            ?.diveCount ??
        0;

    String subtitle = site.locationString;
    if (diveCount > 0) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += context.l10n.diveSites_map_infoCard_diveCount(diveCount);
    }
    if (site.rating != null) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '\u2605 ${site.rating!.toStringAsFixed(1)}';
    }

    return MapInfoCard(
      title: site.name,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.location_on, color: colorScheme.primary),
      ),
      onDetailsTap: widget.onDetailsTap != null
          ? () => widget.onDetailsTap!(site.id)
          : () => context.push('/sites/${site.id}'),
    );
  }

  Widget _buildMarker(
    BuildContext context,
    DiveSite site,
    int diveCount,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = _getMarkerColor(context, diveCount, site.rating);

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
        child: Icon(
          Icons.scuba_diving,
          size: isSelected ? 24 : 20,
          color: Colors.white,
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

  Color _getMarkerColor(BuildContext context, int diveCount, double? rating) {
    // Priority: Use rating if available, otherwise use dive count
    if (rating != null) {
      // Color based on rating (1-5 stars)
      if (rating >= 4.5) return Colors.green.shade700;
      if (rating >= 4.0) return Colors.green.shade500;
      if (rating >= 3.0) return Colors.blue.shade500;
      if (rating >= 2.0) return Colors.orange.shade500;
      return Colors.red.shade500;
    }

    // Color based on dive count
    if (diveCount == 0) return Colors.grey.shade500;
    if (diveCount >= 10) return Colors.purple.shade700;
    if (diveCount >= 5) return Colors.blue.shade700;
    if (diveCount >= 3) return Colors.blue.shade500;
    return Colors.blue.shade300;
  }

  void _onMarkerTapped(DiveSite site) {
    if (widget.selectedId == site.id) {
      widget.onItemSelected(null);
    } else {
      widget.onItemSelected(site.id);
      // Smooth scroll to the tapped marker
      _animateToLocation(
        LatLng(site.location!.latitude, site.location!.longitude),
      );
    }
  }

  Future<void> _animateToCluster(LatLngBounds bounds) async {
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
          Text(
            context.l10n.diveSites_mapContent_error_loadingDiveSites(
              error.toString(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(sitesWithCountsProvider),
            child: Text(context.l10n.diveSites_map_error_retry),
          ),
        ],
      ),
    );
  }
}
