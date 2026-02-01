import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';

class DiveCenterMapPage extends ConsumerStatefulWidget {
  const DiveCenterMapPage({super.key});

  @override
  ConsumerState<DiveCenterMapPage> createState() => _DiveCenterMapPageState();
}

class _DiveCenterMapPageState extends ConsumerState<DiveCenterMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  DiveCenter? _selectedCenter;

  // Default to a nice ocean view (Pacific)
  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(diveCenterListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Centers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'List View',
            onPressed: () => context.go('/dive-centers'),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Fit All Centers',
            onPressed: () => _fitAllCenters(centersAsync.value ?? []),
          ),
        ],
      ),
      body: centersAsync.when(
        data: (centers) => _buildMap(context, centers),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
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
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dive-centers/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Center'),
      ),
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
              setState(() => _selectedCenter = null);
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
                  final isSelected = _selectedCenter?.id == diveCenter.id;
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

        // Center info card at bottom
        if (_selectedCenter != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: _buildCenterInfoCard(context, _selectedCenter!),
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

  Widget _buildCenterInfoCard(BuildContext context, DiveCenter center) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(diveCenterDiveCountProvider(center.id));

    return Card(
      elevation: 8,
      child: InkWell(
        onTap: () => context.push('/dive-centers/${center.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.store, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      center.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (center.fullLocationString != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        center.fullLocationString!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (center.affiliations.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        center.affiliationsDisplay,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (center.rating != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          center.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  diveCountAsync.when(
                    data: (count) => Text(
                      '$count ${count == 1 ? 'dive' : 'dives'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMarkerTapped(DiveCenter center) {
    setState(() {
      _selectedCenter = _selectedCenter?.id == center.id ? null : center;
    });

    if (_selectedCenter != null) {
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

  void _fitAllCenters(List<DiveCenter> centers) {
    // Filter centers with valid coordinates
    final centersWithLocation = centers.where((c) {
      if (!c.hasCoordinates) return false;
      final lat = c.latitude!;
      final lng = c.longitude!;
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    }).toList();

    if (centersWithLocation.isEmpty) return;

    if (centersWithLocation.length == 1) {
      final center = centersWithLocation.first;
      _mapController.move(LatLng(center.latitude!, center.longitude!), 12.0);
      return;
    }

    final bounds = _calculateBounds(centersWithLocation);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
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
}
