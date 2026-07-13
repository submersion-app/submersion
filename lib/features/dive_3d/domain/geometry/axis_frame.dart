import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// The role of a line segment so the renderer can color axes, ticks, and the
/// reference grid distinctly. Ticks are tagged by axis so each can be drawn in
/// its axis's color.
enum AxisRole { axisX, axisY, axisZ, tickX, tickY, tickZ, frameGrid }

/// A line segment in world (scene) coordinates.
class AxisSegment {
  final AxisRole role;
  final double x1, y1, z1, x2, y2, z2;
  const AxisSegment(
    this.role,
    this.x1,
    this.y1,
    this.z1,
    this.x2,
    this.y2,
    this.z2,
  );
}

/// Axis lines (X = time, Y = saturation %, Z = compartment), tick marks, and a
/// floor + back-wall reference grid for a tissue [SceneBounds]. Pure geometry;
/// no Canvas dependency and no text -- the axis titles and tick values are a
/// separate concern (see `buildTissueAxisLabels`), rendered by the painter.
class AxisFrame {
  final List<AxisSegment> segments;
  const AxisFrame(this.segments);

  /// [referenceY] is the scene-Y of 100% (the M-value plane height), so the Y
  /// ticks land at 0 / 50 / 100%. [timeDivs] divisions along X (and the floor
  /// and back wall), [zDivs] divisions along Z for the floor/wall grid.
  factory AxisFrame.build(
    SceneBounds bounds, {
    double referenceY = 3.0,
    int compartments = 16,
    int timeDivs = 4,
    int zDivs = 4,
  }) {
    // Both are used as divisors (i / timeDivs, i / zDivs); 0 would yield
    // NaN/Infinity coordinates. Callers wanting no grid should skip the frame,
    // not pass 0.
    assert(timeDivs > 0, 'timeDivs must be > 0 (used as a divisor)');
    assert(zDivs > 0, 'zDivs must be > 0 (used as a divisor)');
    final segments = <AxisSegment>[];
    const x0 = 0.0;
    const x1 = SceneBounds.xSpan;
    final y0 = bounds.sceneMinY;
    final y1 = bounds.sceneMaxY;
    final z0 = bounds.sceneMinZ;
    final z1 = bounds.sceneMaxZ;
    const tick = SceneBounds.xSpan * 0.02; // short mark length in world units
    final yTicks = [y0, y0 + (referenceY - y0) * 0.5, referenceY];

    // --- Axes, from the origin corner (x0, y0, z0). ---
    segments.add(AxisSegment(AxisRole.axisX, x0, y0, z0, x1, y0, z0));
    segments.add(AxisSegment(AxisRole.axisY, x0, y0, z0, x0, y1, z0));
    segments.add(AxisSegment(AxisRole.axisZ, x0, y0, z0, x0, y0, z1));

    // --- X ticks (into +z on the floor). ---
    for (var i = 1; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.tickX, x, y0, z0, x, y0, z0 + tick));
    }

    // --- Y ticks at 0 / 50 / 100% (into +x on the back wall). ---
    for (final y in yTicks) {
      segments.add(AxisSegment(AxisRole.tickY, x0, y, z0, x0 + tick, y, z0));
    }

    // --- Z ticks per compartment (into +x on the floor). ---
    for (var c = 0; c < compartments; c++) {
      final t = compartments <= 1 ? 0.0 : c / (compartments - 1);
      final z = z0 + (z1 - z0) * t;
      segments.add(AxisSegment(AxisRole.tickZ, x0, y0, z, x0 + tick, y0, z));
    }

    // --- Floor grid (y = y0): lines along X at each z-div, along Z at each x-div. ---
    for (var i = 0; i <= zDivs; i++) {
      final z = z0 + (z1 - z0) * i / zDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y0, z, x1, y0, z));
    }
    for (var i = 0; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x, y0, z0, x, y0, z1));
    }

    // --- Back wall (z = z1): verticals at each x-div, horizontals at each y-tick. ---
    for (var i = 0; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x, y0, z1, x, y1, z1));
    }
    for (final y in yTicks) {
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y, z1, x1, y, z1));
    }

    // --- Left wall (x = x0): verticals at each z-div, horizontals at each y-tick. ---
    for (var i = 0; i <= zDivs; i++) {
      final z = z0 + (z1 - z0) * i / zDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y0, z, x0, y1, z));
    }
    for (final y in yTicks) {
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y, z0, x0, y, z1));
    }

    return AxisFrame(segments);
  }
}
