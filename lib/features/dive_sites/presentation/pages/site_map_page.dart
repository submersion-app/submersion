import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

class SiteMapPage extends ConsumerStatefulWidget {
  const SiteMapPage({super.key});

  @override
  ConsumerState<SiteMapPage> createState() => _SiteMapPageState();
}

class _SiteMapPageState extends ConsumerState<SiteMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Default to a nice ocean view (Pacific)
  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final selectionState = ref.watch(mapListSelectionProvider('sites'));

    // Find selected site from sitesAsync using selectionState.selectedId
    final selectedSite = sitesAsync.whenOrNull(
      data: (sitesWithCounts) {
        if (selectionState.selectedId == null) return null;
        final match = sitesWithCounts.where(
          (s) => s.site.id == selectionState.selectedId,
        );
        return match.isNotEmpty ? match.first.site : null;
      },
    );

    return MapListScaffold(
      sectionKey: 'sites',
      title: 'Dive Sites',
      onBackPressed: () => context.go('/sites'),
      listPane: SiteListContent(
        showAppBar: false,
        isMapMode: true,
        selectedId: selectionState.selectedId,
        onItemTapForMap: (site) {
          if (site.hasCoordinates) {
            _animateToLocation(
              site.location!.latitude,
              site.location!.longitude,
            );
          }
        },
        onItemSelected: (id) {
          if (id != null) {
            ref.read(mapListSelectionProvider('sites').notifier).select(id);
          } else {
            ref.read(mapListSelectionProvider('sites').notifier).deselect();
          }
        },
      ),
      mapPane: sitesAsync.when(
        data: (sitesWithCounts) => _buildMap(context, sitesWithCounts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading sites: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(sitesWithCountsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      infoCard: selectedSite != null
          ? _buildMapInfoCard(context, selectedSite)
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sites/new'),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Site'),
      ),
      actions: [
        const HeatMapToggleButton(),
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'List View',
          onPressed: () => context.go('/sites'),
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

  Widget _buildMapInfoCard(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final sitesWithCounts = ref.read(sitesWithCountsProvider).value ?? [];
    final diveCount =
        sitesWithCounts
            .where((s) => s.site.id == site.id)
            .firstOrNull
            ?.diveCount ??
        0;

    String subtitle = site.locationString;
    if (diveCount > 0) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '$diveCount ${diveCount == 1 ? 'dive' : 'dives'}';
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
      onDetailsTap: () => context.push('/sites/${site.id}'),
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
  ) {
    final selectionState = ref.watch(mapListSelectionProvider('sites'));

    // Filter sites with valid coordinates (lat: -90 to 90, lng: -180 to 180)
    final sitesWithLocation = sitesWithCounts.where((s) {
      if (!s.site.hasCoordinates) return false;
      final lat = s.site.location!.latitude;
      final lng = s.site.location!.longitude;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate initial bounds if we have sites
    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (sitesWithLocation.isNotEmpty) {
      final bounds = _calculateBounds(
        sitesWithLocation.map((s) => s.site).toList(),
      );
      center = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
      // Start at a reasonable zoom
      zoom = 4.0;
    }

    final settings = ref.watch(heatMapSettingsProvider);

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
              ref.read(mapListSelectionProvider('sites').notifier).deselect();
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
            // Markers layer - always shown
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                size: const Size(50, 50),
                markers: sitesWithLocation.map((siteWithCount) {
                  final site = siteWithCount.site;
                  final diveCount = siteWithCount.diveCount;
                  final isSelected = selectionState.selectedId == site.id;
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
              Consumer(
                builder: (context, ref, child) {
                  final heatMapAsync = ref.watch(siteCoverageHeatMapProvider);

                  return heatMapAsync.when(
                    data: (points) => HeatMapLayer(
                      points: points,
                      radius: settings.radius,
                      opacity: settings.opacity,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
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
                      'No sites with coordinates',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add coordinates to your dive sites to see them on the map',
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
    final currentId = ref.read(mapListSelectionProvider('sites')).selectedId;
    if (currentId == site.id) {
      ref.read(mapListSelectionProvider('sites').notifier).deselect();
    } else {
      ref.read(mapListSelectionProvider('sites').notifier).select(site.id);
      // Smooth animate to the tapped marker location
      _animateToLocation(site.location!.latitude, site.location!.longitude);
    }
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
