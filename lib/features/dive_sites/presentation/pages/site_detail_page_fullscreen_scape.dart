part of 'site_detail_page.dart';

/// Opening the site's fullscreen scape from the detail page.
mixin _SiteDetailFullscreen
    on
        ConsumerState<_SiteDetailContent>,
        RecordEditHost<_SiteDetailContent, DiveSite> {
  final MapController _fullController = MapController();

  /// [body] under the scope through which the Features card's editor opens
  /// the map armed to place a feature in its sitting (issue #4527).
  Widget _withFeaturePlacement(BuildContext context, Widget body) =>
      SiteFeaturePlacementScope(
        placeOnMap: (session) {
          // The map is drawn around the site's position: none, no map.
          if (!session.working.hasCoordinates) return;
          _showFullscreenMap(
            context,
            ref,
            session.working,
            startPlacing: true,
            session: session,
          );
        },
        child: body,
      );

  void _showFullscreenMap(
    BuildContext context,
    WidgetRef ref,
    DiveSite site, {
    bool initialScape3d = false,
    bool startPlacing = false,
    EditSession<DiveSite>? session,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenSiteScapePage(
          site: site,
          controller: _fullController,
          initialScape3d: initialScape3d,
          startPlacing: startPlacing,
          session: session,
          sittingHost: session == null ? null : maybeEditController,
          // On a page that holds edits in a sitting, the map changes
          // features only for the Features card's editor (issue #4527).
          readOnly: hostsEditing && session == null,
        ),
      ),
    );
  }
}

/// Fullscreen morphable site scape pushed from the detail page: the same
/// single-pin map the embedded card shows, with the 2D/3D toggle, and it
/// can open directly in 3D (the app-bar terrain action).
class _FullscreenSiteScapePage extends ConsumerStatefulWidget {
  final DiveSite site;
  final MapController controller;
  final bool initialScape3d;

  /// Opens armed for feature placement: the next map tap drops a point.
  final bool startPlacing;

  /// The site's sitting, when opened from the Features card's editor: what
  /// is placed or edited goes to it, held until Save (issue #4527). Once it
  /// has ended, the map reads only.
  final EditSession<DiveSite>? session;

  /// What owns [session] and tells when the sitting ends: a session is
  /// disposed without a word to its listeners.
  final Listenable? sittingHost;

  /// Places nothing and offers no Edit: opened on a page that holds edits
  /// in a sitting, from anywhere but the Features card's editor.
  final bool readOnly;

  const _FullscreenSiteScapePage({
    required this.site,
    required this.controller,
    required this.initialScape3d,
    this.startPlacing = false,
    this.session,
    this.sittingHost,
    this.readOnly = false,
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
  late bool _placing = widget.startPlacing && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    widget.session?.addListener(_onSession);
    widget.sittingHost?.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.sittingHost?.removeListener(_onSession);
    final session = widget.session;
    if (session != null && !session.isDisposed) {
      session.removeListener(_onSession);
    }
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  /// The sitting while it lasts; null without one, or once it has ended.
  EditSession<DiveSite>? get _sitting {
    final session = widget.session;
    return session == null || session.isDisposed ? null : session;
  }

  /// Whether nothing on the map may change: told so, or its sitting ended.
  bool get _writesNothing =>
      widget.readOnly || (widget.session != null && _sitting == null);

  /// Drops a feature at the tapped point: depth pre-samples from the
  /// cached bathymetry grid, then the sheet collects the rest. Placement
  /// disarms on the first tap whether or not the diver saves.
  Future<void> _onMapTap(BuildContext context, LatLng latLng) async {
    if (!_placing || _writesNothing) return;
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
    if (widget.session != null) {
      // Held until Save, under an id of its own until then.
      final sitting = _sitting;
      if (sitting == null) return;
      addFeatureInSitting(
        sitting,
        SiteFeature(
          id: const Uuid().v4(),
          siteId: site.id,
          typeName: result.typeName,
          latitude: latLng.latitude,
          longitude: latLng.longitude,
          bearingDeg: result.bearingDeg,
          depthMeters: result.depthMeters,
          name: result.name,
          notes: result.notes,
        ),
      );
      return;
    }
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
                  _markers(context, site),
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

  /// The site's features: the sitting's, editable in it, while it lasts;
  /// read only once it has ended or when the map writes nothing.
  Widget _markers(BuildContext context, DiveSite site) {
    final sitting = _sitting;
    if (widget.session != null) {
      return SiteFeatureMarkerLayer(
        siteId: site.id,
        features: sitting == null ? null : siteFeaturesList.current(sitting),
        readOnly: sitting == null,
        onEdit: sitting == null
            ? null
            : (feature) => editFeatureInSitting(context, sitting, feature),
      );
    }
    return SiteFeatureMarkerLayer(siteId: site.id, readOnly: widget.readOnly);
  }
}
