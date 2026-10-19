import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';

/// The rectangle being chosen on the region picker, as two map coordinates.
///
/// Kept as coordinates, so it stays on the same place of the map while the map
/// is panned or zoomed. [RegionSelector] changes it from gestures;
/// [RegionSelectionLayer] draws it inside the map, in the same frame as the
/// camera; the page reads it for the instruction card and the buttons.
class RegionSelection extends ChangeNotifier {
  LatLng? _start;
  LatLng? _end;

  bool get hasSelection => _start != null && _end != null;

  LatLng? get southWest => !hasSelection
      ? null
      : LatLng(
          math.min(_start!.latitude, _end!.latitude),
          math.min(_start!.longitude, _end!.longitude),
        );

  LatLng? get northEast => !hasSelection
      ? null
      : LatLng(
          math.max(_start!.latitude, _end!.latitude),
          math.max(_start!.longitude, _end!.longitude),
        );

  /// The rectangle straddles the date line, which one download cannot cover
  /// (see [clampRegionToWorld]).
  bool get crossesDateLine =>
      hasSelection &&
      clampRegionToWorld(southWest!, northEast!).crossesDateLine;

  /// Start a new rectangle at [point].
  void begin(LatLng point) {
    _start = point;
    _end = point;
    notifyListeners();
  }

  /// Take hold of an existing corner: [moving] is the corner that follows the
  /// pointer, [fixed] the opposite one that stays where it is.
  void grab({required LatLng fixed, required LatLng moving}) {
    _start = fixed;
    _end = moving;
    notifyListeners();
  }

  /// Move the free corner to [point].
  void moveTo(LatLng point) {
    _end = point;
    notifyListeners();
  }

  void clear() {
    _start = null;
    _end = null;
    notifyListeners();
  }
}

/// The two layers that draw [selection] inside the map: the filled rectangle
/// and a handle on each corner. Use them as children of the `FlutterMap`.
///
/// Map layers are rebuilt with the camera in the same frame, so the rectangle
/// never trails the tiles while the map is panned or flung, and flutter_map
/// repeats polygons across the copies of the world.
///
/// The selection's longitudes continue past +-180, which flutter_map's
/// polygons do not accept, so the drawing uses [longitudeSpans]: one polygon,
/// or two when the box straddles the date line, and handles at the wrapped
/// corners.
List<Widget> regionSelectionLayers(RegionSelection selection) => [
  ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final color = Theme.of(context).colorScheme.primary;
      final sw = selection.southWest;
      final ne = selection.northEast;
      return PolygonLayer(
        polygons: [
          if (sw != null && ne != null)
            for (final span in longitudeSpans(sw.longitude, ne.longitude))
              Polygon(
                points: [
                  LatLng(sw.latitude, span.west),
                  LatLng(ne.latitude, span.west),
                  LatLng(ne.latitude, span.east),
                  LatLng(sw.latitude, span.east),
                ],
                color: color.withValues(alpha: 0.2),
                borderColor: color,
                borderStrokeWidth: 3,
              ),
        ],
      );
    },
  ),
  ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final sw = selection.southWest;
      final ne = selection.northEast;
      return CircleLayer(
        circles: [
          if (sw != null && ne != null)
            for (final corner in [
              LatLng(sw.latitude, sw.longitude),
              LatLng(ne.latitude, sw.longitude),
              LatLng(ne.latitude, ne.longitude),
              LatLng(sw.latitude, ne.longitude),
            ])
              CircleMarker(
                point: LatLng(
                  corner.latitude,
                  normalizeLongitude(corner.longitude),
                ),
                radius: 9,
                useRadiusInMeter: false,
                color: scheme.primary,
                // The theme's surface keeps the ring visible in dark mode
                // and on satellite tiles.
                borderColor: scheme.surface,
                borderStrokeWidth: 2,
              ),
        ],
      );
    },
  ),
];
