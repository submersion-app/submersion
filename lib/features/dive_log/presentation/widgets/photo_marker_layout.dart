import 'dart:math' as math;

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// A photo positioned on the dive profile chart, derived from the photo's
/// persisted [MediaEnrichment] (computed once at import time).
class PhotoChartMarker {
  /// Source media item; used by the preview card and tap-through navigation.
  final MediaItem item;

  /// Seconds from dive start, clamped to the profile range.
  final int elapsedSeconds;

  /// Depth in meters at capture time.
  final double depthMeters;

  const PhotoChartMarker({
    required this.item,
    required this.elapsedSeconds,
    required this.depthMeters,
  });
}

/// Builds chart markers from a dive's media list, time-sorted. Photos and
/// videos with a usable profile position are included; elapsed time is
/// clamped to the profile range to absorb entry/exit clock skew.
List<PhotoChartMarker> photoMarkersFromMedia(
  List<MediaItem> media, {
  required int maxProfileSeconds,
}) {
  final markers = <PhotoChartMarker>[];
  for (final item in media) {
    // Photos AND videos get markers — underwater libraries are often mostly
    // short clips, and enrichment gives both the same (time, depth) position.
    // Only signatures are categorically not dive-moment media.
    if (item.mediaType == MediaType.instructorSignature) continue;
    final enrichment = item.enrichment;
    if (enrichment == null) continue;
    if (enrichment.matchConfidence == MatchConfidence.noProfile) continue;
    final seconds = enrichment.elapsedSeconds;
    final depth = enrichment.depthMeters;
    if (seconds == null || depth == null) continue;
    markers.add(
      PhotoChartMarker(
        item: item,
        elapsedSeconds: math.min(math.max(seconds, 0), maxProfileSeconds),
        depthMeters: depth,
      ),
    );
  }
  markers.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
  return markers;
}

/// Markers that would overlap at the current zoom, rendered as one chip
/// (with a count badge when there is more than one member).
class PhotoMarkerCluster {
  /// Indexes into the marker list handed to [clusterPhotoMarkers].
  final List<int> memberIndexes;

  /// Chip center in plot-relative pixels (0,0 = top-left of the plot rect).
  final double x;
  final double y;

  const PhotoMarkerCluster({
    required this.memberIndexes,
    required this.x,
    required this.y,
  });
}

/// Maps time-sorted marker [points] into plot pixels for the visible window
/// and greedily merges neighbors whose x positions fall within
/// [mergeRadiusPx] of the open cluster's running center. Zooming in grows
/// pixels-per-second, so clusters split apart with no extra state. Markers
/// outside the visible time or depth window are omitted.
List<PhotoMarkerCluster> clusterPhotoMarkers({
  required List<({double seconds, double depthDisplay})> points,
  required double visibleMinSeconds,
  required double visibleMaxSeconds,
  required double visibleMinDepth,
  required double visibleMaxDepth,
  required double plotWidth,
  required double plotHeight,
  double mergeRadiusPx = 24,
}) {
  final rangeX = visibleMaxSeconds - visibleMinSeconds;
  final rangeY = visibleMaxDepth - visibleMinDepth;
  if (rangeX <= 0 || rangeY <= 0 || plotWidth <= 0 || plotHeight <= 0) {
    return const [];
  }

  final positioned = <({int index, double x, double y})>[];
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (p.seconds < visibleMinSeconds || p.seconds > visibleMaxSeconds) {
      continue;
    }
    if (p.depthDisplay < visibleMinDepth || p.depthDisplay > visibleMaxDepth) {
      continue;
    }
    positioned.add((
      index: i,
      x: (p.seconds - visibleMinSeconds) / rangeX * plotWidth,
      y: (p.depthDisplay - visibleMinDepth) / rangeY * plotHeight,
    ));
  }
  if (positioned.isEmpty) return const [];

  final clusters = <PhotoMarkerCluster>[];
  var members = <({int index, double x, double y})>[positioned.first];

  double centerX() =>
      members.map((m) => m.x).reduce((a, b) => a + b) / members.length;

  void close() {
    final cy = members.map((m) => m.y).reduce((a, b) => a + b) / members.length;
    clusters.add(
      PhotoMarkerCluster(
        memberIndexes: [for (final m in members) m.index],
        x: centerX(),
        y: cy,
      ),
    );
  }

  for (final p in positioned.skip(1)) {
    if ((p.x - centerX()).abs() <= mergeRadiusPx) {
      members.add(p);
    } else {
      close();
      members = [p];
    }
  }
  close();
  return clusters;
}
