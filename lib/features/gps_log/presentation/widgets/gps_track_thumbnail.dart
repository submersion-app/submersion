import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';

const double kTrackThumbnailWidth = 88;
const double kTrackThumbnailHeight = 64;

/// Highest zoom a thumbnail will fit to.
///
/// Deliberately low. Tracks recorded on the same trip then share basemap
/// tiles, so a week of dives costs a handful of tile fetches for the whole
/// list rather than four per row.
const double _kThumbMaxZoom = 12.0;

/// A small non-interactive map preview of one recorded track.
class GpsTrackThumbnail extends ConsumerWidget {
  const GpsTrackThumbnail({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry = ref.watch(
      gpsTrackGeometryProvider((trackId, TrackLod.thumbnail)),
    );

    // While loading, and on any error, show the tile-less shape rather than a
    // spinner: a list of spinners reads as broken, and the shape is the point.
    final points = geometry.value ?? const <GpsTrackPoint>[];
    final camera = points.length >= 2
        ? TrackCamera.forPoints(
            points,
            maxZoom: _kThumbMaxZoom,
            padding: const EdgeInsets.all(8),
          )
        : null;

    if (camera == null) {
      return TrackShapeChip(
        points: points,
        width: kTrackThumbnailWidth,
        height: kTrackThumbnailHeight,
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: kTrackThumbnailWidth,
        height: kTrackThumbnailHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            options: MapOptions(
              // Never interactive: a live map here would fight the parent
              // ListView for the gesture arena on every drag.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
              initialCameraFit: camera.fit,
              initialCenter: camera.center ?? const LatLng(0, 0),
              initialZoom: camera.zoom ?? _kThumbMaxZoom,
            ),
            children: [
              submersionTileLayer(ref, maxZoomOverride: _kThumbMaxZoom),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      for (final p in points) LatLng(p.latitude, p.longitude),
                    ],
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2.5,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
