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

/// Foreground layer: draped wireframe on the surface, then the axis lines +
/// ticks, then the hover marker, then the scrub cursor. Repaints on camera
/// changes and on the scrub/hover listenables.
class TissueChromePainter extends CustomPainter {
  final Scene3d scene;
  final TissueSurfaceGrid grid;
  final AxisFrame frame;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;
  final ValueListenable<double> scrubPosition;
  final ValueListenable<TissuePick?> hoverPick;
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
    required this.scrubPosition,
    required this.hoverPick,
    this.labels,
    this.textDirection = TextDirection.ltr,
  }) : super(repaint: Listenable.merge([scrubPosition, hoverPick]));

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
    _paintAxes(canvas, p);
    _paintLabels(canvas, p);
    _paintMarker(canvas, p);
    _paintCursor(canvas, p);
  }

  void _paintLabels(Canvas canvas, SceneProjector p) {
    final set = labels;
    if (set == null) return;
    for (final l in set.labels) {
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
    // Iso-time lines (along compartments) for a decimated set of columns.
    final step = (grid.columns / _maxWireColumns).ceil().clamp(1, grid.columns);
    for (var col = 0; col < grid.columns; col += step) {
      final path = Path();
      for (var comp = 0; comp < grid.compartments; comp++) {
        final o = _projectVertex(p, col, comp);
        comp == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintAxes(Canvas canvas, SceneProjector p) {
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
          canvas.drawLine(
            a,
            b,
            stroke(style.axisX.withValues(alpha: 0.9), 1.5),
          );
        case AxisRole.tickY:
          canvas.drawLine(
            a,
            b,
            stroke(style.axisY.withValues(alpha: 0.9), 1.5),
          );
        case AxisRole.tickZ:
          canvas.drawLine(
            a,
            b,
            stroke(style.axisZ.withValues(alpha: 0.9), 1.5),
          );
        case AxisRole.frameGrid:
          break; // drawn by TissueFramePainter
      }
    }
  }

  void _paintMarker(Canvas canvas, SceneProjector p) {
    final pick = hoverPick.value;
    if (pick == null || grid.isEmpty) return;
    if (pick.col >= grid.columns || pick.comp >= grid.compartments) return;
    final center = _projectVertex(p, pick.col, pick.comp);
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
