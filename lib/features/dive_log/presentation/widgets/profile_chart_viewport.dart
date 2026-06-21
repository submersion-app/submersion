import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of the dive profile chart's visible window, expressed
/// as normalized fractions [0,1] of the total data range. Resolution- and
/// data-independent, so the anchor math is unit-testable with plain numbers.
///
/// `offsetX`/`offsetY` are the normalized left/top edges of the visible window
/// (`offsetY == 0` is the surface). The window spans `1/zoom` of each axis, so
/// both offsets are valid in `[0, 1 - 1/zoom]`.
@immutable
class ProfileChartViewport {
  final double zoom; // >= 1.0
  final double offsetX;
  final double offsetY;

  const ProfileChartViewport({
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  static const double minZoom = 1.0;
  static const double maxZoom = 10.0;
  static const ProfileChartViewport reset = ProfileChartViewport();

  bool get isZoomed => zoom > 1.0;
  double get visibleWidth => 1.0 / zoom;
  double get visibleHeight => 1.0 / zoom;

  /// Zoom by [factor] (>1 = in, <1 = out) keeping the data point under the
  /// focal point fixed. [focalX]/[focalY] are fractions (0..1) of the visible
  /// plot area under the cursor/pinch (0 = left/top edge).
  ProfileChartViewport zoomedAt(double focalX, double focalY, double factor) {
    final newZoom = (zoom * factor).clamp(minZoom, maxZoom);
    if (newZoom == zoom) return this;
    final anchorX =
        offsetX + focalX / zoom; // data fraction under focus, before
    final anchorY = offsetY + focalY / zoom;
    return ProfileChartViewport(
      zoom: newZoom,
      offsetX: anchorX - focalX / newZoom, // keep it under focus, after
      offsetY: anchorY - focalY / newZoom,
    )._clamped();
  }

  /// Pan by a normalized delta (fractions of the total range).
  ProfileChartViewport pannedBy(double dx, double dy) => ProfileChartViewport(
    zoom: zoom,
    offsetX: offsetX + dx,
    offsetY: offsetY + dy,
  )._clamped();

  ProfileChartViewport _clamped() {
    final maxOff = 1.0 - 1.0 / zoom;
    return ProfileChartViewport(
      zoom: zoom,
      offsetX: offsetX.clamp(0.0, maxOff),
      offsetY: offsetY.clamp(0.0, maxOff),
    );
  }
}

/// Maps a gesture's [localPos] (in the full widget [box]) to a fraction
/// (0..1, clamped) of the inner plot rect, given the reserved axis gutters.
/// fl_chart reserves [left]/[right]/[top]/[bottom] for axis names + tick
/// labels (+ the gas strip), so the data window only fills the inner rect.
({double fx, double fy}) chartFocalFraction(
  Offset localPos,
  Size box, {
  required double left,
  required double right,
  required double top,
  required double bottom,
}) {
  final plotW = (box.width - left - right).clamp(1.0, double.infinity);
  final plotH = (box.height - top - bottom).clamp(1.0, double.infinity);
  return (
    fx: ((localPos.dx - left) / plotW).clamp(0.0, 1.0),
    fy: ((localPos.dy - top) / plotH).clamp(0.0, 1.0),
  );
}

/// What a drag/scale event should do on the profile chart.
enum ChartDragIntent { pan, scrub, zoomPan, none }

/// Decides the meaning of an in-progress gesture from the active pointer kind,
/// the pointer count, and whether a double-tap-hold is active. Keying off the
/// pointer kind (not the platform) is what lets one-finger touch keep scrubbing
/// while a mouse drag pans.
ChartDragIntent chartDragIntent({
  required PointerDeviceKind kind,
  required int pointerCount,
  required bool doubleTapHold,
}) {
  if (pointerCount >= 2) return ChartDragIntent.zoomPan;
  if (doubleTapHold) return ChartDragIntent.pan;
  return kind == PointerDeviceKind.touch
      ? ChartDragIntent.scrub
      : ChartDragIntent.pan;
}
