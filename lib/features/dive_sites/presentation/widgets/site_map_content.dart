import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_depth_overlay_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_marker_layer.dart';
import 'package:submersion/features/site_scape/presentation/site_scape_view.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_sites_toggle_button.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
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
  late final MapCameraAnimator _camera = MapCameraAnimator(
    controller: _mapController,
    vsync: this,
  );
  bool _mapReady = false;

  // Ephemeral morph state: each entry to this widget starts in 2D.
  SiteScapeMode _scapeMode = SiteScapeMode.map2d;

  /// Externally-keyed selection for a tapped built-in (bundled) site. Held
  /// locally rather than in the shared selection, which is keyed to the user's
  /// own sites.
  String? _selectedBuiltInId;

  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 3.0;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

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
        _camera.animateTo(
          LatLng(site.location!.latitude, site.location!.longitude),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final heatMapAsync = ref.watch(siteCoverageHeatMapProvider);
    final heatMapSettings = ref.watch(heatMapSettingsProvider);

    // Clear a built-in selection when built-in sites are hidden, so the info
    // card cannot outlive its markers. Uses listen (not watch) to avoid
    // rebuilding the map on toggle, which would recreate the FlutterMap.
    ref.listen<bool>(showBuiltInSitesProvider, (prev, next) {
      if (!next && _selectedBuiltInId != null) {
        setState(() => _selectedBuiltInId = null);
      }
    });

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

    return SiteScapeView(
      mode: _scapeMode,
      onModeChanged: (m) => setState(() => _scapeMode = m),
      selectedSiteId: selectedSite?.id,
      selectedSiteLocation: selectedSite?.location,
      mapController: _mapController,
      mapBuilder: (context) => Stack(
        children: [
          _buildMap(context, sitesWithCounts, heatMapAsync, heatMapSettings),
          // Pane mode, heat map toggle and fit all sites controls. The 2D/3D
          // pair leads this cluster rather than floating in its own card, so
          // the pane controls read as one group in both modes.
          Positioned(
            top: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SiteScapeModeToggle(
                      mode: _scapeMode,
                      onModeChanged: (m) => setState(() => _scapeMode = m),
                      selectedSiteId: selectedSite?.id,
                      selectedSiteLocation: selectedSite?.location,
                    ),
                    const BuiltInSitesToggleButton(),
                    const HeatMapToggleButton(),
                    IconButton(
                      icon: const Icon(Icons.my_location, size: 20),
                      tooltip: context.l10n.diveSites_map_tooltip_fitAllSites,
                      onPressed: () => _camera.fitAll(
                        _sitePoints(sitesWithCounts.map((s) => s.site)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedBuiltInId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child:
                      _buildBuiltInInfoCard(context) ?? const SizedBox.shrink(),
                ),
              ),
            )
          else if (selectedSite != null)
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
      ),
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

    // The selected site also drives the depth overlay layer below.
    final selectedSite = widget.selectedId == null
        ? null
        : sitesWithLocation
              .where((s) => s.site.id == widget.selectedId)
              .firstOrNull
              ?.site;

    // A selected site with a location opens centred on it.
    final selectedPoint =
        widget.selectedId != null && selectedSite?.hasCoordinates == true
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
            _sitePoints(sitesWithLocation.map((s) => s.site)),
          )
        : null;

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
                setState(() => _selectedBuiltInId = null);
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
              // Depth overlay: the selected site's bathymetry as a
              // translucent ramp + contours, above tiles, below markers.
              BathymetryDepthOverlayLayer(location: selectedSite?.location),
              SiteFeatureMarkerLayer(siteId: selectedSite?.id),
              // Built-in (bundled) sites layer - below the user markers so the
              // user's own sites always draw on top. Shown only when toggled.
              Consumer(
                builder: (context, ref, _) {
                  final show = ref.watch(showBuiltInSitesProvider);
                  if (!show) return const SizedBox.shrink();
                  final builtInAsync = ref.watch(visibleBuiltInSitesProvider);
                  return builtInAsync.maybeWhen(
                    data: (builtIn) => BuiltInSiteMarkerLayer(
                      sites: builtIn,
                      selectedExternalId: _selectedBuiltInId,
                      onTap: (site) {
                        widget.onItemSelected(null);
                        setState(() => _selectedBuiltInId = site.externalId);
                        _camera.animateTo(
                          LatLng(site.latitude!, site.longitude!),
                        );
                      },
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              WorldWrappedMarkerClusterLayer(
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
                    _camera.animateToBounds(node.bounds);
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
      // The same seascape entry point as the site detail app bar, so the
      // 3D terrain is reachable from the map (issue #1065 placement).
      trailing: site.hasCoordinates
          ? IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () =>
                  setState(() => _scapeMode = SiteScapeMode.terrain3d),
            )
          : null,
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
    setState(() => _selectedBuiltInId = null);
    if (widget.selectedId == site.id) {
      widget.onItemSelected(null);
    } else {
      widget.onItemSelected(site.id);
      // Smooth scroll to the tapped marker
      _camera.animateTo(
        LatLng(site.location!.latitude, site.location!.longitude),
      );
    }
  }

  Widget? _buildBuiltInInfoCard(BuildContext context) {
    final async = ref.watch(visibleBuiltInSitesProvider);
    final site = async.maybeWhen(
      data: (list) =>
          list.where((s) => s.externalId == _selectedBuiltInId).firstOrNull,
      orElse: () => null,
    );
    if (site == null) return null;
    return BuiltInSiteInfoCard(site: site, onAdd: () => _addBuiltInSite(site));
  }

  Future<void> _addBuiltInSite(ExternalDiveSite site) async {
    try {
      await ref
          .read(siteListNotifierProvider.notifier)
          .addSite(
            site.toDiveSite(),
            // Its bundled features as site types (issue #1765).
            classification: SiteClassification(typeIds: site.siteTypeIds),
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.diveSites_map_builtInSites_addError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    // addSite reloads the notifier but not the map's FutureProvider; invalidate
    // so the new site appears and the built-in duplicate is deduped out.
    ref.invalidate(sitesWithCountsProvider);
    if (!mounted) return;
    setState(() => _selectedBuiltInId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.diveSites_map_builtInSites_added)),
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
