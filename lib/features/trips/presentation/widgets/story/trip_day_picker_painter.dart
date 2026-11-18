import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/trips/domain/services/trip_picker_model.dart';

/// Where the surface line sits, from the top of a tile.
const double kTripPickerSurfaceY = 4;

/// Clear space under the deepest dive of the trip.
const double kTripPickerBottomInset = 2;

/// Clear space at each side of a tile, so neighbouring days never touch.
const double kTripPickerSideInset = 3;

/// The gap between two dives of one day.
const double kTripPickerDiveGap = 2;

/// The narrowest a dive is drawn, so a very short one stays visible.
const double kTripPickerMinDiveWidth = 3;

/// One dive laid out inside a tile.
class TripPickerShape {
  const TripPickerShape({
    required this.path,
    required this.bounds,
    required this.dashed,
  });

  /// The dive's outline, closed along the surface line.
  final Path path;
  final Rect bounds;

  /// An estimate, or a dive that has not happened: outline only, dashed.
  final bool dashed;
}

/// Lays [day]'s dives out inside a tile of [size], on the trip's scales.
///
/// Depth and time each use one scale for the whole trip, which is what makes
/// two days comparable: [maxDepth] reaches the bottom of the tile, and
/// [widestDaySeconds] spans its usable width. A day whose dives and gaps
/// would not fit (the widest day's own gaps, or minimum widths on a crowded
/// day) shrinks them together until they do. Time runs left to right in
/// every text direction, as it does on every chart in the app.
List<TripPickerShape> layoutTripPickerDay(
  TripPickerDay day, {
  required Size size,
  required double maxDepth,
  required double widestDaySeconds,
}) {
  if (day.dives.isEmpty || maxDepth <= 0 || widestDaySeconds <= 0) {
    return const [];
  }
  final usable = size.width - 2 * kTripPickerSideInset;
  final drop = size.height - kTripPickerSurfaceY - kTripPickerBottomInset;
  if (usable <= 0 || drop <= 0) return const [];

  final pointsPerSecond = usable / widestDaySeconds;
  final pointsPerMeter = drop / maxDepth;
  var widths = [
    for (final dive in day.dives)
      math.max(kTripPickerMinDiveWidth, dive.spanSeconds * pointsPerSecond),
  ];
  var gap = kTripPickerDiveGap;
  var total = widths.sum + gap * (widths.length - 1);
  if (total > usable) {
    final fit = usable / total;
    widths = [for (final w in widths) w * fit];
    gap *= fit;
    total = usable;
  }

  final shapes = <TripPickerShape>[];
  var left = kTripPickerSideInset + (usable - total) / 2;
  for (var i = 0; i < day.dives.length; i++) {
    final dive = day.dives[i];
    final width = widths[i];
    final path = Path()..moveTo(left, kTripPickerSurfaceY);
    for (final point in dive.points) {
      path.lineTo(
        left + point.seconds / dive.spanSeconds * width,
        kTripPickerSurfaceY + point.depth * pointsPerMeter,
      );
    }
    path
      ..lineTo(left + width, kTripPickerSurfaceY)
      ..close();
    shapes.add(
      TripPickerShape(
        path: path,
        bounds: path.getBounds(),
        dashed: dive.dashed,
      ),
    );
    left += width + gap;
  }
  return shapes;
}

/// Paints one day's tile of the trip day picker: the surface line, with the
/// day's dives hanging from it.
class TripDayPickerPainter extends CustomPainter {
  TripDayPickerPainter({
    required this.day,
    required this.maxDepth,
    required this.widestDaySeconds,
    required this.surfaceColor,
    required this.shapeColor,
    required this.fillOpacity,
  });

  final TripPickerDay day;
  final double maxDepth;
  final double widestDaySeconds;

  /// The surface line's colour.
  final Color surfaceColor;

  /// The colour of a dive's outline; its fill is this at [fillOpacity].
  final Color shapeColor;
  final double fillOpacity;

  static const double _dashOn = 3;
  static const double _dashOff = 3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(0, kTripPickerSurfaceY),
      Offset(size.width, kTripPickerSurfaceY),
      Paint()
        ..color = surfaceColor
        ..strokeWidth = 1.5,
    );

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = shapeColor.withValues(alpha: shapeColor.a * fillOpacity);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round
      ..color = shapeColor;

    final shapes = layoutTripPickerDay(
      day,
      size: size,
      maxDepth: maxDepth,
      widestDaySeconds: widestDaySeconds,
    );
    for (final shape in shapes) {
      if (shape.dashed) {
        canvas.drawPath(
          dashedPath(shape.path, dash: _dashOn, gap: _dashOff),
          outline,
        );
      } else {
        canvas
          ..drawPath(shape.path, fill)
          ..drawPath(shape.path, outline);
      }
    }
  }

  @override
  bool shouldRepaint(TripDayPickerPainter oldDelegate) =>
      oldDelegate.day != day ||
      oldDelegate.maxDepth != maxDepth ||
      oldDelegate.widestDaySeconds != widestDaySeconds ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.shapeColor != shapeColor ||
      oldDelegate.fillOpacity != fillOpacity;
}
