import 'dart:math' as math;

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

/// What a single sample of a measured route represents.
///
/// A route ribbon (2D or 3D) is built only from [underwater] and
/// [surfaceReckoned] samples, in file order, and never spans a
/// [gpsFixed]/[outOfWater] run: those samples are a device re-calibrating
/// its own position against a GPS fix, not the diver's swim path.
enum NavTrackSampleKind {
  /// Depth above the surface threshold: the diver is submerged.
  underwater,

  /// Depth at or below the surface threshold, position still advancing by
  /// dead reckoning (no fix event has occurred yet).
  surfaceReckoned,

  /// From a fix event onward, until depth rises above the surface
  /// threshold again: the device has re-calibrated its position against a
  /// GPS fix and is reporting that position (plus GPS scatter), not a
  /// dead-reckoned swim path.
  gpsFixed,

  /// A [gpsFixed] sample additionally identified as the device sitting out
  /// of the water: its cumulative distance has frozen and its temperature
  /// has drifted the same way, without reverting, for over a minute.
  /// Informational only -- every consumer that excludes [gpsFixed] must
  /// exclude this too.
  outOfWater,
}

/// A step between two consecutive samples large enough that it can only be
/// the device re-calibrating its position against a GPS fix, not the
/// diver actually covering that distance.
class NavTrackFixEvent {
  /// Index into the classified points of the first sample after the jump
  /// (the first [NavTrackSampleKind.gpsFixed] sample of the run it opens).
  final int index;

  /// The jump's local frame position just before the event.
  final double beforeNorth;
  final double beforeEast;

  /// The jump's local frame position just after the event.
  final double afterNorth;
  final double afterEast;

  const NavTrackFixEvent({
    required this.index,
    required this.beforeNorth,
    required this.beforeEast,
    required this.afterNorth,
    required this.afterEast,
  });
}

/// The result of classifying a route's samples.
class NavTrackSegmentation {
  /// One kind per input sample, same length and order as the points that
  /// were classified.
  final List<NavTrackSampleKind> kinds;

  /// Every fix event found, in file order.
  final List<NavTrackFixEvent> fixEvents;

  const NavTrackSegmentation({required this.kinds, required this.fixEvents});
}

/// Classifies the samples of a measured underwater route and finds surface
/// GPS re-calibration jumps within it.
///
/// Pure: runs on read, over whatever a parser already produced, and never
/// rewrites the samples themselves. See the design spec
/// (2026-09-10-underwater-nav-track-design.md, "Segments and GPS fixes")
/// for the reasoning behind each threshold.
class NavTrackSegmenter {
  const NavTrackSegmenter._();

  /// Depth at or below this (metres) counts as "at the surface" for both
  /// the run-boundary rule and the fix-event depth gate.
  static const double _surfaceDepthMeters = 0.3;

  /// A step at least this large (metres) between two consecutive surface
  /// samples, close together in time and not moving at real swimming
  /// speed, is a GPS re-calibration jump rather than genuine travel.
  static const double _fixEventStepMeters = 50;

  /// The two samples of a candidate jump must be no more than this many
  /// seconds apart -- otherwise slow, real drift over a longer gap could
  /// exceed the step threshold too.
  static const int _fixEventMaxGapSeconds = 5;

  /// A reported speed above this (m/s, roughly 60 m/min) rules a step out
  /// as a fix event: no scooter covers 50 m in 5 s.
  static const double _fixEventMaxSpeedMetersPerSecond = 1.0;

  /// How long (seconds) cumulative distance must stay frozen and
  /// temperature must keep drifting the same way, without reverting, for a
  /// [NavTrackSampleKind.gpsFixed] run to be reclassified as
  /// [NavTrackSampleKind.outOfWater].
  static const int _outOfWaterMinDurationSeconds = 60;

  /// A `gpsFixed` run's positions have "settled" once every remaining
  /// sample stays within this radius (metres) of the others: the design
  /// spec's own reading of the real fixture is that positions wobble
  /// within about 10 m for up to 17 minutes after a fix event before the
  /// console has fully converged.
  static const double _stabilizationRadiusMeters = 10;

  /// The stable cluster [stabilizedFixPosition] averages over must contain
  /// at least this many samples, so a single lucky close pair right at the
  /// end of a run is never mistaken for the position having settled.
  static const int _stabilizationMinSamples = 3;

  static NavTrackSegmentation classify(List<NavTrackPoint> points) {
    final n = points.length;
    final kinds = List<NavTrackSampleKind>.filled(
      n,
      NavTrackSampleKind.underwater,
    );
    final fixEvents = <NavTrackFixEvent>[];
    if (n == 0) {
      return NavTrackSegmentation(kinds: kinds, fixEvents: fixEvents);
    }

    kinds[0] = _depthKind(points[0].depth);
    var inFixedRun = false;
    var runStart = -1;
    final runs = <(int, int)>[]; // inclusive start, exclusive end

    for (var i = 1; i < n; i++) {
      final prev = points[i - 1];
      final cur = points[i];

      if (inFixedRun) {
        if (cur.depth > _surfaceDepthMeters) {
          runs.add((runStart, i));
          inFixedRun = false;
          kinds[i] = NavTrackSampleKind.underwater;
        } else {
          kinds[i] = NavTrackSampleKind.gpsFixed;
        }
        continue;
      }

      // Not already inside a fixed run: a second qualifying step once
      // inside one is GPS scatter, not a new event, so detection only
      // ever runs here.
      if (_looksLikeFixEvent(prev, cur)) {
        fixEvents.add(
          NavTrackFixEvent(
            index: i,
            beforeNorth: prev.north,
            beforeEast: prev.east,
            afterNorth: cur.north,
            afterEast: cur.east,
          ),
        );
        inFixedRun = true;
        runStart = i;
        kinds[i] = NavTrackSampleKind.gpsFixed;
      } else {
        kinds[i] = _depthKind(cur.depth);
      }
    }
    if (inFixedRun) {
      runs.add((runStart, n));
    }

    for (final run in runs) {
      _markOutOfWater(points, kinds, run.$1, run.$2);
    }

    return NavTrackSegmentation(kinds: kinds, fixEvents: fixEvents);
  }

  /// The stabilized position within [event]'s `gpsFixed` run: a better
  /// estimate of where the diver actually surfaced than the run's very
  /// first sample.
  ///
  /// A GPS receiver typically takes a little while after surfacing to
  /// converge; the first one or two readings right after a fix event's
  /// jump can still be noisy. This scans forward from the fix event and
  /// finds the EARLIEST run of at least [_stabilizationMinSamples]
  /// consecutive samples whose positions all stay within
  /// [_stabilizationRadiusMeters] of one another (bounding-box diagonal),
  /// then returns the centroid of that cluster, extended as far forward as
  /// it stays within the radius.
  ///
  /// Deliberately anchored to the EARLIEST stable cluster, not the run's
  /// tail: a diver who climbs out and walks around on land while the
  /// console keeps recording produces a second, later "stable" cluster
  /// wherever they stop (e.g. at a car), which is not the exit point. A
  /// backward scan from the run's end would lock onto that later cluster
  /// instead; this forward scan commits to the first genuine settle and
  /// ignores whatever the position does afterwards. Uses position data
  /// only -- no temperature or distance-freeze signal, which would need
  /// tuning per device and says nothing about where the diver actually
  /// came out of the water.
  ///
  /// Falls back to the longest stable-or-partial run found (or a single
  /// sample, for a run shorter than [_stabilizationMinSamples]) when
  /// nothing reaches the minimum sample count.
  static ({double north, double east}) stabilizedFixPosition(
    List<NavTrackPoint> points,
    NavTrackFixEvent event,
  ) {
    final n = points.length;
    var runEnd = n; // exclusive
    for (var i = event.index + 1; i < n; i++) {
      if (points[i].depth > _surfaceDepthMeters) {
        runEnd = i;
        break;
      }
    }
    final runStart = event.index;

    var bestStart = runStart;
    var bestLength = 1;

    for (var i = runStart; i < runEnd; i++) {
      var minNorth = points[i].north;
      var maxNorth = minNorth;
      var minEast = points[i].east;
      var maxEast = minEast;
      var length = 1;

      for (var j = i + 1; j < runEnd; j++) {
        final north = points[j].north;
        final east = points[j].east;
        final candidateMinNorth = math.min(minNorth, north);
        final candidateMaxNorth = math.max(maxNorth, north);
        final candidateMinEast = math.min(minEast, east);
        final candidateMaxEast = math.max(maxEast, east);
        final dn = candidateMaxNorth - candidateMinNorth;
        final de = candidateMaxEast - candidateMinEast;
        if (math.sqrt(dn * dn + de * de) > _stabilizationRadiusMeters) break;
        minNorth = candidateMinNorth;
        maxNorth = candidateMaxNorth;
        minEast = candidateMinEast;
        maxEast = candidateMaxEast;
        length++;
      }

      if (length > bestLength) {
        bestStart = i;
        bestLength = length;
      }
      if (length >= _stabilizationMinSamples) break;
    }

    var sumNorth = 0.0;
    var sumEast = 0.0;
    for (var i = bestStart; i < bestStart + bestLength; i++) {
      sumNorth += points[i].north;
      sumEast += points[i].east;
    }
    return (north: sumNorth / bestLength, east: sumEast / bestLength);
  }

  static NavTrackSampleKind _depthKind(double depth) =>
      depth > _surfaceDepthMeters
      ? NavTrackSampleKind.underwater
      : NavTrackSampleKind.surfaceReckoned;

  static bool _looksLikeFixEvent(NavTrackPoint prev, NavTrackPoint cur) {
    if (prev.depth > _surfaceDepthMeters || cur.depth > _surfaceDepthMeters) {
      return false;
    }
    final dt = cur.timestamp - prev.timestamp;
    if (dt <= 0 || dt > _fixEventMaxGapSeconds) return false;
    final speed = cur.speed;
    if (speed != null && speed > _fixEventMaxSpeedMetersPerSecond) {
      return false;
    }
    final dn = cur.north - prev.north;
    final de = cur.east - prev.east;
    final stepMeters = math.sqrt(dn * dn + de * de);
    return stepMeters > _fixEventStepMeters;
  }

  /// Reclassifies the tail of one [NavTrackSampleKind.gpsFixed] run
  /// [start, end) as [NavTrackSampleKind.outOfWater] once its distance has
  /// frozen at the run's own first reading and its temperature has stayed
  /// on one side of that first reading (never reverting to it) for at
  /// least [_outOfWaterMinDurationSeconds].
  static void _markOutOfWater(
    List<NavTrackPoint> points,
    List<NavTrackSampleKind> kinds,
    int start,
    int end,
  ) {
    final frozenDistance = points[start].distance;
    final freezeTemp = points[start].temperature;
    if (frozenDistance == null || freezeTemp == null) return;

    var holdStart = -1;
    var direction = 0; // -1, 0 (unknown yet), or 1
    var thresholdCrossed = false;

    for (var i = start + 1; i < end; i++) {
      final p = points[i];
      final temp = p.temperature;
      final distanceHolds = p.distance == frozenDistance;
      var holds = distanceHolds && temp != null && temp != freezeTemp;
      if (holds) {
        final d = temp > freezeTemp ? 1 : -1;
        if (direction == 0) {
          direction = d;
        } else if (d != direction) {
          holds = false;
        }
      }

      if (holds) {
        if (holdStart < 0) {
          holdStart = i;
          thresholdCrossed = false;
        }
        if (!thresholdCrossed &&
            p.timestamp - points[holdStart].timestamp >=
                _outOfWaterMinDurationSeconds) {
          thresholdCrossed = true;
        }
        if (thresholdCrossed) {
          kinds[i] = NavTrackSampleKind.outOfWater;
        }
      } else {
        holdStart = -1;
        direction = 0;
        thresholdCrossed = false;
      }
    }
  }
}
