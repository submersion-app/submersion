import 'dart:math' as math;

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// Summary scalars for a route, computed from its raw samples.
///
/// These are exactly the summary columns `nav_tracks` stores redundantly
/// alongside the points blob (so a list row or a stat card never needs to
/// decode it), and this is where those values come from at import time.
///
/// Computed over the active range only ([NavTrackCorrector.activeRangeEndIndex]):
/// a recording with a surface GPS fix (design spec "Ground truth: the
/// Seacraft ENC3 CSV", 011.DAT.csv) has a GPS-fixed jump and a
/// post-surfacing/out-of-water tail after that; the design spec requires
/// statistics to stop at the last dead-reckoned sample, the same boundary
/// the 3D ribbon and the 2D layer already stop at.
class NavTrackStats {
  final int pointCount;
  final int durationSeconds;

  /// Total distance in metres: the device's own `distance` reading at the
  /// last sample when every sample has one and they are non-decreasing,
  /// else the 2D path length -- the same distance-source rule
  /// `NavTrackCorrector` uses, so the number on a route's summary card
  /// matches what its own correction was computed against.
  final double totalDistance;

  final double maxDepth;

  /// Metres per second, or null when no sample carries a speed reading.
  final double? maxSpeed;

  /// Metres per second, or null when no sample carries a speed reading.
  final double? avgSpeed;

  const NavTrackStats({
    required this.pointCount,
    required this.durationSeconds,
    required this.totalDistance,
    required this.maxDepth,
    required this.maxSpeed,
    required this.avgSpeed,
  });

  static NavTrackStats of(List<NavTrackPoint> points) {
    if (points.isEmpty) {
      return const NavTrackStats(
        pointCount: 0,
        durationSeconds: 0,
        totalDistance: 0,
        maxDepth: 0,
        maxSpeed: null,
        avgSpeed: null,
      );
    }

    final activeStart = NavTrackCorrector.activeRangeStartIndex(points);
    final activeEnd = NavTrackCorrector.activeRangeEndIndex(points);
    final active = points.sublist(activeStart, activeEnd + 1);

    var maxDepth = active.first.depth;
    double? maxSpeed;
    var speedSum = 0.0;
    var speedCount = 0;

    for (final p in active) {
      if (p.depth > maxDepth) maxDepth = p.depth;
      final speed = p.speed;
      if (speed != null) {
        speedSum += speed;
        speedCount++;
        if (maxSpeed == null || speed > maxSpeed) maxSpeed = speed;
      }
    }

    return NavTrackStats(
      pointCount: points.length,
      durationSeconds: active.last.timestamp - active.first.timestamp,
      totalDistance: _totalDistance(active),
      maxDepth: maxDepth,
      maxSpeed: maxSpeed,
      avgSpeed: speedCount == 0 ? null : speedSum / speedCount,
    );
  }

  static double _totalDistance(List<NavTrackPoint> points) {
    var deviceDistanceUsable = points.first.distance != null;
    if (deviceDistanceUsable) {
      for (var i = 1; i < points.length; i++) {
        final previous = points[i - 1].distance;
        final current = points[i].distance;
        if (previous == null || current == null || current < previous) {
          deviceDistanceUsable = false;
          break;
        }
      }
    }
    if (deviceDistanceUsable) return points.last.distance!;

    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dNorth = points[i].north - points[i - 1].north;
      final dEast = points[i].east - points[i - 1].east;
      total += math.sqrt(dNorth * dNorth + dEast * dEast);
    }
    return total;
  }
}
