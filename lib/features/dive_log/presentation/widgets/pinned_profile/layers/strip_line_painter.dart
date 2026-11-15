import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_painter_base.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

/// How faint a ghost depth line is at full strength.
const double kStripGhostAlpha = 0.45;

/// Stroke width of a card's line layer on the strip.
const double _lineWidth = 1.5;

/// The dash an estimated tank pressure is drawn with: on, off.
const List<double> _estimateDash = [4, 3];

/// Draws the pinned strip's line layers over its depth line (issue #4562):
/// ghosted depth lines (a plan, other computers) on the depth scale, then
/// each card's lines on scales of their own, bottom to top of the curve
/// area.
class StripLinePainter extends StripLayerPainter {
  const StripLinePainter({required super.strip, required super.layers});

  @override
  bool get hasAnything =>
      layers.data.lines.any((l) => layers.strengthOf(l.layer) > 0) ||
      layers.data.ghosts.any((g) => layers.strengthOf(g.layer) > 0);

  /// Where [line] passes [point], drawn on a strip of [size].
  @visibleForTesting
  Offset linePointFor(Size size, StripLine line, StripPoint point) =>
      _linePoint(strip.mappingFor(size), line, point);

  /// Where a ghost passes [point] (a depth), drawn on a strip of [size].
  @visibleForTesting
  Offset ghostPointFor(Size size, StripPoint point) =>
      strip.mappingFor(size).project(point.seconds, point.value);

  Offset _linePoint(PlotMapping m, StripLine line, StripPoint point) {
    final span = line.max - line.min;
    final share = span <= 0
        ? 0.5
        : ((point.value - line.min) / span).clamp(0.0, 1.0);
    return Offset(
      m.project(point.seconds, 0).dx,
      m.rect.bottom - share * m.rect.height,
    );
  }

  @override
  void paintLayers(Canvas canvas, Rect area, PlotMapping m) {
    for (final ghost in layers.data.ghosts) {
      final strength = layers.strengthOf(ghost.layer);
      if (strength <= 0 || ghost.points.length < 2) continue;
      canvas.drawPath(
        Path()..addPolygon([
          for (final p in ghost.points) m.project(p.seconds, p.value),
        ], false),
        Paint()
          ..color = StripLayerPainter.faded(
            ghost.color.withValues(alpha: ghost.color.a * kStripGhostAlpha),
            strength,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    for (final line in layers.data.lines) {
      final strength = layers.strengthOf(line.layer);
      if (strength <= 0) continue;
      final path = Path();
      for (final run in line.runs) {
        if (run.isEmpty) continue;
        path.addPolygon([for (final p in run) _linePoint(m, line, p)], false);
      }
      canvas.drawPath(
        line.estimated ? _dashedFor(line, m, path) : path,
        Paint()
          ..color = StripLayerPainter.faded(line.color, strength)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _lineWidth
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// [line]'s dashes through [m], cut from [path] once per mapping: the
  /// painter repaints every frame of a fade, and only the alpha changes.
  static Path _dashedFor(StripLine line, PlotMapping m, Path path) {
    final kept = _dashes[line];
    if (kept != null && kept.mapping == m) return kept.path;
    final dashed = _dashed(path);
    _dashes[line] = (mapping: m, path: dashed);
    return dashed;
  }

  static final Expando<({PlotMapping mapping, Path path})> _dashes = Expando(
    'stripDashes',
  );

  /// [path] cut into dashes.
  static Path _dashed(Path path) {
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      var i = 0;
      while (at < metric.length) {
        final length = _estimateDash[i % _estimateDash.length];
        if (i.isEven) {
          dashed.addPath(metric.extractPath(at, at + length), Offset.zero);
        }
        at += length;
        i++;
      }
    }
    return dashed;
  }
}
