import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/dive_site.dart';
import '../providers/site_providers.dart';

class SiteMapPage extends ConsumerStatefulWidget {
  const SiteMapPage({super.key});

  @override
  ConsumerState<SiteMapPage> createState() => _SiteMapPageState();
}

class _SiteMapPageState extends ConsumerState<SiteMapPage> {
  final MapController _mapController = MapController();
  DiveSite? _selectedSite;

  // Default to a nice ocean view (Pacific)
  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Sites Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'List View',
            onPressed: () => context.go('/sites'),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Fit All Sites',
            onPressed: () => _fitAllSites(sitesAsync.value ?? []),
          ),
        ],
      ),
      body: sitesAsync.when(
        data: (sites) => _buildMap(context, sites),
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
                onPressed: () => ref.invalidate(sitesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sites/new'),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Site'),
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<DiveSite> sites) {
    final sitesWithLocation = sites.where((s) => s.hasCoordinates).toList();
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate initial bounds if we have sites
    LatLng center = _defaultCenter;
    double zoom = _defaultZoom;

    if (sitesWithLocation.isNotEmpty) {
      final bounds = _calculateBounds(sitesWithLocation);
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
            onTap: (_, __) {
              setState(() => _selectedSite = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.submersion.app',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: sitesWithLocation.map((site) {
                final isSelected = _selectedSite?.id == site.id;
                return Marker(
                  point: LatLng(site.location!.latitude, site.location!.longitude),
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  child: GestureDetector(
                    onTap: () => _onMarkerTapped(site),
                    child: _buildMarker(context, site, isSelected),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Site info card at bottom
        if (_selectedSite != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 80,
            child: _buildSiteInfoCard(context, _selectedSite!),
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
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

  Widget _buildMarker(BuildContext context, DiveSite site, bool isSelected) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primary : colorScheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
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
          color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSiteInfoCard(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      child: InkWell(
        onTap: () => context.push('/sites/${site.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.location_on,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      site.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (site.locationString.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        site.locationString,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    if (site.maxDepth != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${site.maxDepth!.toStringAsFixed(0)}m max depth',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (site.rating != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text(
                          site.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
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

  void _onMarkerTapped(DiveSite site) {
    setState(() {
      _selectedSite = _selectedSite?.id == site.id ? null : site;
    });

    if (_selectedSite != null) {
      _mapController.move(
        LatLng(site.location!.latitude, site.location!.longitude),
        _mapController.camera.zoom,
      );
    }
  }

  void _fitAllSites(List<DiveSite> sites) {
    final sitesWithLocation = sites.where((s) => s.hasCoordinates).toList();
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
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  LatLngBounds _calculateBounds(List<DiveSite> sites) {
    double minLat = 90, maxLat = -90;
    double minLng = 180, maxLng = -180;

    for (final site in sites) {
      if (site.location != null) {
        final lat = site.location!.latitude;
        final lng = site.location!.longitude;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }
}
