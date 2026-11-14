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

/// Where [item] sits on a profile [maxProfileSeconds] long, or null when it
/// has no place there. The one rule for it: the chart's camera chips and the
/// media hover in dive details (issue #4524) both ask here, so they cannot
/// disagree about an item.
///
/// Photos and videos with a usable profile position have a place; a
/// signature or a document never does. Elapsed time is clamped to the
/// profile range to absorb entry/exit clock skew, but only inside the
/// [MediaDiveWindow] tolerance: a capture time days outside the dive has no
/// place rather than being pinned to the exit (issue #1090). A manual
/// position always passes.
PhotoChartMarker? photoMarkerFor(
  MediaItem item, {
  required int maxProfileSeconds,
}) {
  // Photos AND videos get markers: underwater libraries are often mostly
  // short clips, and enrichment gives both the same (time, depth) position.
  // Signatures and documents are categorically not dive-moment media. A
  // document can still carry an enrichment (the backfill positions whatever
  // is attached to the dive by its date), so it is excluded by type.
  if (item.isSignature || item.isDocument) return null;
  final enrichment = item.enrichment;
  if (enrichment == null) return null;
  if (enrichment.matchConfidence == MatchConfidence.noProfile) return null;
  if (!enrichment.isWithinDiveWindow(maxProfileSeconds)) return null;
  final seconds = enrichment.elapsedSeconds;
  final depth = enrichment.depthMeters;
  if (seconds == null || depth == null) return null;
  return PhotoChartMarker(
    item: item,
    elapsedSeconds: math.min(math.max(seconds, 0), maxProfileSeconds),
    depthMeters: depth,
  );
}

/// Builds chart markers from a dive's media list, time-sorted: every item
/// [photoMarkerFor] gives a place.
List<PhotoChartMarker> photoMarkersFromMedia(
  List<MediaItem> media, {
  required int maxProfileSeconds,
}) {
  return [
    for (final item in media)
      ?photoMarkerFor(item, maxProfileSeconds: maxProfileSeconds),
  ]..sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
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
/// and greedily merges neighbors whose on-screen 2D distance to the open
/// cluster's running centroid is within [mergeRadiusPx]. Zooming in grows
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

  // Greedy left-to-right merge on 2D distance to the running cluster
  // centroid, so only markers that would actually overlap on screen merge.
  // Running sums keep the pass O(n).
  final clusters = <PhotoMarkerCluster>[];
  var memberIndexes = <int>[positioned.first.index];
  var sumX = positioned.first.x;
  var sumY = positioned.first.y;

  void close() {
    clusters.add(
      PhotoMarkerCluster(
        memberIndexes: memberIndexes,
        x: sumX / memberIndexes.length,
        y: sumY / memberIndexes.length,
      ),
    );
  }

  final radiusSquared = mergeRadiusPx * mergeRadiusPx;
  for (final p in positioned.skip(1)) {
    final dx = p.x - sumX / memberIndexes.length;
    final dy = p.y - sumY / memberIndexes.length;
    if (dx * dx + dy * dy <= radiusSquared) {
      memberIndexes.add(p.index);
      sumX += p.x;
      sumY += p.y;
    } else {
      close();
      memberIndexes = [p.index];
      sumX = p.x;
      sumY = p.y;
    }
  }
  close();
  return clusters;
}
