import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';

class DiveCenterMapPage extends ConsumerStatefulWidget {
  const DiveCenterMapPage({super.key});

  @override
  ConsumerState<DiveCenterMapPage> createState() => _DiveCenterMapPageState();
}

class _DiveCenterMapPageState extends ConsumerState<DiveCenterMapPage>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Default to a nice ocean view (Pacific)
  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final centersAsync = ref.watch(diveCenterListNotifierProvider);
    final selectionState = ref.watch(mapListSelectionProvider('dive-centers'));

    // Find selected center from centersAsync using selectionState.selectedId
    final selectedCenter = centersAsync.whenOrNull(
      data: (centers) {
        if (selectionState.selectedId == null) return null;
        final match = centers.where((c) => c.id == selectionState.selectedId);
        return match.isNotEmpty ? match.first : null;
      },
    );

    return MapListScaffold(
      sectionKey: 'dive-centers',
      title: context.l10n.diveCenters_title,
      onBackPressed: () => context.go('/dive-centers'),
      listPane: DiveCenterListContent(
        showAppBar: false,
        isMapMode: true,
        selectedId: selectionState.selectedId,
        onItemTapForMap: (center) {
          if (center.hasCoordinates) {
            _animateToLocation(center.latitude!, center.longitude!);
          }
        },
        onItemSelected: (id) {
          if (id != null) {
            ref
                .read(mapListSelectionProvider('dive-centers').notifier)
                .select(id);
          } else {
            ref
                .read(mapListSelectionProvider('dive-centers').notifier)
                .deselect();
          }
        },
      ),
      mapPane: centersAsync.when(
        data: (centers) => _buildMap(context, centers),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(context.l10n.diveCenters_error_loading(error.toString())),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(diveCenterListNotifierProvider.notifier).refresh(),
                child: Text(context.l10n.diveCenters_action_retry),
              ),
            ],
          ),
        ),
      ),
      infoCard: selectedCenter != null
          ? _buildMapInfoCard(context, selectedCenter)
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dive-centers/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.diveCenters_action_addCenter),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.list),
          tooltip: context.l10n.diveCenters_tooltip_listView,
          onPressed: () => context.go('/dive-centers'),
        ),
        IconButton(
          icon: const Icon(Icons.my_location),
          tooltip: context.l10n.diveCenters_tooltip_fitAllCenters,
          onPressed: () => _fitAllCenters(centersAsync.value ?? []),
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
      onDetailsTap: () => context.push('/dive-centers/${center.id}'),
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

  Widget _buildMap(BuildContext context, List<DiveCenter> centers) {
    final selectionState = ref.watch(mapListSelectionProvider('dive-centers'));

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
              ref
                  .read(mapListSelectionProvider('dive-centers').notifier)
                  .deselect();
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
                  final isSelected = selectionState.selectedId == diveCenter.id;
                  return Marker(
                    point: LatLng(diveCenter.latitude!, diveCenter.longitude!),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: Semantics(
                      button: true,
                      label: context.l10n.diveCenters_accessibility_markerLabel(
                        diveCenter.name,
                      ),
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(diveCenter),
                        child: _buildMarker(context, diveCenter, isSelected),
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
                      context.l10n.diveCenters_map_noCoordinates,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.diveCenters_map_addCoordinatesHint,
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

  void _onMarkerTapped(DiveCenter center) {
    final currentId = ref
        .read(mapListSelectionProvider('dive-centers'))
        .selectedId;
    if (currentId == center.id) {
      ref.read(mapListSelectionProvider('dive-centers').notifier).deselect();
    } else {
      ref
          .read(mapListSelectionProvider('dive-centers').notifier)
          .select(center.id);
      // Smooth animate to the tapped marker location
      _animateToLocation(center.latitude!, center.longitude!);
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
