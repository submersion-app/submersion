import 'dart:math';

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../shape/dive_shape.dart';

/// The shape of a scooter run.
enum RoutePattern { outAndBack, loop, reefRun }

/// A scooter dive's underwater route, as a scooter's navigation unit logs
/// it: every five seconds, metres north and east of the entry, and the
/// dive's own depth at that second.
///
/// The diver scoots at a steady 30 to 60 metres a minute through the bottom
/// of the dive and swims slowly on the descent, the ascent and the stops.
/// [startEpochSeconds] is the dive's start on the wall-clock-as-UTC scale
/// the dives use.
List<NavTrackPoint> scooterRoute(
  RoutePattern pattern, {
  required List<ShapeSample> samples,
  required int startEpochSeconds,
  required Random random,
}) {
  if (samples.length < 2) return const [];
  final maxDepth = samples.map((s) => s.depth).reduce(max);
  final bottomFrom = samples.firstWhere((s) => s.depth >= maxDepth * 0.6).t;
  final bottomTo = samples.lastWhere((s) => s.depth >= maxDepth * 0.6).t;
  final scootSpeed = 0.5 + random.nextDouble() * 0.5; // m/s
  final heading = random.nextDouble() * 2 * pi;
  final end = samples.last.t;

  // Distance covered by each point, then the pattern laid over it.
  final times = [for (var t = 0; t <= end; t += 5) t];
  final along = <double>[];
  var travelled = 0.0;
  for (var i = 0; i < times.length; i++) {
    if (i > 0) {
      final t = times[i];
      final speed = t >= bottomFrom && t <= bottomTo ? scootSpeed : 0.1;
      travelled += speed * (t - times[i - 1]);
    }
    along.add(travelled);
  }
  final total = max(1.0, travelled);

  (double, double) offset(double d) {
    switch (pattern) {
      case RoutePattern.outAndBack:
        final x = d <= total / 2 ? d : total - d;
        return (x, 5 * sin(d / 40));
      case RoutePattern.loop:
        final r = total / (2 * pi);
        final a = 2 * pi * d / total;
        return (r * sin(a), r - r * cos(a));
      case RoutePattern.reefRun:
        return (d, 20 * sin(d / 120));
    }
  }

  var s = 0;
  return [
    for (var i = 0; i < times.length; i++)
      () {
        final t = times[i];
        while (s < samples.length - 2 && samples[s + 1].t <= t) {
          s++;
        }
        final a = samples[s], b = samples[min(s + 1, samples.length - 1)];
        final f = b.t == a.t ? 0.0 : ((t - a.t) / (b.t - a.t)).clamp(0.0, 1.0);
        final (x, y) = offset(along[i]);
        return NavTrackPoint(
          timestamp: startEpochSeconds + t,
          north: x * cos(heading) - y * sin(heading),
          east: x * sin(heading) + y * cos(heading),
          depth: max(0, a.depth + (b.depth - a.depth) * f),
        );
      }(),
  ];
}
