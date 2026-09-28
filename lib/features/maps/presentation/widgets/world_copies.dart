import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

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

/// Every copy of the world that [camera]'s viewport overlaps, west to east.
///
/// flutter_map repeats tiles and its own marker, polyline and polygon layers
/// across the date line, but a layer that projects points itself (the marker
/// cluster plugin, the heat map painter) only ever draws the canonical
/// world. Such a layer can draw itself once per copy, using each copy's
/// camera in place of the real one, to scroll seamlessly (issue #2516).
///
/// The copy with shift 0 is [camera] itself. The others are centred 360
/// degrees west for each world east, so a point projects [shift] world
/// widths further east on screen. Their [MapCamera.visibleBounds] spans every
/// longitude at the real view's latitudes, because a longitude past 180 has
/// no valid [LatLngBounds]; layers still cull by pixel bounds.
///
/// [margin] adds that many copies beyond the visible ones on each side.
///
/// A CRS that does not repeat the world has one copy: [camera].
List<WorldCopy> worldCopyCameras(MapCamera camera, {int margin = 0}) {
  final worldWidth = camera.getWorldWidthAtZoom();
  if (worldWidth <= 0) return [(shift: 0, camera: camera)];

  // The canonical world covers x in [0, worldWidth) at this zoom.
  final left = camera.pixelOrigin.dx;
  final right = left + camera.size.width;
  final first = (left / worldWidth).floor() - margin;
  final last = ((right - 1) / worldWidth).floor() + margin;
  if (first == 0 && last == 0) return [(shift: 0, camera: camera)];

  final real = camera.visibleBounds;
  final everyLongitude = LatLngBounds.unsafe(
    north: real.north,
    south: real.south,
    east: 180,
    west: -180,
  );
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
            bounds: everyLongitude,
          ),
        ),
  ];
}

/// A [MarkerClusterLayerWidget] that repeats across the date line.
///
/// `flutter_map_marker_cluster` positions markers in the canonical world
/// only, so on a map that scrolls past 180 the markers on the far side of the
/// seam would be missing. This draws one cluster layer per visible copy of
/// the world (see [worldCopyCameras]). Clusters never merge across the seam,
/// the same as the plugin's own clustering, which works in canonical pixels.
///
/// It keeps one copy beyond the visible ones on each side. The plugin runs
/// its zoom-to-cluster animation inside the copy that was tapped, and when
/// that animation carries the camera across the date line the camera's
/// longitude wraps, which relabels every copy by one world. Without the spare
/// copies the tapped copy could leave the list and take the animation with
/// it halfway. Copies off screen cull all their markers, so they cost little.
class WorldWrappedMarkerClusterLayer extends StatelessWidget {
  const WorldWrappedMarkerClusterLayer({super.key, required this.options});

  final MarkerClusterLayerOptions options;

  @override
  Widget build(BuildContext context) {
    final controller = MapController.of(context);
    final copies = worldCopyCameras(MapCamera.of(context), margin: 1);
    return Stack(
      children: [
        for (final copy in copies)
          MarkerClusterLayer(
            // Keyed by shift so each copy keeps its own cluster state as the
            // camera moves.
            key: ValueKey(copy.shift),
            mapController: controller,
            mapCamera: copy.camera,
            options: options,
          ),
      ],
    );
  }
}
