import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/region_download_dialog.dart';
import 'package:submersion/features/maps/presentation/widgets/region_selection.dart';
import 'package:submersion/features/maps/presentation/widgets/region_selector.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Page for selecting a rectangular region on a map and opening the
/// [RegionDownloadDialog] for that region.
///
/// It has two modes, switched by the toggle at the top:
/// - Move: drag to pan, pinch / double-tap / the +/- buttons to zoom.
/// - Select: drag to draw the download rectangle, or drag one of its corner
///   handles to adjust it. Confirm to launch the download dialog.
///
/// Mouse and keyboard: wheel and double-click zoom, `+` / `-` (also on the
/// numpad) zoom in and out, and the middle button pans in Select mode too.
///
/// The rectangle is stored as coordinates and drawn inside the map, so it stays
/// put on the map while the map is moved. The page starts in Move mode so the
/// diver can first navigate to the area before drawing.
class RegionPickerPage extends ConsumerStatefulWidget {
  const RegionPickerPage({super.key});

  @override
  ConsumerState<RegionPickerPage> createState() => _RegionPickerPageState();
}

class _RegionPickerPageState extends ConsumerState<RegionPickerPage> {
  /// Lowest zoom the picker allows: the whole world.
  static const double _minZoom = 2.0;

  final MapController _mapController = MapController();
  final RegionSelection _selection = RegionSelection();

  bool _selecting = false;

  /// Width kept clear for the style button in the top-right corner (the
  /// button itself plus the gap to the card).
  static const double _styleButtonSlot = 44 + 12;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> _onRegionSelected(LatLng southWest, LatLng northEast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          RegionDownloadDialog(southWest: southWest, northEast: northEast),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final maxZoom = ref.read(mapTileMaxZoomProvider).toDouble();
    final zoom = (camera.zoom + delta).clamp(_minZoom, maxZoom);
    _mapController.move(camera.center, zoom);
  }

  /// The card at the top: what to do in the current mode, and why Select
  /// Region is disabled when the box straddles the date line.
  Widget _instructionCard(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _selection,
      builder: (context, _) {
        final String instruction;
        if (!_selecting) {
          instruction = l10n.maps_regionSelector_dragToMove;
        } else if (_selection.hasSelection) {
          instruction = l10n.maps_regionSelector_dragToAdjust;
        } else {
          instruction = l10n.maps_regionSelector_dragToSelect;
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.touch_app, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(instruction, style: theme.textTheme.bodyMedium),
                      if (_selection.crossesDateLine)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.maps_regionSelector_dateLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Select mode keeps only the gestures that cannot clash with drawing;
    // Move mode gives the map every gesture except rotation.
    final flags = _selecting
        ? InteractiveFlag.pinchZoom |
              InteractiveFlag.pinchMove |
              InteractiveFlag.doubleTapZoom
        : InteractiveFlag.drag |
              InteractiveFlag.flingAnimation |
              InteractiveFlag.pinchMove |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.maps_offline_downloadNewRegion)),
      // No Focus of its own: flutter_map autofocuses its keyboard node (arrow
      // keys pan), and the keys it ignores bubble up to these bindings.
      body: CallbackShortcuts(
        // Matched by the typed character, so "+" works however the layout
        // produces it (Shift and = on a US keyboard, its own key on others,
        // the numpad), and fires once. "=" is the unshifted plus key.
        bindings: {
          const CharacterActivator('+'): () => _zoomBy(1),
          const CharacterActivator('='): () => _zoomBy(1),
          const CharacterActivator('-'): () => _zoomBy(-1),
        },
        child: Stack(
          children: [
            TrackpadZoomMap(
              controller: _mapController,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(20.0, 0.0),
                  initialZoom: 2.0,
                  minZoom: _minZoom,
                  maxZoom: ref.watch(mapTileMaxZoomProvider),
                  interactionOptions: InteractionOptions(flags: flags),
                  // Stops at the poles like the app's other world maps, so
                  // the map cannot be dragged to show the grey area above or
                  // below the world.
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
                  // The chosen rectangle, drawn with the camera of the same
                  // frame.
                  ...regionSelectionLayers(_selection),
                  const MapAttribution(),
                ],
              ),
            ),
            RegionSelector(
              mapController: _mapController,
              selection: _selection,
              onRegionSelected: _onRegionSelected,
              selecting: _selecting,
            ),
            // The standard corner controls (the map style button; no compass,
            // since this map does not rotate), anchored to the top-right
            // corner. The style is app-wide, so the tiles here and the tiles
            // a download fetches are the same style.
            const Positioned(top: 16, right: 16, child: MapCornerControls()),
            // Instruction card, then the mode toggle under it. They take the
            // width left of the style button, in a column, so a long
            // translation grows the card without overlapping the controls.
            Positioned(
              top: 16,
              left: 16,
              right: 16 + _styleButtonSlot,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _instructionCard(context),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: false,
                            icon: const Icon(Icons.open_with),
                            label: Text(l10n.maps_regionSelector_modeMove),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: const Icon(Icons.crop_free),
                            label: Text(l10n.maps_regionSelector_modeSelect),
                          ),
                        ],
                        selected: {_selecting},
                        onSelectionChanged: (value) =>
                            setState(() => _selecting = value.first),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Zoom buttons, above the action buttons.
            Positioned(
              right: 16,
              bottom: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: l10n.maps_regionSelector_zoomIn,
                    onPressed: () => _zoomBy(1),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: l10n.maps_regionSelector_zoomOut,
                    onPressed: () => _zoomBy(-1),
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
