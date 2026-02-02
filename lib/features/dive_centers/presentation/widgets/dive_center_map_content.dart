import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

/// Map content widget for displaying dive centers on a map.
///
/// Designed to be embedded in the master-detail right pane when map view is
/// active. This widget handles:
/// - Loading dive centers from the provider
/// - Building the FlutterMap with clustered markers
/// - Showing info card overlay for selected center
/// - Handling marker and cluster taps
/// - Displaying loading/error states
class DiveCenterMapContent extends ConsumerStatefulWidget {
  /// Currently selected dive center ID (for highlighting marker).
  final String? selectedId;

  /// Callback when a marker is tapped.
  final void Function(String?) onItemSelected;

  /// Callback when info card details button is tapped.
  /// If null, navigates to dive center detail page.
  final void Function(String centerId)? onDetailsTap;

  const DiveCenterMapContent({
    super.key,
    this.selectedId,
    required this.onItemSelected,
    this.onDetailsTap,
  });

  @override
  ConsumerState<DiveCenterMapContent> createState() =>
      _DiveCenterMapContentState();
}

class _DiveCenterMapContentState extends ConsumerState<DiveCenterMapContent>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(diveCenterListNotifierProvider);

    return centersAsync.when(
      data: (centers) => _buildMapWithInfoCard(context, centers),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildMapWithInfoCard(BuildContext context, List<DiveCenter> centers) {
    final selectedCenter = widget.selectedId != null
        ? centers.where((c) => c.id == widget.selectedId).firstOrNull
        : null;

    return Stack(
      children: [
        _buildMap(context, centers),
        if (selectedCenter != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildMapInfoCard(context, selectedCenter),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMap(BuildContext context, List<DiveCenter> centers) {
    // Filter centers with valid coordinates
    final centersWithLocation = centers.where((c) {
      if (!c.hasCoordinates) return false;
      final lat = c.latitude!;
      final lng = c.longitude!;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate initial bounds if we have centers
    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (centersWithLocation.isNotEmpty) {
      final bounds = _calculateBounds(centersWithLocation);
      center = LatLng(
        (bounds.north + bounds.south) / 2,
        (bounds.east + bounds.west) / 2,
      );
      // Start at a reasonable zoom
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
                markers: centersWithLocation.map((diveCenter) {
                  final isSelected = widget.selectedId == diveCenter.id;
                  return Marker(
                    point: LatLng(diveCenter.latitude!, diveCenter.longitude!),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () => _onMarkerTapped(diveCenter),
                      child: _buildMarker(context, diveCenter, isSelected),
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
          ],
        ),

        // Empty state overlay
        if (centersWithLocation.isEmpty)
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
                      'No dive centers with coordinates',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add coordinates to your dive centers to see them on the map',
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

  Widget _buildMapInfoCard(BuildContext context, DiveCenter center) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(diveCenterDiveCountProvider(center.id));

    String subtitle = center.fullLocationString ?? '';
    final diveCount = diveCountAsync.valueOrNull;
    if (diveCount != null && diveCount > 0) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '$diveCount ${diveCount == 1 ? 'dive' : 'dives'}';
    }
    if (center.rating != null) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += '\u2605 ${center.rating!.toStringAsFixed(1)}';
    }
    if (center.affiliations.isNotEmpty) {
      subtitle += subtitle.isNotEmpty ? ' \u2022 ' : '';
      subtitle += center.affiliationsDisplay;
    }

    return MapInfoCard(
      title: center.name,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.store, color: colorScheme.primary),
      ),
      onDetailsTap: widget.onDetailsTap != null
          ? () => widget.onDetailsTap!(center.id)
          : () => context.push('/dive-centers/${center.id}'),
    );
  }

  Widget _buildMarker(
    BuildContext context,
    DiveCenter center,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = _getMarkerColor(context, center.rating);

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
          Icons.store,
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

  Color _getMarkerColor(BuildContext context, double? rating) {
    // Color based on rating (1-5 stars)
    if (rating != null) {
      if (rating >= 4.5) return Colors.green.shade700;
      if (rating >= 4.0) return Colors.green.shade500;
      if (rating >= 3.0) return Colors.blue.shade500;
      if (rating >= 2.0) return Colors.orange.shade500;
      return Colors.red.shade500;
    }
    // Default color for unrated centers
    return Colors.blue.shade400;
  }

  void _onMarkerTapped(DiveCenter center) {
    if (widget.selectedId == center.id) {
      widget.onItemSelected(null);
    } else {
      widget.onItemSelected(center.id);
      _mapController.move(
        LatLng(center.latitude!, center.longitude!),
        _mapController.camera.zoom,
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

  LatLngBounds _calculateBounds(List<DiveCenter> centers) {
    double minLat = 90, maxLat = -90;
    double minLng = 180, maxLng = -180;

    for (final center in centers) {
      if (center.hasCoordinates) {
        final lat = center.latitude!;
        final lng = center.longitude!;

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
          Text('Error loading dive centers: $error'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(diveCenterListNotifierProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
