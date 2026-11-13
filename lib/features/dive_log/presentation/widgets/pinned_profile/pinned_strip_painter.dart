import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_depth_at.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ceilingFillAlpha;
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';

export 'pinned_strip_layers.dart' show kPinnedStripPointBudget;

/// Breathing room above and below the strip's curve.
const double _curvePad = 4;

/// Height of the pinned strip's curve area: the whole strip (issue #4509).
/// The strip aims its line at this from the start, whatever height its box
/// has while it condenses, so the line never grows back out toward a tall
/// box.
const double _curveAreaHeight = kPinnedStripHeight;

/// Stroke width of the strip's NDL line.
const double _ndlLineWidth = 1.5;

/// Radius of the max-depth dot.
const double _maxDepthDotRadius = 3.5;

/// Font size of the max-depth label.
const double _maxDepthLabelSize = 10;

/// What the strip draws of a profile: its points cut down to
/// [kPinnedStripPointBudget], keeping the depth envelope and the deepest
/// point, and the depth its axis runs to.
@immutable
class PinnedStripCurve {
  const PinnedStripCurve({
    required this.points,
    required this.maxDepthMeters,
    this.deepest,
  });

  final List<DiveProfilePoint> points;
  final double maxDepthMeters;

  /// The deepest sample, where the max-depth marker goes; null when the
  /// profile never leaves the surface.
  final DiveProfilePoint? deepest;
}

final Expando<PinnedStripCurve> _curves = Expando('pinnedStripCurve');

/// The [PinnedStripCurve] of [profile], worked out once per profile list
/// rather than on every paint: the strip repaints on every scroll frame
/// while it shows.
PinnedStripCurve pinnedStripCurve(List<DiveProfilePoint> profile) =>
    _curves[profile] ??= _curveOf(profile);

PinnedStripCurve _curveOf(List<DiveProfilePoint> profile) {
  var maxDepth = 0.0;
  DiveProfilePoint? deepest;
  for (final p in profile) {
    if (p.depth > maxDepth) {
      maxDepth = p.depth;
      deepest = p;
    }
  }
  final kept = decimateSeriesIndices([
    for (final p in profile) p.depth,
  ], targetPoints: kPinnedStripPointBudget);
  return PinnedStripCurve(
    points: kept.length == profile.length
        ? profile
        : [for (final i in kept) profile[i]],
    maxDepthMeters: maxDepth,
    deepest: deepest,
  );
}

/// Paints the pinned strip's depth curve (issue #4423), with its NDL line,
/// deco bands and max-depth marker (issue #4509).
///
/// The curve goes through a [PlotMapping] that moves, as [morph] runs from 0
/// to 1, from [from] (where the full chart draws its depth line, in this
/// painter's coordinates) to the strip's own curve area. At 0 the line lies
/// exactly on the chart's, so the condense never shows two depth lines; every
/// point then travels continuously into the strip. The layers the strip adds
/// fade in with [morph], so the hand-over never doubles the chart's own deco
/// bands at full strength.
class PinnedStripPainter extends CustomPainter {
  const PinnedStripPainter({
    required this.profile,
    required this.selectedSeconds,
    required this.curveColor,
    required this.fillColors,
    required this.markerColor,
    this.from,
    this.morph = 1,
    this.ndlCurve,
    this.ceilingCurve,
    this.decoStopCurve,
    this.maxDepthLabel,
    this.maxDepthLabelColor = ProfileMetricColors.maxDepth,
    this.surfaceColor = const Color(0x00000000),
    this.ndlColor = ProfileMetricColors.ndl,
    this.ceilingColor = ProfileMetricColors.ceiling,
    this.maxDepthColor = ProfileMetricColors.maxDepth,
  });

  final List<DiveProfilePoint> profile;
  final int? selectedSeconds;
  final Color curveColor;

  /// Top and bottom of the shading under the line, as the full chart's depth
  /// gradient.
  final List<Color> fillColors;
  final Color markerColor;
  final PlotMapping? from;
  final double morph;

  /// NDL in seconds, index-aligned with [profile]; zero or less in deco.
  final List<int>? ndlCurve;

  /// Ceiling depth in metres, index-aligned with [profile]; zero with no
  /// obligation.
  final List<double>? ceilingCurve;

  /// Deco stop depth in metres, index-aligned with [profile]; zero with no
  /// obligation.
  final List<double>? decoStopCurve;

  /// The max depth, formatted in the diver's units, beside the max-depth dot.
  final String? maxDepthLabel;
  final Color maxDepthLabelColor;

  /// The strip's background, which rings the max-depth dot.
  final Color surfaceColor;

  /// The colours of the NDL line, the ceiling and the max-depth dot: the
  /// diver's chart colours, as the full chart draws them.
  final Color ndlColor;
  final Color ceilingColor;
  final Color maxDepthColor;

  /// The strip's own mapping: the whole dive across the pinned strip's curve
  /// area, surface to deepest point down.
  PlotMapping _own(Size size) {
    final maxDepth = pinnedStripCurve(profile).maxDepthMeters;
    return PlotMapping(
      rect: Rect.fromLTWH(
        0,
        _curvePad,
        size.width,
        _curveAreaHeight - 2 * _curvePad,
      ),
      minSeconds: profile.isEmpty ? 0 : profile.first.timestamp.toDouble(),
      maxSeconds: profile.isEmpty ? 1 : profile.last.timestamp.toDouble(),
      minDepthMeters: 0,
      maxDepthMeters: maxDepth <= 0 ? 1 : maxDepth,
    );
  }

  /// The mapping the curve is drawn through at this [morph].
  PlotMapping mappingFor(Size size) {
    final own = _own(size);
    final start = from;
    return start == null ? own : PlotMapping.lerp(start, own, morph);
  }

  /// Where the curve is clipped while it morphs: from the chart's plot (the
  /// chart clips its line there, so a zoomed-in chart hides the rest of the
  /// dive) to the strip's whole curve area. Null without a chart plot.
  Rect? clipFor(Size size) {
    final start = from;
    if (start == null) return null;
    final curveArea = Rect.fromLTWH(0, 0, size.width, _curveAreaHeight);
    return Rect.lerp(start.rect, curveArea, morph);
  }

  /// The shaded area, as the full chart draws it: between the depth line and
  /// the bottom of the plot (the water below the diver), clear above.
  Path? fillPathFor(Size size) =>
      profile.length < 2 ? null : _fillPath(mappingFor(size));

  /// Where the NDL line passes the sample at [index] reading [ndlSeconds]:
  /// on [ProfileMetricBands.ndl]'s scale, the hour at the top of the plot
  /// and zero at its bottom, longer readings held at the top.
  @visibleForTesting
  Offset ndlPointFor(Size size, int index, double ndlSeconds) =>
      _ndlPoint(mappingFor(size), index, ndlSeconds);

  Offset _ndlPoint(PlotMapping m, int index, double ndlSeconds) {
    final share = (ndlSeconds / ProfileMetricBands.ndl.fixedMax).clamp(
      0.0,
      1.0,
    );
    return Offset(
      m.project(profile[index].timestamp, 0).dx,
      m.rect.bottom - share * m.rect.height,
    );
  }

  Path _fillPath(PlotMapping m) {
    final points = pinnedStripCurve(profile).points;
    final bottomY = m.rect.bottom;
    final first = m.project(points.first.timestamp, points.first.depth);
    final path = Path()..moveTo(first.dx, bottomY);
    for (final p in points) {
      final o = m.project(p.timestamp, p.depth);
      path.lineTo(o.dx, o.dy);
    }
    final last = m.project(points.last.timestamp, points.last.depth);
    return path
      ..lineTo(last.dx, bottomY)
      ..close();
  }

  /// [runs] as drawn: only the points whose index is in [profile], so a
  /// curve that does not match the profile draws no further than it.
  Iterable<List<StripSeriesPoint>> _inProfile(
    List<List<StripSeriesPoint>> runs,
  ) sync* {
    for (final run in runs) {
      final kept = [
        for (final p in run)
          if (p.index < profile.length) p,
      ];
      if (kept.isNotEmpty) yield kept;
    }
  }

  /// A band from the surface down to each run of [curve], and its edge.
  void _paintBand(
    Canvas canvas,
    PlotMapping m,
    List<double> curve, {
    required bool stepped,
    required Color color,
    required double fillAlpha,
    required double opacity,
  }) {
    final runs = _inProfile(pinnedDepthRuns(curve, stepped: stepped)).toList();
    if (runs.isEmpty) return;
    final fill = Path();
    final edge = Path();
    for (final run in runs) {
      final points = [
        for (final p in run) m.project(profile[p.index].timestamp, p.value),
      ];
      final surface = m.project(profile[run.first.index].timestamp, 0).dy;
      fill.moveTo(points.first.dx, surface);
      edge.moveTo(points.first.dx, points.first.dy);
      for (final o in points) {
        fill.lineTo(o.dx, o.dy);
        edge.lineTo(o.dx, o.dy);
      }
      fill
        ..lineTo(points.last.dx, surface)
        ..close();
    }
    canvas
      ..drawPath(
        fill,
        Paint()..color = color.withValues(alpha: fillAlpha * opacity),
      )
      ..drawPath(
        edge,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = kProfileDepthLineWidth,
      );
  }

  /// Draws the NDL line and returns its points, which the max-depth label
  /// keeps clear of.
  List<Offset> _paintNdl(
    Canvas canvas,
    PlotMapping m,
    List<int> curve,
    double opacity,
  ) {
    final all = <Offset>[];
    final line = Path();
    for (final run in _inProfile(pinnedNdlRuns(curve))) {
      for (var i = 0; i < run.length; i++) {
        final o = _ndlPoint(m, run[i].index, run[i].value);
        i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
        all.add(o);
      }
    }
    if (all.isEmpty) return all;
    canvas.drawPath(
      line,
      Paint()
        ..color = ndlColor.withValues(alpha: ndlColor.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ndlLineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    return all;
  }

  void _paintMaxDepth(
    Canvas canvas,
    Size size,
    PlotMapping m,
    List<Offset> avoid,
    double opacity,
  ) {
    final deepest = pinnedStripCurve(profile).deepest;
    if (deepest == null) return;
    final dot = m.project(deepest.timestamp, deepest.depth);
    canvas
      ..drawCircle(
        dot,
        _maxDepthDotRadius,
        Paint()
          ..color = maxDepthColor.withValues(alpha: maxDepthColor.a * opacity),
      )
      ..drawCircle(
        dot,
        _maxDepthDotRadius,
        Paint()
          ..color = surfaceColor.withValues(alpha: surfaceColor.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final text = maxDepthLabel;
    if (text == null || text.isEmpty) return;
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _maxDepthLabelSize,
          fontWeight: FontWeight.w600,
          color: maxDepthLabelColor.withValues(
            alpha: maxDepthLabelColor.a * opacity,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    label.paint(
      canvas,
      maxDepthLabelOffset(
        dot: dot,
        label: label.size,
        area: Size(size.width, math.min(size.height, _curveAreaHeight)),
        avoid: avoid,
      ),
    );
    label.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;
    final m = mappingFor(size);
    final clip = clipFor(size);
    if (clip != null) canvas.clipRect(clip);
    final layers = morph.clamp(0.0, 1.0);
    // The bounded set of points, as the full chart draws; the cursor below
    // still reads its depth from the whole profile.
    final points = pinnedStripCurve(profile).points;
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final o = m.project(points[i].timestamp, points[i].depth);
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      _fillPath(m),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fillColors,
        ).createShader(m.rect),
    );
    final stops = decoStopCurve;
    final ceiling = ceilingCurve;
    if (layers > 0 && stops != null) {
      _paintBand(
        canvas,
        m,
        stops,
        stepped: true,
        color: decoStopBandColor,
        fillAlpha: decoStopFillAlpha,
        opacity: layers,
      );
    }
    if (layers > 0 && ceiling != null) {
      _paintBand(
        canvas,
        m,
        ceiling,
        stepped: false,
        color: ceilingColor,
        fillAlpha: ceilingFillAlpha,
        opacity: layers,
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = kProfileDepthLineWidth,
    );
    final ndl = ndlCurve;
    final ndlPoints = layers > 0 && ndl != null
        ? _paintNdl(canvas, m, ndl, layers)
        : const <Offset>[];
    if (layers > 0) _paintMaxDepth(canvas, size, m, ndlPoints, layers);

    final selected = selectedSeconds;
    if (selected == null) return;
    final depth = profileDepthAt(profile, selected);
    final top = m.project(selected, m.minDepthMeters);
    final bottom = m.project(selected, m.maxDepthMeters);
    canvas.drawLine(
      Offset(top.dx, math.max(0, top.dy)),
      Offset(bottom.dx, math.min(size.height, bottom.dy)),
      Paint()
        ..color = markerColor
        ..strokeWidth = 1.5,
    );
    if (depth != null) {
      canvas.drawCircle(
        m.project(selected, depth),
        4,
        Paint()..color = markerColor,
      );
    }
  }

  @override
  bool shouldRepaint(PinnedStripPainter old) =>
      old.profile != profile ||
      old.selectedSeconds != selectedSeconds ||
      old.curveColor != curveColor ||
      !listEquals(old.fillColors, fillColors) ||
      old.markerColor != markerColor ||
      old.morph != morph ||
      old.from != from ||
      old.ndlCurve != ndlCurve ||
      old.ceilingCurve != ceilingCurve ||
      old.decoStopCurve != decoStopCurve ||
      old.maxDepthLabel != maxDepthLabel ||
      old.maxDepthLabelColor != maxDepthLabelColor ||
      old.surfaceColor != surfaceColor ||
      old.ndlColor != ndlColor ||
      old.ceilingColor != ceilingColor ||
      old.maxDepthColor != maxDepthColor;
}
