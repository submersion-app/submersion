import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';
import 'package:submersion/features/planner/presentation/chart/stop_tag_layouter.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// The data layer of the plan chart: ghost contingency profile, gradient
/// fill, the profile line itself, the mean-depth line, gas-switch flags, and
/// collision-avoided stop tags.
class PlanChartSeriesPainter extends CustomPainter {
  final PlanChartGeometry geometry;
  final PlanChartPalette palette;
  final PlanCanvasSeries series;
  final PlanCanvasSeries? ghost;

  /// The logged profile of the dive a "What if..." plan was built from,
  /// drawn dashed under the plan so the diver can see how far they have
  /// moved from what they actually did. Null for ordinary plans.
  final PlanCanvasSeries? sourceDive;
  final List<PlanStopTag> stopTags;
  final String meanDepthLabel;
  final TextStyle labelStyle;
  final TextStyle tagStyle;
  final TextDirection textDirection;

  const PlanChartSeriesPainter({
    required this.geometry,
    required this.palette,
    required this.series,
    required this.ghost,
    this.sourceDive,
    required this.stopTags,
    required this.meanDepthLabel,
    required this.labelStyle,
    required this.tagStyle,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plotRect;

    // Source dive's actual profile under everything.
    final actual = sourceDive;
    if (actual != null && actual.profile.length >= 2) {
      canvas.drawPath(
        dashedPath(_polyline(actual.profile), dash: 6, gap: 4),
        Paint()
          ..color = palette.sourceDiveLine
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    // Ghost contingency profile under everything.
    final ghostSeries = ghost;
    if (ghostSeries != null && ghostSeries.profile.length >= 2) {
      canvas.drawPath(
        dashedPath(_polyline(ghostSeries.profile), dash: 5, gap: 4),
        Paint()
          ..color = palette.ghostLine
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    if (series.profile.length >= 2) {
      // Gradient fill between the profile and the surface.
      final fill = Path.from(_polyline(series.profile))
        ..lineTo(geometry.xFor(series.profile.last.timeSeconds), plot.top)
        ..lineTo(geometry.xFor(series.profile.first.timeSeconds), plot.top)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.profileFillTop, palette.profileFillBottom],
          ).createShader(plot),
      );

      // Mean-depth line (dashed) with a right-aligned label above it.
      final mean = PlanChartGeometry.meanDepthMeters(series.profile);
      if (mean > 0) {
        final y = geometry.yFor(mean);
        final line = Path()
          ..moveTo(plot.left, y)
          ..lineTo(plot.right, y);
        canvas.drawPath(
          dashedPath(line, dash: 8, gap: 5),
          Paint()
            ..color = palette.meanDepthLine
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );
        final label = layoutLabel(
          meanDepthLabel,
          labelStyle.copyWith(color: palette.meanDepthLine),
          textDirection,
        );
        label.paint(
          canvas,
          Offset(plot.right - label.width - 4, y - label.height - 2),
        );
      }

      // The profile line.
      canvas.drawPath(
        _polyline(series.profile),
        Paint()
          ..color = palette.profileLine
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Gas-switch flags: dashed stem from the surface to the switch, pill on
    // top with the gas name, dropped a row where it would print over an
    // earlier one.
    final flags = [
      for (final marker in series.gasSwitches)
        (
          marker: marker,
          x: geometry.xFor(marker.timeSeconds),
          label: layoutLabel(
            marker.label,
            tagStyle.copyWith(color: palette.gasFlag),
            textDirection,
          ),
        ),
    ];
    final pills = gasFlagPills(
      xs: [for (final flag in flags) flag.x],
      sizes: [
        for (final flag in flags)
          Size(flag.label.width + 12, flag.label.height + 6),
      ],
      plot: plot,
    );
    for (var i = 0; i < flags.length; i++) {
      final (:marker, :x, :label) = flags[i];
      final stem = Path()
        ..moveTo(x, plot.top)
        ..lineTo(x, geometry.yFor(marker.depth));
      canvas.drawPath(
        dashedPath(stem, dash: 3, gap: 3),
        Paint()
          ..color = palette.gasFlag
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );
      final pill = RRect.fromRectAndRadius(pills[i], const Radius.circular(8));
      canvas.drawRRect(pill, Paint()..color = palette.gasFlagBackground);
      label.paint(canvas, Offset(pill.left + 6, pill.top + 3));
    }

    // Stop tags with collision avoidance. A change against the base plan
    // rides in a second pill inside the same laid-out box, so it moves with
    // its tag.
    if (stopTags.isNotEmpty) {
      const changeGap = 3.0;
      final labels = [
        for (final tag in stopTags)
          (
            main: layoutLabel(
              tag.label,
              tagStyle.copyWith(
                color: tag.isNew
                    ? palette.stopTagChangeText
                    : palette.stopTagText,
              ),
              textDirection,
            ),
            change: tag.change == null
                ? null
                : layoutLabel(
                    tag.change!,
                    tagStyle.copyWith(color: palette.stopTagChangeText),
                    textDirection,
                  ),
          ),
      ];
      final rects = StopTagLayouter.layout(
        anchors: [
          for (final tag in stopTags)
            geometry.toPixel(
              tag.marker.timeSeconds + tag.marker.durationSeconds,
              tag.marker.depth,
            ),
        ],
        sizes: [
          for (final (:main, :change) in labels)
            Size(
              main.width +
                  10 +
                  (change == null ? 0 : changeGap + change.width + 10),
              main.height + 6,
            ),
        ],
        bounds: plot,
      );
      void pill(Rect rect, TextPainter text, {required bool warn}) {
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = warn
                ? palette.stopTagChangeBackground
                : palette.stopTagBackground,
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = warn ? palette.stopTagChangeBorder : palette.stopTagBorder
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
        text.paint(canvas, Offset(rect.left + 5, rect.top + 3));
      }

      for (var i = 0; i < rects.length; i++) {
        final (:main, :change) = labels[i];
        final pills = stopTagPillRects(
          box: rects[i],
          mainWidth: main.width + 10,
          changeWidth: change == null ? null : change.width + 10,
          gap: changeGap,
          textDirection: textDirection,
        );
        pill(pills.main, main, warn: stopTags[i].isNew);
        if (change != null) pill(pills.change!, change, warn: true);
      }
    }
  }

  Path _polyline(List<CanvasPoint> points) {
    final path = Path()
      ..moveTo(
        geometry.xFor(points.first.timeSeconds),
        geometry.yFor(points.first.depth),
      );
    for (final point in points.skip(1)) {
      path.lineTo(geometry.xFor(point.timeSeconds), geometry.yFor(point.depth));
    }
    return path;
  }

  @override
  bool shouldRepaint(PlanChartSeriesPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.palette != palette ||
      oldDelegate.series != series ||
      oldDelegate.ghost != ghost ||
      oldDelegate.sourceDive != sourceDive ||
      oldDelegate.meanDepthLabel != meanDepthLabel ||
      !listEquals(oldDelegate.stopTags, stopTags) ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.tagStyle != tagStyle ||
      oldDelegate.textDirection != textDirection;
}

/// Splits a stop tag's laid-out [box] into its main pill and, when there is
/// a change, the change pill after it in reading order: on the right in a
/// left-to-right locale, on the left in a right-to-left one.
@visibleForTesting
({Rect main, Rect? change}) stopTagPillRects({
  required Rect box,
  required double mainWidth,
  required double? changeWidth,
  required double gap,
  required TextDirection textDirection,
}) {
  if (changeWidth == null) {
    return (
      main: Rect.fromLTWH(box.left, box.top, mainWidth, box.height),
      change: null,
    );
  }
  final rtl = textDirection == TextDirection.rtl;
  final changeLeft = rtl ? box.left : box.left + mainWidth + gap;
  final mainLeft = rtl ? box.left + changeWidth + gap : box.left;
  return (
    main: Rect.fromLTWH(mainLeft, box.top, mainWidth, box.height),
    change: Rect.fromLTWH(changeLeft, box.top, changeWidth, box.height),
  );
}
