import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

/// Adapts a measured underwater route into the [ReckonedPath] frame the 3D
/// scene already knows how to draw (spec
/// 2026-09-10-underwater-nav-track-design.md, "3D integration on the
/// dive").
///
/// Pure: the corrector runs first, over the whole raw recording, so
/// [NavTrackEndMode.gpsFix] can still resolve its target against the
/// recording's own fix event; the ribbon is then built from the
/// [NavTrackSampleKind.underwater] and [NavTrackSampleKind.surfaceReckoned]
/// samples only, in recording order, and never spans a fix event or an
/// out-of-water run.
class NavTrackPathAdapter {
  const NavTrackPathAdapter._();

  static ReckonedPath toReckonedPath(NavTrack route) {
    final points = route.points;
    if (points.isEmpty) {
      return const ReckonedPath(
        points: [],
        provenance: PathProvenance.measured,
        minEast: 0,
        maxEast: 0,
        minNorth: 0,
        maxNorth: 0,
        maxDepth: 0,
        durationSeconds: 0,
      );
    }

    final corrected = NavTrackCorrector.apply(points, route.correction);
    // Stop at the active range's boundaries (a pre-dive fix event before,
    // a post-dive one after) rather than filtering by kind across the
    // whole recording: a diver who re-descends after a GPS fix produces
    // more `underwater` samples past the jump, and filtering by kind alone
    // would stitch those back onto the pre-fix ribbon, drawing straight
    // across the very jump this adapter must never span.
    // `NavTrackCorrector.activeRangeStartIndex`/`activeRangeEndIndex` is the
    // same "active range" boundary the corrector itself already stops
    // proportional correction at, reused here for consistency.
    final activeStart = NavTrackCorrector.activeRangeStartIndex(points);
    final activeEnd = NavTrackCorrector.activeRangeEndIndex(points);

    final kept = <ReckonedPoint>[];
    int? startTimestamp;
    var minEast = double.infinity, maxEast = double.negativeInfinity;
    var minNorth = double.infinity, maxNorth = double.negativeInfinity;
    var maxDepth = 0.0;

    for (var i = activeStart; i <= activeEnd && i < corrected.length; i++) {
      final p = corrected[i];
      startTimestamp ??= p.timestamp;
      final timeSeconds = (p.timestamp - startTimestamp).toDouble();
      kept.add(
        ReckonedPoint(
          east: p.east,
          north: p.north,
          depth: p.depth,
          timeSeconds: timeSeconds,
        ),
      );
      if (p.east < minEast) minEast = p.east;
      if (p.east > maxEast) maxEast = p.east;
      if (p.north < minNorth) minNorth = p.north;
      if (p.north > maxNorth) maxNorth = p.north;
      if (p.depth > maxDepth) maxDepth = p.depth;
    }

    if (kept.isEmpty) {
      return const ReckonedPath(
        points: [],
        provenance: PathProvenance.measured,
        minEast: 0,
        maxEast: 0,
        minNorth: 0,
        maxNorth: 0,
        maxDepth: 0,
        durationSeconds: 0,
      );
    }

    return ReckonedPath(
      points: kept,
      provenance: PathProvenance.measured,
      sourceLabel: route.source.label,
      minEast: minEast,
      maxEast: maxEast,
      minNorth: minNorth,
      maxNorth: maxNorth,
      maxDepth: maxDepth,
      durationSeconds: kept.last.timeSeconds,
    );
  }
}
