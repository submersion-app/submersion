import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';

/// Reconstructs the underwater swim path by dead reckoning: integrating
/// per-sample compass heading times an estimated step distance into a local
/// east-north path, anchored at the entry point. When an exit fix exists,
/// the accumulated path is rubber-banded (linearly drift-corrected) to land
/// on it. With too few headings it falls back to a straight entry->exit
/// line. Pure and isolate-friendly. Honest by construction: the
/// [ReckonedPath.reconstructed] flag distinguishes dead reckoning from the
/// straight-line fallback.
class DeadReckoningService {
  /// Default horizontal swim speed (m/s) when the diver is submerged.
  static const double defaultSwimSpeedMps = 0.25;

  /// Fraction of samples that must carry a heading to dead-reckon.
  static const double _headingCoverageThreshold = 0.5;

  const DeadReckoningService();

  ReckonedPath reckon({
    required List<double> times,
    required List<double> depths,
    required List<double?> headings,
    ({double east, double north})? exitOffset,
    double swimSpeedMps = defaultSwimSpeedMps,
  }) {
    final n = times.length;
    if (n == 0) {
      return const ReckonedPath(
        points: [],
        reconstructed: false,
        minEast: 0,
        maxEast: 0,
        minNorth: 0,
        maxNorth: 0,
        maxDepth: 0,
        durationSeconds: 0,
      );
    }

    final headingCount = headings.where((h) => h != null).length;
    final canReckon = n >= 2 && headingCount >= (n * _headingCoverageThreshold);

    final east = List<double>.filled(n, 0);
    final north = List<double>.filled(n, 0);

    if (canReckon) {
      var lastHeading = headings.firstWhere((h) => h != null)!;
      for (var i = 1; i < n; i++) {
        final dt = times[i] - times[i - 1];
        final h = headings[i] ?? lastHeading;
        lastHeading = h;
        // Only advance while submerged; surface drift is not swimming.
        final step = depths[i] > 1.0 ? swimSpeedMps * dt : 0.0;
        final rad = h * math.pi / 180.0;
        east[i] = east[i - 1] + step * math.sin(rad);
        north[i] = north[i - 1] + step * math.cos(rad);
      }
      if (exitOffset != null) {
        _rubberBand(east, north, times, exitOffset);
      }
    } else {
      // Straight line entry -> exit over time. With no exit fix the target is
      // the origin, so the path has no horizontal component (a vertical
      // descent/ascent): heading data was insufficient to infer a direction,
      // and the "estimated path" caption flags this uncertainty to the diver.
      final target = exitOffset ?? (east: 0.0, north: 0.0);
      final total = times.last - times.first;
      for (var i = 0; i < n; i++) {
        final f = total <= 0 ? 0.0 : (times[i] - times.first) / total;
        east[i] = target.east * f;
        north[i] = target.north * f;
      }
    }

    final points = <ReckonedPoint>[];
    var minE = double.infinity, maxE = double.negativeInfinity;
    var minN = double.infinity, maxN = double.negativeInfinity;
    var maxD = 0.0;
    for (var i = 0; i < n; i++) {
      points.add(
        ReckonedPoint(
          east: east[i],
          north: north[i],
          depth: depths[i],
          timeSeconds: times[i],
        ),
      );
      minE = math.min(minE, east[i]);
      maxE = math.max(maxE, east[i]);
      minN = math.min(minN, north[i]);
      maxN = math.max(maxN, north[i]);
      if (depths[i] > maxD) maxD = depths[i];
    }

    return ReckonedPath(
      points: points,
      reconstructed: canReckon,
      minEast: minE,
      maxEast: maxE,
      minNorth: minN,
      maxNorth: maxN,
      maxDepth: maxD,
      durationSeconds: times.last,
    );
  }

  /// Linearly distributes the endpoint error over the path so it lands on
  /// [exitOffset], proportional to elapsed time.
  void _rubberBand(
    List<double> east,
    List<double> north,
    List<double> times,
    ({double east, double north}) exitOffset,
  ) {
    final n = east.length;
    final errE = exitOffset.east - east[n - 1];
    final errN = exitOffset.north - north[n - 1];
    final total = times.last - times.first;
    for (var i = 0; i < n; i++) {
      final f = total <= 0 ? 0.0 : (times[i] - times.first) / total;
      east[i] += errE * f;
      north[i] += errN * f;
    }
  }
}
