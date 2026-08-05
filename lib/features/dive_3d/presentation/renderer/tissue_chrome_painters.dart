import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scrub_cursor.dart';

/// Theme-resolved colors for the tissue chrome (built by the viewport, which
/// owns the BuildContext; painters never read Theme directly).
class TissueChromeStyle extends Equatable {
  final Color axisX,
      axisY,
      axisZ,
      grid,
      wireframe,
      marker,
      markerOutline,
      label;
  const TissueChromeStyle({
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.grid,
    required this.wireframe,
    required this.marker,
    required this.markerOutline,
    required this.label,
  });

  @override
  List<Object?> get props => [
    axisX,
    axisY,
    axisZ,
    grid,
    wireframe,
    marker,
    markerOutline,
    label,
  ];
}

/// Background layer: the floor + back-wall reference grid, drawn BEHIND the
/// surface so the opaque mesh occludes it via paint order.
class TissueFramePainter extends CustomPainter {
  final SceneBounds bounds;
  final AxisFrame frame;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;

  TissueFramePainter({
    required this.bounds,
    required this.frame,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projector = SceneProjector(
      size: size,
      bounds: bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    final paint = Paint()
      ..color = style.grid
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    for (final s in frame.segments) {
      if (s.role != AxisRole.frameGrid) continue;
      canvas.drawLine(
        projector.project(s.x1, s.y1, s.z1),
        projector.project(s.x2, s.y2, s.z2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TissueFramePainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.frame, frame) ||
      !identical(old.bounds, bounds) ||
      old.style != style;
}

/// Draws [frame]'s axis lines and tick marks in the axis colors. Grid
/// segments are skipped — they belong to the background frame painter.
/// Shared by the tissue chrome and the seascape's [AxisChromePainter].
void paintAxisSegments(
  Canvas canvas,
  SceneProjector p,
  AxisFrame frame,
  TissueChromeStyle style,
) {
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke;
  for (final s in frame.segments) {
    final a = p.project(s.x1, s.y1, s.z1);
    final b = p.project(s.x2, s.y2, s.z2);
    switch (s.role) {
      case AxisRole.axisX:
        canvas.drawLine(a, b, stroke(style.axisX, 2));
      case AxisRole.axisY:
        canvas.drawLine(a, b, stroke(style.axisY, 2));
      case AxisRole.axisZ:
        canvas.drawLine(a, b, stroke(style.axisZ, 2));
      case AxisRole.tickX:
        canvas.drawLine(a, b, stroke(style.axisX.withValues(alpha: 0.9), 1.5));
      case AxisRole.tickY:
        canvas.drawLine(a, b, stroke(style.axisY.withValues(alpha: 0.9), 1.5));
      case AxisRole.tickZ:
        canvas.drawLine(a, b, stroke(style.axisZ.withValues(alpha: 0.9), 1.5));
      case AxisRole.frameGrid:
        break; // background layer's concern
    }
  }
}

/// Draws world-anchored axis titles and tick values so labels track the
/// rotating camera. Shared by the tissue chrome and [AxisChromePainter].
void paintAxisLabels(
  Canvas canvas,
  SceneProjector p,
  AxisLabelSet? labels,
  TissueChromeStyle style,
  TextDirection textDirection,
) {
  if (labels == null) return;
  for (final l in labels.labels) {
    final at = p.project(l.x, l.y, l.z);
    final isTitle = l.kind == AxisLabelKind.title;
    final tp = TextPainter(
      text: TextSpan(
        text: l.text,
        style: TextStyle(
          color: style.label,
          fontSize: isTitle ? 11 : 9.5,
          fontWeight: isTitle ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    // Titles sit above-right of the axis end; tick values below-left of the
    // tick, so neither overlaps the axis line.
    final offset = isTitle
        ? Offset(4, -tp.height - 2)
        : Offset(-tp.width - 4, -tp.height / 2);
    tp.paint(canvas, at + offset);
  }
}

/// Screen angle (radians, canvas convention: y grows downward) of the
/// scene's +Z axis — geographic NORTH in the seascape's east-north-up
/// frame — under the projector's current camera. Position-independent
/// under the orthographic projection, so any base point works. Returns
/// null when the view runs straight along north and the projected
/// direction collapses (the compass should hide, not point a lie).
double? compassNeedleAngle(SceneProjector p) {
  final delta = p.project(0, 0, 1) - p.project(0, 0, 0);
  if (delta.distance < 1e-3) return null;
  return math.atan2(delta.dy, delta.dx);
}

/// Foreground axis + label chrome with no tissue surface — the seascape
/// views' measurement frame, plus (when hover inputs are provided) the
/// hover marker ring on the picked terrain vertex. The scrub cursor stays
/// on the scene's own foreground painter, unaffected. The seascape frame
/// is small (~10 segments, ~15 labels), so folding the ring's per-hover
/// repaint into this layer costs little.
class AxisChromePainter extends CustomPainter {
  final SceneBounds bounds;
  final AxisFrame frame;
  final AxisLabelSet? labels;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;
  final TextDirection textDirection;
  final TissueSurfaceGrid? surfaceGrid;
  final ValueListenable<TissuePick?>? hoverPick;

  AxisChromePainter({
    required this.bounds,
    required this.frame,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    this.labels,
    this.textDirection = TextDirection.ltr,
    this.surfaceGrid,
    this.hoverPick,
  }) : super(repaint: hoverPick);

  static const double _compassRadius = 18;
  static const Offset _compassInset = Offset(36, 36);

  @override
  void paint(Canvas canvas, Size size) {
    final p = SceneProjector(
      size: size,
      bounds: bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    paintAxisSegments(canvas, p, frame, style);
    paintAxisLabels(canvas, p, labels, style, textDirection);
    _paintCompass(canvas, size, p);
    _paintHoverRing(canvas, p);
  }

  /// A small rose in the bottom-left corner whose needle points along the
  /// screen-projected direction of scene-north — so it tracks yaw and
  /// pitch honestly. Hidden when the projection degenerates (viewing
  /// straight along north).
  void _paintCompass(Canvas canvas, Size size, SceneProjector p) {
    final angle = compassNeedleAngle(p);
    if (angle == null) return;
    final center = Offset(_compassInset.dx, size.height - _compassInset.dy);
    canvas.drawCircle(
      center,
      _compassRadius,
      Paint()
        ..color = style.label.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final needle = Offset(math.cos(angle), math.sin(angle));
    final tip = center + needle * (_compassRadius - 4);
    // South tail, fainter, so the rose reads as a needle not a spoke.
    canvas.drawLine(
      center,
      center - needle * (_compassRadius - 8),
      Paint()
        ..color = style.label.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = style.label
        ..strokeWidth = 2,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: style.label,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    // The label rides just beyond the tip, kept clear of the needle.
    final labelCenter = center + needle * (_compassRadius + 7);
    tp.paint(canvas, labelCenter - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintHoverRing(Canvas canvas, SceneProjector p) {
    final grid = surfaceGrid;
    final pick = hoverPick?.value;
    if (grid == null || grid.isEmpty || pick == null) return;
    if (pick.col >= grid.columns || pick.comp >= grid.compartments) return;
    final (x, y, z) = grid.positionAt(pick.col, pick.comp);
    final center = p.project(x, y, z);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.markerOutline.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.marker.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant AxisChromePainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.frame, frame) ||
      !identical(old.labels, labels) ||
      !identical(old.bounds, bounds) ||
      !identical(old.surfaceGrid, surfaceGrid) ||
      old.style != style ||
      old.textDirection != textDirection;
}

/// Static chrome layer: the draped wireframe on the surface, then the axis
/// lines + ticks + labels. Deliberately has NO scrub/hover listenable, so it
/// repaints only when the camera, grid, frame, labels, or style change -- it
/// stays put during playback and hover. The moving parts (hover marker + scrub
/// cursor) live in the lightweight [TissueOverlayPainter] on top, so a scrub
/// tick no longer re-lays-out every axis label or redraws the whole wireframe.
class TissueChromePainter extends CustomPainter {
  final Scene3d scene;
  final TissueSurfaceGrid grid;
  final AxisFrame frame;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;
  final AxisLabelSet? labels;
  final TextDirection textDirection;

  /// ~12 iso-time lines is enough to read structure without clutter.
  static const int _maxWireColumns = 12;

  TissueChromePainter({
    required this.scene,
    required this.grid,
    required this.frame,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    this.labels,
    this.textDirection = TextDirection.ltr,
  });

  SceneProjector _projector(Size size) => SceneProjector(
    size: size,
    bounds: scene.bounds,
    yawDegrees: yawDegrees,
    pitchDegrees: pitchDegrees,
    zoom: zoom,
  );

  Offset _projectVertex(SceneProjector p, int col, int comp) {
    final (x, y, z) = grid.positionAt(col, comp);
    return p.project(x, y, z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = _projector(size);
    if (!grid.isEmpty) _paintWireframe(canvas, p);
    paintAxisSegments(canvas, p, frame, style);
    paintAxisLabels(canvas, p, labels, style, textDirection);
  }

  void _paintWireframe(Canvas canvas, SceneProjector p) {
    final paint = Paint()
      ..color = style.wireframe
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    // Iso-compartment lines (along time) for every compartment row.
    for (var comp = 0; comp < grid.compartments; comp++) {
      final path = Path();
      for (var col = 0; col < grid.columns; col++) {
        final o = _projectVertex(p, col, comp);
        col == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
    // Iso-time lines (along compartments) for a decimated set of columns. step
    // is int-valued (int.clamp(int, int) -> int); the annotation is explicit so
    // a future change that widens it to num fails at compile time, not in `+=`.
    final int step = (grid.columns / _maxWireColumns).ceil().clamp(
      1,
      grid.columns,
    );
    for (var col = 0; col < grid.columns; col += step) {
      final path = Path();
      for (var comp = 0; comp < grid.compartments; comp++) {
        final o = _projectVertex(p, col, comp);
        comp == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TissueChromePainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.scene, scene) ||
      !identical(old.grid, grid) ||
      !identical(old.frame, frame) ||
      !identical(old.labels, labels) ||
      old.style != style ||
      old.textDirection != textDirection;
}

/// Dynamic overlay layer: the hover marker and the scrub cursor -- the only
/// pieces that move on hover/playback. Repaints on [scrubPosition]/[hoverPick]
/// (via the merged listenable), and [shouldRepaint] additionally catches
/// camera/scene/grid/style changes so a widget rebuild re-projects them for the
/// new camera. Split out of [TissueChromePainter] so these frequent repaints no
/// longer drag the wireframe/axes/labels along.
class TissueOverlayPainter extends CustomPainter {
  final Scene3d scene;
  final TissueSurfaceGrid grid;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;
  final ValueListenable<double> scrubPosition;
  final ValueListenable<TissuePick?> hoverPick;

  TissueOverlayPainter({
    required this.scene,
    required this.grid,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    required this.scrubPosition,
    required this.hoverPick,
  }) : super(repaint: Listenable.merge([scrubPosition, hoverPick]));

  SceneProjector _projector(Size size) => SceneProjector(
    size: size,
    bounds: scene.bounds,
    yawDegrees: yawDegrees,
    pitchDegrees: pitchDegrees,
    zoom: zoom,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final p = _projector(size);
    _paintMarker(canvas, p);
    _paintCursor(canvas, p);
  }

  void _paintMarker(Canvas canvas, SceneProjector p) {
    final pick = hoverPick.value;
    if (pick == null || grid.isEmpty) return;
    if (pick.col >= grid.columns || pick.comp >= grid.compartments) return;
    final (x, y, z) = grid.positionAt(pick.col, pick.comp);
    final center = p.project(x, y, z);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.markerOutline.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.marker.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintCursor(Canvas canvas, SceneProjector p) {
    final path = scene.scrubPath;
    if (path == null) return;
    final pt = path.sceneAt(scrubPosition.value);
    if (pt == null) return;
    paintScrubCursor(canvas, p.project(pt.x, pt.y, pt.z));
  }

  @override
  bool shouldRepaint(covariant TissueOverlayPainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.scene, scene) ||
      !identical(old.grid, grid) ||
      old.style != style;
}
