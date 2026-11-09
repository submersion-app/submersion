import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_camera_animator.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/gbif_occurrence_layer.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_layers_button.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_legend.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_list_pane.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_markers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_site_card.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_species_site_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Which species are seen where (issue #4358).
///
/// With nothing picked it shows "what lives here": a pin per site the diver
/// logged species at. With a species picked it shows "where it turns up":
/// logged pins, hollow expected pins and, when the diver turns it on, GBIF's
/// public records under them.
class SpeciesMapPage extends ConsumerStatefulWidget {
  /// Deep-link seed (`/species/map?species=<id>`). An id the catalog does
  /// not hold opens the places view.
  final String? initialSpeciesId;

  const SpeciesMapPage({super.key, this.initialSpeciesId});

  @override
  ConsumerState<SpeciesMapPage> createState() => _SpeciesMapPageState();
}

class _SpeciesMapPageState extends ConsumerState<SpeciesMapPage>
    with TickerProviderStateMixin {
  static const _sectionKey = 'speciesMap';
  static const _defaultCenter = LatLng(20.0, -157.0);
  static const _defaultZoom = 2.0;

  final MapController _mapController = MapController();
  late final MapCameraAnimator _camera = MapCameraAnimator(
    controller: _mapController,
    vsync: this,
  );

  String? _speciesId;

  /// Set when the resolved pick changes, cleared once the camera has framed
  /// the new pins, so data refreshes (a sighting added elsewhere) never yank
  /// the camera away from where the diver panned.
  bool _fitPending = false;

  /// The pick the camera last framed for. Compared with the RESOLVED pick,
  /// not [_speciesId]: a deep-linked id the catalog turns out not to hold
  /// resolves to places mode once the catalog loads, and those pins need
  /// framing too.
  String? _framedPick;
  bool _framedOnce = false;

  @override
  void initState() {
    super.initState();
    _speciesId = widget.initialSpeciesId;
  }

  /// go_router keeps this State when only the query changes (a link to
  /// another species while the map is open), so a new seed is a new pick.
  @override
  void didUpdateWidget(SpeciesMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSpeciesId != oldWidget.initialSpeciesId) {
      _speciesId = widget.initialSpeciesId;
      // A provider cannot change during this rebuild; clear the open card
      // once the frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mapListSelectionProvider(_sectionKey).notifier).deselect();
      });
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _pick(String? speciesId) {
    if (speciesId == _speciesId) return;
    ref.read(mapListSelectionProvider(_sectionKey).notifier).deselect();
    setState(() => _speciesId = speciesId);
  }

  Future<void> _openPicker(String? pickedId) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.85,
      child: SpeciesMapListPane(
        selectedSpeciesId: pickedId,
        onSelected: (id) {
          Navigator.of(sheetContext).pop();
          _pick(id);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final catalogAsync = ref.watch(allSpeciesProvider);
    final catalog = catalogAsync.value;
    // An id the catalog does not hold (deleted, or a stale link) is no
    // pick at all; while the catalog loads the seed stands.
    final pickedId = _speciesId == null
        ? null
        : catalog == null || catalog.any((s) => s.id == _speciesId)
        ? _speciesId
        : null;
    final picked = pickedId == null
        ? null
        : catalog?.where((s) => s.id == pickedId).firstOrNull;
    if (!_framedOnce || pickedId != _framedPick) {
      // The first build frames through initialCameraFit; later changes of
      // the resolved pick frame through [_fitPending].
      _fitPending = _framedOnce;
      _framedOnce = true;
      _framedPick = pickedId;
    }
    final selectedSiteId = ref
        .watch(mapListSelectionProvider(_sectionKey))
        .selectedId;
    final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);

    return MapListScaffold(
      sectionKey: _sectionKey,
      title: picked == null
          ? l10n.speciesMap_title
          : picked.localizedCommonName(l10n),
      onBackPressed: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      listPane: SpeciesMapListPane(
        selectedSpeciesId: pickedId,
        onSelected: _pick,
      ),
      mapPane: pickedId == null
          ? _placesMap(context, selectedSiteId)
          : _speciesMap(context, pickedId, selectedSiteId),
      infoCard: _infoCard(pickedId, selectedSiteId),
      actions: [
        if (!isDesktop)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.speciesMap_pickSpeciesTooltip,
            onPressed: () => _openPicker(pickedId),
          ),
      ],
    );
  }

  Widget? _infoCard(String? pickedId, String? selectedSiteId) {
    if (selectedSiteId == null) return null;
    void close() =>
        ref.read(mapListSelectionProvider(_sectionKey).notifier).deselect();
    if (pickedId == null) {
      final pin = ref
          .watch(speciesMapSitePinsProvider)
          .value
          ?.where((p) => p.siteId == selectedSiteId)
          .firstOrNull;
      return pin == null ? null : SpeciesMapSiteCard(pin: pin, onClose: close);
    }
    final pin = ref
        .watch(speciesMapSpeciesPinsProvider(pickedId))
        .value
        ?.where((p) => p.siteId == selectedSiteId)
        .firstOrNull;
    return pin == null
        ? null
        : SpeciesMapSpeciesSiteCard(
            pin: pin,
            speciesId: pickedId,
            onClose: close,
          );
  }

  Widget _placesMap(BuildContext context, String? selectedSiteId) {
    final l10n = context.l10n;
    final pins = ref.watch(speciesMapSitePinsProvider);
    return _loaded(
      pins,
      () => ref.invalidate(speciesMapSitePinsProvider),
      (pins) => _map(
        context,
        points: [for (final p in pins) LatLng(p.latitude, p.longitude)],
        markers: [
          for (final pin in pins)
            _marker(
              point: LatLng(pin.latitude, pin.longitude),
              size: siteSpeciesMarkerSize(pin.speciesCount) + 6,
              label: l10n.speciesMap_semantics_sitePin(
                pin.siteName,
                pin.speciesCount,
              ),
              siteId: pin.siteId,
              child: SiteSpeciesMarker(
                speciesCount: pin.speciesCount,
                selected: pin.siteId == selectedSiteId,
              ),
            ),
        ],
        speciesId: null,
        notes: [_unplacedNote(null)],
      ),
    );
  }

  Widget _speciesMap(
    BuildContext context,
    String speciesId,
    String? selectedSiteId,
  ) {
    final l10n = context.l10n;
    final pins = ref.watch(speciesMapSpeciesPinsProvider(speciesId));
    final publicOn = ref.watch(speciesMapPublicLayerProvider);
    return _loaded(
      pins,
      () => ref.invalidate(speciesMapSpeciesPinsProvider(speciesId)),
      (pins) {
        final taxonKey = publicOn
            ? ref.watch(speciesGbifTaxonKeyProvider(speciesId))
            : null;
        final tilesFailed =
            publicOn &&
            ref.watch(speciesMapPublicTilesFailedProvider(speciesId));
        return _map(
          context,
          points: [for (final p in pins) LatLng(p.latitude, p.longitude)],
          markers: [
            for (final pin in pins)
              _marker(
                point: LatLng(pin.latitude, pin.longitude),
                size: 40,
                label: pin.kind == SpeciesPinKind.logged
                    ? l10n.speciesMap_semantics_loggedPin(
                        pin.siteName,
                        pin.sightingCount,
                      )
                    : l10n.speciesMap_semantics_expectedPin(pin.siteName),
                siteId: pin.siteId,
                key: speciesPinMarkerKey(pin.kind, pin.siteId),
                child: pin.kind == SpeciesPinKind.logged
                    ? LoggedSpeciesMarker(
                        sightingCount: pin.sightingCount,
                        selected: pin.siteId == selectedSiteId,
                      )
                    : ExpectedSpeciesMarker(
                        selected: pin.siteId == selectedSiteId,
                      ),
              ),
          ],
          speciesId: speciesId,
          notes: [
            _unplacedNote(speciesId),
            if (publicOn &&
                taxonKey?.hasValue == true &&
                taxonKey!.value == null)
              l10n.speciesMap_noPublicRecords,
            if (publicOn && (taxonKey?.hasError == true || tilesFailed))
              l10n.speciesMap_publicUnavailable,
            if (!publicOn && pins.isEmpty) l10n.speciesMap_suggestPublic,
          ],
        );
      },
    );
  }

  String? _unplacedNote(String? speciesId) {
    final count =
        ref.watch(speciesMapUnplacedCountProvider(speciesId)).value ?? 0;
    return count > 0 ? context.l10n.speciesMap_unplaced(count) : null;
  }

  Widget _loaded<T>(
    AsyncValue<T> value,
    VoidCallback retry,
    Widget Function(T data) builder,
  ) => value.when(
    data: builder,
    loading: () => const Center(child: CircularProgressIndicator()),
    // Like the Sites map: a localized message and a way to try again.
    error: (_, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(context.l10n.speciesMap_error_loading),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: retry,
            child: Text(context.l10n.marineLife_speciesPage_retry),
          ),
        ],
      ),
    ),
  );

  Marker _marker({
    required LatLng point,
    required double size,
    required String label,
    required String siteId,
    required Widget child,
    Key? key,
  }) => Marker(
    key: key,
    point: point,
    width: size,
    height: size,
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        // Selects without zooming: the card opens over the view the diver
        // chose, so comparing neighbouring sites stays one tap each.
        onTap: () => ref
            .read(mapListSelectionProvider(_sectionKey).notifier)
            .select(siteId),
        child: child,
      ),
    ),
  );

  Widget _map(
    BuildContext context, {
    required List<LatLng> points,
    required List<Marker> markers,
    required String? speciesId,
    required List<String?> notes,
  }) {
    if (_fitPending) {
      _fitPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (points.isEmpty) {
          _mapController.move(_defaultCenter, _defaultZoom);
        } else {
          _camera.fitAll(points);
        }
      });
    }
    final publicOn = ref.watch(speciesMapPublicLayerProvider);
    final cardOpen =
        ref.watch(mapListSelectionProvider(_sectionKey)).selectedId != null;
    final shownNotes = notes.whereType<String>().toList();

    return Stack(
      children: [
        TrackpadZoomMap(
          controller: _mapController,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              initialCameraFit: MapCameraAnimator.fitAllCameraFit(points),
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: rotatableMapInteraction,
              cameraConstraint: worldMapCameraConstraint,
              onTap: (_, _) => ref
                  .read(mapListSelectionProvider(_sectionKey).notifier)
                  .deselect(),
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
              if (speciesId != null) GbifOccurrenceLayer(speciesId: speciesId),
              WorldWrappedMarkerClusterLayer(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(44, 44),
                  markers: markers,
                  zoomToBoundsOnClick: false,
                  onClusterTap: (node) => _camera.animateToBounds(node.bounds),
                  builder: (context, clustered) =>
                      SpeciesMapClusterMarker(markers: clustered),
                ),
              ),
              const MapAttribution(),
            ],
          ),
        ),
        // The species map's own layers sit above the standard style and
        // compass column, in the same corner.
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SpeciesMapLayersButton(),
              const SizedBox(height: 8),
              MapCornerControls(controller: _mapController),
            ],
          ),
        ),
        if (shownNotes.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 64,
            child: Align(
              alignment: Alignment.topLeft,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final note in shownNotes)
                        Text(
                          note,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // An open site card sits at the bottom and would cover the legend,
        // so the legend steps aside until the card closes.
        if (!cardOpen)
          Positioned(
            left: 8,
            bottom: 28,
            child: SpeciesMapLegend(
              speciesMode: speciesId != null,
              publicOn: publicOn,
            ),
          ),
      ],
    );
  }
}
