import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/utils/geo_math.dart';

/// The camera constraint for the app's world maps: stop at the poles but
/// scroll east and west without end, the way flutter_map repeats the world.
///
/// These maps used `CameraConstraint.contain` on -180..180, which pinned the
/// camera to one copy of the world with the Pacific split across its two
/// edges (issue #2516). Layers that project points themselves have to draw
/// every copy for this to look right: use [WorldWrappedMarkerClusterLayer]
/// for clustered markers.
const CameraConstraint worldMapCameraConstraint =
    CameraConstraint.containLatitude();

/// One copy of the world that the viewport shows, and a camera that draws
/// the canonical -180..180 world into that copy's place.
///
/// [shift] counts whole worlds east of the canonical one (negative is west).
typedef WorldCopy = ({int shift, MapCamera camera});

/// Every copy of the world that [camera]'s viewport overlaps, or comes
/// within [bleed] pixels of, west to east.
///
/// flutter_map repeats tiles and its own marker, polyline and polygon layers
/// across the date line, but a layer that projects points itself (the marker
/// cluster plugin, the heat map painter) only ever draws the canonical
/// world. Such a layer can draw itself once per copy, using each copy's
/// camera in place of the real one, to scroll seamlessly (issue #2516).
///
/// The copy with shift 0 is [camera] itself. The others are centred 360
/// degrees west for each world east, so a point projects [shift] world
/// widths further east on screen. A longitude past 180 has no valid
/// [LatLngBounds], so each shifted copy's [MapCamera.visibleBounds] holds
/// instead the canonical longitudes it actually puts on screen, padded by
/// half a screen, so a layer that recurses by visible bounds, as the cluster
/// plugin does, only walks the part of the world that copy can show.
///
/// [bleed] is for a layer that draws past a point's position, such as a heat
/// blob of that radius: a copy whose world starts just off screen can still
/// reach it. Away from the seam it adds nothing.
///
/// A CRS that does not repeat the world has one copy: [camera].
List<WorldCopy> worldCopyCameras(MapCamera camera, {double bleed = 0}) {
  final worldWidth = camera.getWorldWidthAtZoom();
  if (worldWidth <= 0) return [(shift: 0, camera: camera)];

  // The canonical world covers x in [0, worldWidth) at this zoom.
  final left = camera.pixelOrigin.dx;
  final right = left + camera.size.width;
  final first = ((left - bleed) / worldWidth).floor();
  final last = ((right + bleed - 1) / worldWidth).floor();
  if (first == 0 && last == 0) return [(shift: 0, camera: camera)];

  final real = camera.visibleBounds;
  // Padded by half a screen each side, as the cluster plugin pads the real
  // view, so a marker just past a sliver of a copy still draws its edge.
  final pad = camera.size.width / 2;
  double longitudeAt(double x) =>
      x.clamp(0.0, worldWidth) / worldWidth * 360 - 180;
  return [
    for (var shift = first; shift <= last; shift++)
      if (shift == 0)
        (shift: 0, camera: camera)
      else
        (
          shift: shift,
          camera: MapCamera(
            crs: camera.crs,
            center: LatLng(
              camera.center.latitude,
              camera.center.longitude - 360.0 * shift,
            ),
            zoom: camera.zoom,
            rotation: camera.rotation,
            nonRotatedSize: camera.nonRotatedSize,
            minZoom: camera.minZoom,
            maxZoom: camera.maxZoom,
            bounds: LatLngBounds.unsafe(
              north: real.north,
              south: real.south,
              west: longitudeAt(left - pad - worldWidth * shift),
              east: longitudeAt(right + pad - worldWidth * shift),
            ),
          ),
        ),
  ];
}

/// A [MarkerClusterLayerWidget] that repeats across the date line.
///
/// `flutter_map_marker_cluster` positions markers in the canonical world
/// only, so on a map that scrolls past 180 the markers on the far side of the
/// seam would be missing. This draws one cluster layer per visible copy of
/// the world (see [worldCopyCameras]); away from the seam that is just one.
/// Clusters never merge across the seam, the same as the plugin's own
/// clustering, which works in canonical pixels.
///
/// Each copy is keyed by the world it shows, not by its shift. The camera's
/// longitude wraps as it crosses 180, which relabels every copy's shift by
/// one; keyed by shift, the copy on screen would become a new State and take
/// any running plugin animation (the zoom-to-cluster of a layer with
/// `zoomToBoundsOnClick`) with it halfway. Counting the wraps keeps each
/// piece of the world with its own State.
class WorldWrappedMarkerClusterLayer extends StatefulWidget {
  const WorldWrappedMarkerClusterLayer({super.key, required this.options});

  final MarkerClusterLayerOptions options;

  @override
  State<WorldWrappedMarkerClusterLayer> createState() =>
      _WorldWrappedMarkerClusterLayerState();
}

class _WorldWrappedMarkerClusterLayerState
    extends State<WorldWrappedMarkerClusterLayer> {
  double? _lastLongitude;

  /// Net times the camera has wrapped east across 180 (west counts -1).
  int _wraps = 0;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final controller = MapController.of(context);

    // The camera wrapped at the seam when its longitude jumped by more than
    // half the world while it actually moved only a little the short way:
    // 179.9 to -179.9 is 0.2 degrees east. A long jump the short way too is
    // a teleport (a fit, a list tap), and nothing on screen carries over, so
    // leave the keys alone and every copy keeps its clusters.
    final last = _lastLongitude;
    if (last != null) {
      final jump = camera.center.longitude - last;
      final moved = longitudeDelta(last, camera.center.longitude).abs();
      if (jump.abs() > 180 && moved < 90) _wraps += jump < 0 ? 1 : -1;
    }
    _lastLongitude = camera.center.longitude;

    return Stack(
      children: [
        for (final copy in worldCopyCameras(camera))
          MarkerClusterLayer(
            key: ValueKey(copy.shift + _wraps),
            mapController: controller,
            mapCamera: copy.camera,
            options: widget.options,
          ),
      ],
    );
  }
}
