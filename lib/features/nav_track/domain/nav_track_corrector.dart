import 'dart:math' as math;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';

/// How a route's recorded end should be reconciled with where the diver
/// says it actually ended.
enum NavTrackEndMode {
  /// No drift correction: the route is used exactly as recorded (after
  /// [NavTrackCorrection.headingOffsetDeg] rotation).
  none,

  /// The route should end where it started -- a loop.
  sameAsStart,

  /// The route should end at [NavTrackCorrection.endPoint], reached via
  /// [NavTrackCorrection.anchor].
  point,

  /// The route should end at the recording's own surface GPS fix, when it
  /// has one (see `NavTrackSegmenter`). Silently behaves as [none] when
  /// the recording has no fix event -- the UI only ever offers this mode
  /// when one exists, so this is a defensive fallback, not a case the
  /// diver is expected to hit.
  gpsFix,
}

/// How a route's raw recording is placed on the map and reconciled with a
/// known end point. Every field is optional to apply: the default value of
/// each corresponds to "make no correction of this kind".
class NavTrackCorrection {
  /// Where the route's local (0, 0) origin sits on the map. Required for
  /// [NavTrackEndMode.point] (to resolve [endPoint] into the route's local
  /// frame); irrelevant to every other mode, since [sameAsStart] and
  /// [gpsFix] targets are already expressed in the recording's own frame.
  final GeoPoint? anchor;

  final NavTrackEndMode endMode;

  /// The target for [NavTrackEndMode.point]. Ignored otherwise.
  final GeoPoint? endPoint;

  /// Fraction of the route's cumulative distance, 0 to 1, up to which the
  /// recording is taken as correct. 0 (default) rubber-bands the whole
  /// route toward the target; 1 disables the correction entirely.
  final double trustFraction;

  /// Clockwise rotation, in degrees, applied to every raw (north, east)
  /// before any drift correction.
  final double headingOffsetDeg;

  const NavTrackCorrection({
    this.anchor,
    this.endMode = NavTrackEndMode.none,
    this.endPoint,
    this.trustFraction = 0,
    this.headingOffsetDeg = 0,
  });

  NavTrackCorrection copyWith({
    GeoPoint? anchor,
    NavTrackEndMode? endMode,
    GeoPoint? endPoint,
    double? trustFraction,
    double? headingOffsetDeg,
  }) {
    return NavTrackCorrection(
      anchor: anchor ?? this.anchor,
      endMode: endMode ?? this.endMode,
      endPoint: endPoint ?? this.endPoint,
      trustFraction: trustFraction ?? this.trustFraction,
      headingOffsetDeg: headingOffsetDeg ?? this.headingOffsetDeg,
    );
  }
}

/// One sample after rotation and drift correction: the local frame the 2D
/// layer, the 3D adapter, and the terrain check all read from. Depth and
/// timestamp pass through [NavTrackCorrector.apply] unchanged.
class CorrectedNavTrackPoint {
  final int timestamp;
  final double east;
  final double north;
  final double depth;

  const CorrectedNavTrackPoint({
    required this.timestamp,
    required this.east,
    required this.north,
    required this.depth,
  });
}

/// Applies a [NavTrackCorrection] to a route's raw samples.
///
/// Pure, and the single place every consumer of a corrected route (the 2D
/// layer, the 3D path adapter, the terrain check) reads from -- see the
/// design spec (2026-09-10-underwater-nav-track-design.md, "Georeferencing
/// and drift correction") for the reasoning behind each step. Never
/// rewrites [NavTrackPoint]s; always produces a fresh list, same length
/// and order as the input.
class NavTrackCorrector {
  const NavTrackCorrector._();

  /// The first index of [points] that [apply] treats as part of the active
  /// correction range -- the start of the real dive.
  ///
  /// Usually 0. When the recording opens with a GPS-fix event *before* the
  /// diver ever descends (the console re-acquires a surface fix, then the
  /// diver dives -- see `NavTrackSegmenter`'s own generic fix-event
  /// detection, which does not assume a fix can only happen after the
  /// dive), everything up to and including that pre-dive fix run is a
  /// calibration, not the diver's swim path, and is skipped: [start] then
  /// lands on the first sample of the real dive.
  ///
  /// Exposed for the same reason as [activeRangeEndIndex]: presentation
  /// code that needs "the part of the route the correction actually
  /// reaches" (the alignment page's trust slider, the terrain check) must
  /// share this boundary instead of assuming the active range always
  /// starts at 0.
  static int activeRangeStartIndex(List<NavTrackPoint> points) {
    if (points.isEmpty) return 0;
    final segmentation = NavTrackSegmenter.classify(points);
    return _activeRange(segmentation, points.length).start;
  }

  /// The last index of [points] that [apply] treats as part of the active
  /// correction range for every mode but [NavTrackEndMode.none] -- the
  /// last [NavTrackSampleKind.underwater] or
  /// [NavTrackSampleKind.surfaceReckoned] sample of the real dive, i.e.
  /// everything up to but excluding a post-dive GPS-fix event.
  ///
  /// Exposed so presentation code that needs a distance axis over "the
  /// part of the route the correction actually reaches" (the alignment
  /// page's trust slider) shares exactly this boundary instead of
  /// computing its own over the full raw recording: a recording with a
  /// GPS-fix event is dominated by the jump and the post-surfacing wobble,
  /// so a slider computed over the whole thing disagrees with where
  /// [apply] actually freezes the route, making an "already frozen"
  /// prefix look like it is still moving as the diver drags the slider.
  static int activeRangeEndIndex(List<NavTrackPoint> points) {
    if (points.isEmpty) return 0;
    final segmentation = NavTrackSegmenter.classify(points);
    return _activeRange(segmentation, points.length).end;
  }

  static List<CorrectedNavTrackPoint> apply(
    List<NavTrackPoint> points,
    NavTrackCorrection correction,
  ) {
    if (points.isEmpty) return const [];

    final rotated = [
      for (final p in points) _rotate(p, correction.headingOffsetDeg),
    ];

    final target = _resolveTarget(points, rotated, correction);
    if (target == null) return rotated;

    final cumulative = cumulativeDistances(
      points,
      start: target.start,
      end: target.end,
    );
    final sLast = cumulative[target.end];
    final sTrust = correction.trustFraction.clamp(0.0, 1.0) * sLast;
    final denominator = sLast - sTrust;

    if (denominator <= 0) {
      // trustFraction is 1 (or numerically indistinguishable from it), or
      // the active range has zero length: there is nothing to distribute
      // the residual over, so the recording stands as rotated.
      return rotated;
    }

    final last = rotated[target.end];
    final residualEast = target.east - last.east;
    final residualNorth = target.north - last.north;

    return [
      for (var i = 0; i < rotated.length; i++)
        if (i < target.start || i > target.end || cumulative[i] <= sTrust)
          rotated[i]
        else
          _shift(
            rotated[i],
            residualEast * (cumulative[i] - sTrust) / denominator,
            residualNorth * (cumulative[i] - sTrust) / denominator,
          ),
    ];
  }

  /// The correction target and the active range (start and end index) the
  /// proportional correction applies to, or null when [correction] resolves
  /// to no correction at all (mode [NavTrackEndMode.none], or a mode whose
  /// inputs are incomplete: [NavTrackEndMode.point] without both [anchor]
  /// and [endPoint], or [NavTrackEndMode.gpsFix] on a recording with no
  /// fix event after the active range).
  ///
  /// The active range is the same for every mode but [none]: see
  /// [_activeRange]. On a recording with no fix event this is the whole
  /// recording, same as before. On a recording with a pre-dive and/or
  /// post-dive fix event it excludes both: everything before the real dive
  /// (a pre-dive GPS calibration) and everything from a post-dive fix
  /// onward is the device's own GPS-derived position, excluded from
  /// rendering entirely by `NavTrackSampleKind` (`NavTrackPolylineLayer.kept`,
  /// `NavTrackPathAdapter`). Computing the cumulative distance denominator
  /// (or the [NavTrackEndMode.sameAsStart] target) over samples outside
  /// this range would swamp the correction budget, or anchor "the start"
  /// on a sample that is not actually where the dive began.
  static ({double east, double north, int start, int end})? _resolveTarget(
    List<NavTrackPoint> points,
    List<CorrectedNavTrackPoint> rotated,
    NavTrackCorrection correction,
  ) {
    if (correction.endMode == NavTrackEndMode.none) return null;

    final segmentation = NavTrackSegmenter.classify(points);
    final range = _activeRange(segmentation, rotated.length);

    switch (correction.endMode) {
      case NavTrackEndMode.none:
        return null; // handled above; unreachable here
      case NavTrackEndMode.sameAsStart:
        final startPoint = rotated[range.start];
        return (
          east: startPoint.east,
          north: startPoint.north,
          start: range.start,
          end: range.end,
        );
      case NavTrackEndMode.point:
        final anchor = correction.anchor;
        final endPoint = correction.endPoint;
        if (anchor == null || endPoint == null) return null;
        final offset = offsetFromAnchor(anchor, endPoint);
        return (
          east: offset.east,
          north: offset.north,
          start: range.start,
          end: range.end,
        );
      case NavTrackEndMode.gpsFix:
        // The first fix event that occurs AFTER the active range, i.e. a
        // post-dive fix -- never a pre-dive one that [_activeRange] already
        // skipped past to find [range.start]. Fix events are in file order,
        // so the first one past [range.end] is also the earliest.
        NavTrackFixEvent? postDiveFix;
        for (final event in segmentation.fixEvents) {
          if (event.index > range.end) {
            postDiveFix = event;
            break;
          }
        }
        if (postDiveFix == null) return null;
        final stabilized = NavTrackSegmenter.stabilizedFixPosition(
          points,
          postDiveFix,
        );
        final target = _rotateNorthEast(
          stabilized.north,
          stabilized.east,
          correction.headingOffsetDeg,
        );
        return (
          east: target.east,
          north: target.north,
          start: range.start,
          end: range.end,
        );
    }
  }

  /// The active range of [segmentation]'s classified samples: the start and
  /// end index of the real dive, i.e. the contiguous run of
  /// [NavTrackSampleKind.underwater] / [NavTrackSampleKind.surfaceReckoned]
  /// samples that make up the actual dive, excluding any pre-dive GPS
  /// calibration at the start and any post-dive fix event/out-of-water tail
  /// at the end.
  ///
  /// A fix event can happen before the diver ever descends (the console
  /// re-acquires a surface fix, then the diver dives) as well as after (the
  /// far more common case: the console re-acquires GPS once the diver
  /// surfaces). Both must be excluded from the active range, not just the
  /// trailing one: including a pre-dive calibration would make `sameAsStart`
  /// anchor on the recording's very first sample -- which may sit wherever
  /// the console was before the diver even entered the water -- instead of
  /// where the dive actually began, and would let a large pre-dive jump
  /// swamp the trust-fraction distance budget the same way an unexcluded
  /// post-dive jump used to.
  ///
  /// A pre-dive fix is identified by occurring at or before the first
  /// [NavTrackSampleKind.underwater] sample in the whole recording (the
  /// same test the alignment page's own pre-dive-fix start suggestion
  /// uses): real diving has not started yet, so any fix event up to that
  /// point -- and everything before it, including the leading
  /// [NavTrackSampleKind.surfaceReckoned] sample(s) that sit before the
  /// jump itself -- is calibration, not the swim path. [start] then lands
  /// on the first active sample once that fix event's
  /// [NavTrackSampleKind.gpsFixed]/[NavTrackSampleKind.outOfWater] run ends.
  /// From [start], [end] is the last sample of the following contiguous
  /// active run: the index right before the next excluded sample (a
  /// post-dive fix event), or the last raw sample when there is none.
  ///
  /// Falls back to the whole recording when no active sample can be found
  /// at all (an edge case the parser's `tooShort` check should already
  /// prevent, but this keeps the corrector from producing a degenerate
  /// zero-length active range instead of failing loudly elsewhere).
  static ({int start, int end}) _activeRange(
    NavTrackSegmentation segmentation,
    int length,
  ) {
    final kinds = segmentation.kinds;
    if (kinds.isEmpty) return (start: 0, end: length > 0 ? length - 1 : 0);

    bool isActive(NavTrackSampleKind kind) =>
        kind == NavTrackSampleKind.underwater ||
        kind == NavTrackSampleKind.surfaceReckoned;

    final firstUnderwaterIndex = kinds.indexOf(NavTrackSampleKind.underwater);

    var start = 0;
    if (firstUnderwaterIndex > 0) {
      NavTrackFixEvent? preDiveFix;
      for (final event in segmentation.fixEvents) {
        if (event.index <= firstUnderwaterIndex) preDiveFix = event;
      }
      if (preDiveFix != null) {
        start = preDiveFix.index;
        while (start < kinds.length && !isActive(kinds[start])) {
          start++;
        }
      }
    }

    if (start >= kinds.length || !isActive(kinds[start])) {
      return (start: 0, end: length - 1);
    }

    var end = start;
    while (end + 1 < kinds.length && isActive(kinds[end + 1])) {
      end++;
    }
    return (start: start, end: end);
  }

  static CorrectedNavTrackPoint _rotate(
    NavTrackPoint p,
    double headingOffsetDeg,
  ) {
    final r = _rotateNorthEast(p.north, p.east, headingOffsetDeg);
    return CorrectedNavTrackPoint(
      timestamp: p.timestamp,
      east: r.east,
      north: r.north,
      depth: p.depth,
    );
  }

  /// Rotates a raw (north, east) pair by [headingOffsetDeg], the same
  /// transform [_rotate] applies to a whole sample. Shared so a target
  /// derived from raw coordinates (e.g. [NavTrackSegmenter.stabilizedFixPosition])
  /// can be placed in the same rotated frame as [_rotate]'s output before
  /// being compared against it.
  static ({double east, double north}) _rotateNorthEast(
    double north,
    double east,
    double headingOffsetDeg,
  ) {
    if (headingOffsetDeg == 0) return (east: east, north: north);
    final theta = headingOffsetDeg * math.pi / 180.0;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);
    // A clockwise rotation by theta (matching compass bearings: 0 = north,
    // 90 = east): a point due north rotates toward due east as theta grows
    // toward 90.
    return (
      east: east * cosT + north * sinT,
      north: north * cosT - east * sinT,
    );
  }

  /// Cumulative distance for indices `start..end` inclusive, zero-based at
  /// [start] (`result[start] == 0`); indices outside `start..end` are left
  /// at 0 and are never read by [apply].
  ///
  /// Prefers the device's own `distance` channel when every sample in that
  /// range has one and they are non-decreasing (a scooter's dead-reckoning
  /// error grows with distance travelled, not with elapsed time, so a
  /// route that sits still should not accumulate correction meanwhile);
  /// otherwise falls back to the 2D path length of the rotated points
  /// (equivalent to the raw points' path length, since rotation preserves
  /// distance -- so this reads directly from [points]' own north/east and
  /// needs no rotated copy). The device channel is read relative to
  /// `points[start]`, not the raw recording's absolute index 0, so a
  /// pre-dive calibration segment's own distance reading (frozen or
  /// otherwise) never leaks into the dive's distance budget.
  ///
  /// Exposed so presentation code that needs a distance axis over part of
  /// a route (the alignment page's trust slider) shares exactly this
  /// distance-source rule instead of unconditionally recomputing geometric
  /// path length: on an ENC log the device `distance` channel and the 2D
  /// path length can disagree (a route that loops back near itself keeps
  /// accumulating device distance from the speed log while its geometric
  /// path length barely grows), so a slider computed independently could
  /// point at a different sample than [apply] actually freezes.
  static List<double> cumulativeDistances(
    List<NavTrackPoint> points, {
    int start = 0,
    int? end,
  }) {
    if (points.isEmpty) return const [];
    final lastIndex = end ?? points.length - 1;

    var deviceDistanceUsable = points[start].distance != null;
    if (deviceDistanceUsable) {
      for (var i = start + 1; i <= lastIndex; i++) {
        final previous = points[i - 1].distance;
        final current = points[i].distance;
        if (previous == null || current == null || current < previous) {
          deviceDistanceUsable = false;
          break;
        }
      }
    }

    final result = List<double>.filled(points.length, 0);
    if (deviceDistanceUsable) {
      final base = points[start].distance!;
      for (var i = start; i <= lastIndex; i++) {
        result[i] = points[i].distance! - base;
      }
      return result;
    }

    for (var i = start + 1; i <= lastIndex; i++) {
      final dEast = points[i].east - points[i - 1].east;
      final dNorth = points[i].north - points[i - 1].north;
      result[i] = result[i - 1] + math.sqrt(dEast * dEast + dNorth * dNorth);
    }
    return result;
  }

  static CorrectedNavTrackPoint _shift(
    CorrectedNavTrackPoint p,
    double dEast,
    double dNorth,
  ) => CorrectedNavTrackPoint(
    timestamp: p.timestamp,
    east: p.east + dEast,
    north: p.north + dNorth,
    depth: p.depth,
  );
}
