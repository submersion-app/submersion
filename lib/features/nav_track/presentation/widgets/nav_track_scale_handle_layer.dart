import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_scale_handle.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_map_drag_target.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The handle a diver drags to resize a track against the map: away from
/// [pivot] grows it, toward [pivot] shrinks it, and only the distance counts,
/// so a sideways move cannot rotate anything.
class NavTrackScaleHandleLayer extends StatefulWidget {
  const NavTrackScaleHandleLayer({
    super.key,
    required this.mapKey,
    required this.point,
    required this.pivot,
    required this.scaleFactor,
    required this.onChanged,
  });

  final GlobalKey mapKey;

  /// Where the handle sits: on the corrected track.
  final GeoPoint point;

  /// The dive's start, which a scale leaves where it is.
  final GeoPoint pivot;

  final double scaleFactor;
  final ValueChanged<double> onChanged;

  @override
  State<NavTrackScaleHandleLayer> createState() =>
      _NavTrackScaleHandleLayerState();
}

class _NavTrackScaleHandleLayerState extends State<NavTrackScaleHandleLayer> {
  /// The scale the drag works from, read at its first move rather than at the
  /// press: pressing here is what commits a value still being typed in the
  /// scale field, and that commit lands after the press.
  double? _pressScale;
  double _pressDistance = 0;

  /// How far on the ground [global] is from the pivot.
  double _distanceFromPivot(MapCamera camera, Offset global) {
    final ground = groundUnderPointer(widget.mapKey, camera, global);
    return distanceMeters(
      widget.pivot,
      GeoPoint(ground.latitude, ground.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final label = context.l10n.navTrack_align_scaleHandleLabel;
    return MarkerLayer(
      markers: [
        Marker(
          point: LatLng(widget.point.latitude, widget.point.longitude),
          width: 36,
          height: 36,
          child: Semantics(
            label: label,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: NavTrackMapDragTarget(
                key: const ValueKey('nav-track-align-scale-handle'),
                onStart: (global) {
                  _pressScale = null;
                  _pressDistance = _distanceFromPivot(camera, global);
                },
                onMove: (global) => widget.onChanged(
                  scaleFromDrag(
                    pressScale: _pressScale ??= widget.scaleFactor,
                    pressDistance: _pressDistance,
                    currentDistance: _distanceFromPivot(camera, global),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
