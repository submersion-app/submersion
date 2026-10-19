import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/widgets/region_selection.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Callback for when a region is selected.
typedef RegionSelectedCallback =
    void Function(LatLng southWest, LatLng northEast);

/// The gesture layer and the action buttons for choosing a rectangle on a map.
///
/// The rectangle itself is [selection]: this widget changes it, and
/// [RegionSelectionLayer] draws it inside the map.
///
/// Two modes, switched by [selecting]:
/// - Select (true): a drag on the map draws a new rectangle, unless it starts
///   on one of the rectangle's four corner handles, in which case that corner
///   follows the finger and the opposite corner stays put. The gesture layer
///   sits above the map, so the map itself cannot be panned in this mode.
/// - Move (false): the gesture layer is removed, so drags and pinches reach the
///   map and it can be panned and zoomed. The rectangle stays drawn and follows
///   the map.
///
/// Mouse: the cursor turns into a crosshair in select mode and into a grab hand
/// over a corner handle, the corner grab area is smaller for a mouse than for a
/// finger, and the middle button pans the map even in select mode.
class RegionSelector extends StatefulWidget {
  final MapController mapController;
  final RegionSelection selection;
  final RegionSelectedCallback? onRegionSelected;
  final VoidCallback? onCancel;
  final bool selecting;

  const RegionSelector({
    super.key,
    required this.mapController,
    required this.selection,
    this.onRegionSelected,
    this.onCancel,
    this.selecting = true,
  });

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  /// A drag that starts within this many logical pixels of a corner handle
  /// grabs it. Generous, because a fingertip is much bigger than the dot.
  static const double _cornerGrabRadius = 36;

  /// A mouse is precise, so its grab area is much smaller; a big one would make
  /// it impossible to start a new rectangle near an existing corner.
  static const double _cornerGrabRadiusMouse = 14;

  bool _isDragging = false;

  /// Mouse is over a corner handle (changes the cursor to a grab hand).
  bool _hoverCorner = false;

  /// The middle mouse button is held and moving: pan the map by hand, because
  /// the gesture layer above the map takes the primary-button drags.
  bool _middlePanning = false;

  RegionSelection get _selection => widget.selection;

  /// The map position under [offset], with a longitude that keeps counting
  /// past +-180.
  ///
  /// The map repeats the world, and the camera's own conversion
  /// (`screenOffsetToLatLng`) clamps the longitude at +-180, so a point on
  /// another copy of the world would collapse onto the date line. The
  /// longitude is worked out from the world pixel instead, so a rectangle
  /// drawn on any copy, or across the date line, has the longitudes it shows;
  /// `clampRegionToWorld` brings it back into one world when it is reported.
  LatLng _latLngAt(Offset offset) {
    final camera = widget.mapController.camera;
    final worldWidth = camera.getWorldWidthAtZoom(camera.zoom);
    final x =
        camera.projectAtZoom(camera.center).dx +
        (offset.dx - camera.nonRotatedSize.width / 2);
    return LatLng(
      camera.screenOffsetToLatLng(offset).latitude,
      x / worldWidth * 360 - 180,
    );
  }

  /// The four corners as (corner, opposite corner) pairs, each moved by whole
  /// worlds so that it sits on the copy of the world nearest the screen
  /// position [near]. Dragging a corner keeps its opposite fixed, whichever
  /// way the rectangle is then pulled.
  List<(LatLng, LatLng)> _cornerPairs(Offset near) {
    final camera = widget.mapController.camera;
    final worldWidth = camera.getWorldWidthAtZoom(camera.zoom);
    final sw = _selection.southWest!;
    final ne = _selection.northEast!;
    final nw = LatLng(ne.latitude, sw.longitude);
    final se = LatLng(sw.latitude, ne.longitude);

    (LatLng, LatLng) onNearestWorld((LatLng, LatLng) pair) {
      final x = camera.latLngToScreenOffset(pair.$1).dx;
      final worlds = ((near.dx - x) / worldWidth).round();
      LatLng shift(LatLng p) =>
          LatLng(p.latitude, p.longitude + 360.0 * worlds);
      return (shift(pair.$1), shift(pair.$2));
    }

    return [
      for (final pair in [(sw, ne), (ne, sw), (nw, se), (se, nw)])
        onNearestWorld(pair),
    ];
  }

  /// The corner pair whose handle is nearest [localPos] and within the grab
  /// radius, or null when the press is not on a handle.
  (LatLng, LatLng)? _cornerNear(Offset localPos, double radius) {
    if (!_selection.hasSelection) return null;
    final camera = widget.mapController.camera;
    (LatLng, LatLng)? best;
    var bestDistance = radius;
    for (final pair in _cornerPairs(localPos)) {
      final distance =
          (camera.latLngToScreenOffset(pair.$1) - localPos).distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = pair;
      }
    }
    return best;
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    final radius = details.kind == PointerDeviceKind.mouse
        ? _cornerGrabRadiusMouse
        : _cornerGrabRadius;
    final corner = _cornerNear(localPos, radius);
    if (corner != null) {
      // Grab the corner where it is (no jump), pinned to its opposite.
      _selection.grab(fixed: corner.$2, moving: corner.$1);
    } else {
      _selection.begin(_latLngAt(localPos));
    }
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);
    _selection.moveTo(_latLngAt(localPos));
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _onHover(PointerHoverEvent event) {
    final over =
        _cornerNear(event.localPosition, _cornerGrabRadiusMouse) != null;
    if (over != _hoverCorner) setState(() => _hoverCorner = over);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kMiddleMouseButton) _middlePanning = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_middlePanning) return;
    final camera = widget.mapController.camera;
    final size = (context.findRenderObject() as RenderBox).size;
    // Dragging the map right means the view centre moves left by the same
    // number of pixels, hence centre - delta.
    final centre = Offset(size.width / 2, size.height / 2);
    widget.mapController.move(
      camera.screenOffsetToLatLng(centre - event.delta),
      camera.zoom,
    );
  }

  void _onPointerUp(PointerEvent event) {
    _middlePanning = false;
  }

  void _confirmSelection() {
    if (!_selection.hasSelection) return;
    final region = clampRegionToWorld(
      _selection.southWest!,
      _selection.northEast!,
    );
    // A box across the date line is not downloadable as drawn; the button is
    // disabled for it, this only guards the call.
    if (region.crossesDateLine) return;
    widget.onRegionSelected?.call(region.southWest, region.northEast);
  }

  void _clearSelection() {
    _selection.clear();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      children: [
        // Gesture layer: only in select mode, otherwise it would swallow the
        // drags the map needs for panning.
        if (widget.selecting)
          Positioned.fill(
            child: Semantics(
              label: l10n.maps_regionSelector_selectRegion,
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                child: MouseRegion(
                  cursor: _hoverCorner
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.precise,
                  onHover: _onHover,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                  ),
                ),
              ),
            ),
          ),

        // Action buttons
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: ListenableBuilder(
            listenable: _selection,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearSelection,
                    child: Text(context.l10n.common_action_cancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _selection.hasSelection && !_selection.crossesDateLine
                        ? _confirmSelection
                        : null,
                    child: Text(
                      context.l10n.maps_regionSelector_selectRegionButton,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
