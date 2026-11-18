part of 'site_detail_page.dart';

/// Fullscreen morphable site scape pushed from the detail page: the same
/// single-pin map the embedded card shows, with the 2D/3D toggle, and it
/// can open directly in 3D (the app-bar terrain action).
class _FullscreenSiteScapePage extends ConsumerStatefulWidget {
  final DiveSite site;
  final MapController controller;
  final bool initialScape3d;

  /// Opens armed for feature placement: the next map tap drops a point.
  final bool startPlacing;

  const _FullscreenSiteScapePage({
    required this.site,
    required this.controller,
    required this.initialScape3d,
    this.startPlacing = false,
  });

  @override
  ConsumerState<_FullscreenSiteScapePage> createState() =>
      _FullscreenSiteScapePageState();
}

class _FullscreenSiteScapePageState
    extends ConsumerState<_FullscreenSiteScapePage> {
  late SiteScapeMode _mode = widget.initialScape3d
      ? SiteScapeMode.terrain3d
      : SiteScapeMode.map2d;
  late bool _placing = widget.startPlacing;

  /// Drops a feature at the tapped point: depth pre-samples from the
  /// cached bathymetry grid, then the sheet collects the rest. Placement
  /// disarms on the first tap whether or not the diver saves.
  Future<void> _onMapTap(BuildContext context, LatLng latLng) async {
    if (!_placing) return;
    setState(() => _placing = false);
    final site = widget.site;
    final grid = ref
        .read(
          bathymetryGridProvider(BathymetryRepository.quantize(site.location!)),
        )
        .valueOrNull;
    final sampled = grid == null
        ? null
        : sampleGridDepth(grid, latLng.latitude, latLng.longitude);
    if (!context.mounted) return;
    final result = await showSiteFeatureSheet(
      context,
      initialDepthMeters: sampled,
    );
    if (result is! SiteFeatureSheetSave) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    await ref
        .read(siteFeatureRepositoryProvider)
        .addFeature(
          actingDiverId: diverId,
          siteId: site.id,
          typeName: result.typeName,
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          bearingDeg: result.bearingDeg,
          depthMeters: result.depthMeters,
          name: result.name,
          notes: result.notes,
        );
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final colorScheme = Theme.of(context).colorScheme;
    final siteLocation = LatLng(
      site.location!.latitude,
      site.location!.longitude,
    );
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: SiteScapeView(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        selectedSiteId: site.id,
        selectedSiteLocation: site.location,
        mapController: widget.controller,
        mapBuilder: (context) => Stack(
          children: [
            TrackpadZoomMap(
              controller: widget.controller,
              child: FlutterMap(
                mapController: widget.controller,
                options: MapOptions(
                  initialCenter: siteLocation,
                  initialZoom: 14.0,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, latLng) => _onMapTap(context, latLng),
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
                  BathymetryDepthOverlayLayer(location: site.location),
                  SiteFeatureMarkerLayer(siteId: site.id),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: siteLocation,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.scuba_diving,
                              size: 24,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MapAttribution(),
                ],
              ),
            ),
            // Map style switcher. No compass: this map does not rotate.
            const Positioned(top: 8, right: 8, child: MapCornerControls()),
            // Stops short of the right edge so the style switcher stays
            // reachable while placing a feature.
            if (_placing)
              Positioned(
                top: 8,
                left: 56,
                right: 60,
                child: Material(
                  key: const ValueKey('siteFeaturePlaceBanner'),
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          size: 18,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.siteFeature_placeHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('siteFeaturePlaceCancel'),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: context.l10n.common_action_cancel,
                          onPressed: () => setState(() => _placing = false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
