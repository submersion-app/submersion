import 'dart:ui';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Pure (time, depth) to pixel mapping for the plan profile chart, plus tick
/// intervals and inverse hit-testing. Positions work in metric depth;
/// [depthUnitScale] (display units per meter) only shapes tick spacing so
/// grid lines land on round display values.
class PlanChartGeometry {
  final Size size;
  final double maxTimeSeconds;
  final double maxDepthMeters;
  final double depthUnitScale;

  static const double leftGutter = 44;
  static const double bottomGutter = 24;
  static const double topPad = 12;
  static const double rightPad = 12;

  const PlanChartGeometry({
    required this.size,
    required this.maxTimeSeconds,
    required this.maxDepthMeters,
    required this.depthUnitScale,
  });

  Rect get plotRect => Rect.fromLTRB(
    leftGutter,
    topPad,
    size.width - rightPad,
    size.height - bottomGutter,
  );

  double get _paddedMaxTime => maxTimeSeconds > 0 ? maxTimeSeconds * 1.05 : 600;
  double get _paddedMaxDepth => maxDepthMeters > 0 ? maxDepthMeters * 1.1 : 10;

  double xFor(double timeSeconds) =>
      plotRect.left + (timeSeconds / _paddedMaxTime) * plotRect.width;

  double yFor(double depthMeters) =>
      plotRect.top + (depthMeters / _paddedMaxDepth) * plotRect.height;

  Offset toPixel(double timeSeconds, double depthMeters) =>
      Offset(xFor(timeSeconds), yFor(depthMeters));

  /// Inverse of [xFor], clamped to the data range (not the padded range) so
  /// scrubbing never reads past the end of the plan.
  double timeAtDx(double dx) {
    if (maxTimeSeconds <= 0) return 0;
    final t = (dx - plotRect.left) / plotRect.width * _paddedMaxTime;
    return t.clamp(0.0, maxTimeSeconds);
  }

  /// Inverse of [yFor], clamped to the padded depth range (unlike [timeAtDx],
  /// which clamps to the data range): a drag may extend a waypoint into the
  /// padding below the deepest planned point, but never past the axis edge.
  double depthAtDy(double dy) {
    final d = (dy - plotRect.top) / plotRect.height * _paddedMaxDepth;
    return d.clamp(0.0, _paddedMaxDepth);
  }

  double get timeTickIntervalSeconds => niceInterval(_paddedMaxTime / 60) * 60;

  double get depthTickIntervalMeters =>
      niceInterval(_paddedMaxDepth * depthUnitScale) / depthUnitScale;

  /// Legacy interval ladder from the fl_chart implementation, preserved so
  /// grid density matches diver expectations.
  static double niceInterval(double maxValue) {
    if (maxValue <= 0) return 5;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 5;
    if (maxValue <= 50) return 10;
    if (maxValue <= 100) return 20;
    return 30;
  }

  /// Time-weighted mean depth of a polyline profile (trapezoidal rule).
  static double meanDepthMeters(List<CanvasPoint> profile) {
    if (profile.length < 2) return 0;
    double weighted = 0;
    for (var i = 1; i < profile.length; i++) {
      final dt = profile[i].timeSeconds - profile[i - 1].timeSeconds;
      weighted += dt * (profile[i].depth + profile[i - 1].depth) / 2;
    }
    final total = profile.last.timeSeconds - profile.first.timeSeconds;
    return total > 0 ? weighted / total : 0;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanChartGeometry &&
      other.size == size &&
      other.maxTimeSeconds == maxTimeSeconds &&
      other.maxDepthMeters == maxDepthMeters &&
      other.depthUnitScale == depthUnitScale;

  @override
  int get hashCode =>
      Object.hash(size, maxTimeSeconds, maxDepthMeters, depthUnitScale);
}

/// The user-authored segment whose time span covers [timeSeconds], or null
/// when the time falls in the computed ascent past the last segment.
String? segmentIdAtTime(List<PlanSegment> segments, double timeSeconds) {
  final ordered = List<PlanSegment>.from(segments)
    ..sort((a, b) => a.order.compareTo(b.order));
  var elapsed = 0.0;
  for (final segment in ordered) {
    final end = elapsed + segment.durationSeconds;
    if (timeSeconds >= elapsed && timeSeconds <= end) return segment.id;
    elapsed = end;
  }
  return null;
}
