import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
  late final MapCameraAnimator _camera = MapCameraAnimator(
    controller: _mapController,
    vsync: this,
  );
  bool _mapReady = false;

  // Default to a world view
  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DiveMapContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When selectedId changes from an external source (e.g., list selection),
    // zoom the map to the selected dive's location
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        _mapReady) {
      _zoomToSelectedDive(widget.selectedId!);
    }
  }

  /// Animate the map to center on the selected dive's site location
  void _zoomToSelectedDive(String diveId) {
    final divesAsync = ref.read(sortedFilteredDivesProvider);
    divesAsync.whenData((dives) {
      final dive = dives.where((d) => d.id == diveId).firstOrNull;
      if (dive?.site?.hasCoordinates == true) {
        final site = dive!.site!;
        _camera.animateTo(
          LatLng(site.location!.latitude, site.location!.longitude),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final heatMapAsync = ref.watch(diveActivityHeatMapProvider);
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

    // Derive sites with counts from the filtered dives
    // This ensures the map respects the current dive filter
    return divesAsync.when(
      data: (dives) {
        final sitesWithCounts = _extractSitesFromDives(dives);
        return _buildMapWithInfoCard(
          context,
          sitesWithCounts,
          heatMapAsync,
          settings,
          selectedDive,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  /// Extract unique sites with dive counts from the filtered dive list.
  /// This ensures the map only shows sites that have dives matching the current filter.
  List<SiteWithDiveCount> _extractSitesFromDives(List<Dive> dives) {
    final siteCountMap = <String, _SiteCounter>{};

    for (final dive in dives) {
      final site = dive.site;
      if (site != null) {
        if (siteCountMap.containsKey(site.id)) {
          siteCountMap[site.id]!.count++;
        } else {
          siteCountMap[site.id] = _SiteCounter(site: site, count: 1);
        }
      }
    }

    return siteCountMap.values
        .map(
          (counter) =>
              SiteWithDiveCount(site: counter.site, diveCount: counter.count),
        )
        .toList();
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
                    tooltip: context.l10n.diveLog_map_tooltip_fitAllSites,
                    onPressed: () => _camera.fitAll(
                      _sitePoints(sitesWithCounts.map((s) => s.site)),
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

    // Get selected dive's site ID for highlighting
    final selectedSiteId = _getSelectedSiteId(widget.selectedId);

    // A selected dive whose site has a location opens centred on it.
    final selectedSite = selectedSiteId == null
        ? null
        : sitesWithDives
              .where((s) => s.site.id == selectedSiteId)
              .firstOrNull
              ?.site;
    final selectedPoint = selectedSite?.hasCoordinates == true
        ? LatLng(
            selectedSite!.location!.latitude,
            selectedSite.location!.longitude,
          )
        : null;
    final center = selectedPoint ?? _defaultCenter;
    // Reasonable zoom for viewing a single site
    final zoom = selectedPoint != null ? 12.0 : _defaultZoom;
    // No selection, or one the map cannot place: open framed on every site
    // the way the fit-all button frames them, across the date line when that
    // is tighter (#2516).
    final initialFit = selectedPoint == null
        ? MapCameraAnimator.fitAllCameraFit(
            _sitePoints(sitesWithDives.map((s) => s.site)),
          )
        : null;

    // Build a lookup map from marker location to dive count for cluster summing
    final diveCountByLocation = <LatLng, int>{};
    for (final siteWithCount in sitesWithDives) {
      final site = siteWithCount.site;
      final point = LatLng(site.location!.latitude, site.location!.longitude);
      diveCountByLocation[point] = siteWithCount.diveCount;
    }

    return Stack(
      children: [
        TrackpadZoomMap(
          controller: _mapController,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              initialCameraFit: initialFit,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: rotatableMapInteraction,
              onMapReady: () {
                _mapReady = true;
              },
              onTap: (_, _) {
                widget.onItemSelected(null);
              },
              cameraConstraint: worldMapCameraConstraint,
            ),
            children: [
              TileLayer(
                urlTemplate: ref.watch(mapTileUrlProvider),
                userAgentPackageName: 'app.submersion',
                maxZoom: ref.watch(mapTileMaxZoomProvider),
                tileProvider: TileCacheService.instance.tileProviderFor(
                  urlTemplate: ref.watch(mapTileUrlProvider),
                ),
              ),
              // Markers layer - shows sites with dives
              WorldWrappedMarkerClusterLayer(
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
                      child: Semantics(
                        button: true,
                        label: 'Select dive site ${site.name}',
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
                    _camera.animateToBounds(node.bounds);
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
              const MapAttribution(),
            ],
          ),
        ),

        // Reset-to-north compass (hidden until the map is rotated), tucked
        // below the heat-map toggle so the two controls stack rather than overlap.
        Positioned(
          top: 64,
          right: 8,
          child: MapCompassButton(controller: _mapController),
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
                      context.l10n.diveLog_map_emptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.diveLog_map_emptySubtitle,
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

    // Title: Site name (matching DiveListTile)
    final title = dive.site?.name ?? context.l10n.diveLog_listPage_unknownSite;

    // Build subtitle with date, depth, duration, water temp (matching DiveListTile)
    final parts = <String>[];
    parts.add(units.formatDateTime(dive.dateTime, l10n: context.l10n));
    if (dive.maxDepth != null) {
      parts.add(units.formatDepth(dive.maxDepth!));
    }
    if (dive.bottomTime != null) {
      parts.add('${dive.bottomTime!.inMinutes} min');
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

    // Smooth scroll to the tapped marker
    _camera.animateTo(
      LatLng(site.location!.latitude, site.location!.longitude),
    );
  }

  /// Where [sites] sit on the map, skipping any without coordinates.
  static List<LatLng> _sitePoints(Iterable<DiveSite> sites) => [
    for (final site in sites)
      if (site.hasCoordinates)
        LatLng(site.location!.latitude, site.location!.longitude),
  ];

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.l10n.diveLog_map_errorLoading(error.toString())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              // The id set behind the filtered list is its own provider
              // (#2365); a failed SQL refresh lives there, so Retry must
              // reach it.
              ref.invalidate(
                queryFilteredDiveIdsProvider(ref.read(diveFilterProvider)),
              );
              ref.invalidate(sortedFilteredDivesProvider);
              ref.invalidate(diveActivityHeatMapProvider);
            },
            child: Text(context.l10n.diveLog_error_retry),
          ),
        ],
      ),
    );
  }
}

/// Helper class for counting dives per site
class _SiteCounter {
  final DiveSite site;
  int count;

  _SiteCounter({required this.site, required this.count});
}
