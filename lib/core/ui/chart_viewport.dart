import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Immutable description of a chart's visible window, expressed
/// as normalized fractions [0,1] of the total data range. Resolution- and
/// data-independent, so the anchor math is unit-testable with plain numbers.
///
/// `offsetX`/`offsetY` are the normalized left/top edges of the visible window
/// (`offsetY == 0` is the surface). The window spans `1/zoom` of each axis, so
/// both offsets are valid in `[0, 1 - 1/zoom]`.
@immutable
class ChartViewport {
  final double zoom; // >= 1.0
  final double offsetX;
  final double offsetY;

  /// The deepest zoom this viewport allows. Defaults to [maxZoom]; a date
  /// chart over a long logbook raises it so a few weeks can fill the plot.
  final double zoomLimit;

  const ChartViewport({
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    this.zoomLimit = maxZoom,
  });

  /// A viewport showing [start]..[end] of the x range (fractions, 0..1).
  ///
  /// A window narrower than [zoomLimit] allows is widened about its centre,
  /// then shifted back inside 0..1, so a window ending at 1 still ends at 1.
  factory ChartViewport.forWindow(
    double start,
    double end, {
    double zoomLimit = maxZoom,
  }) {
    final width = (end - start).clamp(1.0 / zoomLimit, 1.0);
    final centre = (start + end) / 2;
    return ChartViewport(
      zoom: 1.0 / width,
      offsetX: centre - width / 2,
      zoomLimit: zoomLimit,
    )._clamped();
  }

  static const double minZoom = 1.0;
  static const double maxZoom = 10.0;
  static const ChartViewport reset = ChartViewport();

  bool get isZoomed => zoom > 1.0;
  double get visibleWidth => 1.0 / zoom;
  double get visibleHeight => 1.0 / zoom;

  /// Left edge of the visible x window, as a fraction of the full range.
  double get windowStart => offsetX;

  /// Right edge of the visible x window, as a fraction of the full range.
  double get windowEnd => offsetX + visibleWidth;

  /// This viewport under a different [limit], zoomed out to it if needed.
  ChartViewport withZoomLimit(double limit) => ChartViewport(
    zoom: zoom.clamp(minZoom, limit),
    offsetX: offsetX,
    offsetY: offsetY,
    zoomLimit: limit,
  )._clamped();

  /// Zoom by [factor] (>1 = in, <1 = out) keeping the data point under the
  /// focal point fixed. [focalX]/[focalY] are fractions (0..1) of the visible
  /// plot area under the cursor/pinch (0 = left/top edge).
  ChartViewport zoomedAt(double focalX, double focalY, double factor) {
    final newZoom = (zoom * factor).clamp(minZoom, zoomLimit);
    if (newZoom == zoom) return this;
    final anchorX =
        offsetX + focalX / zoom; // data fraction under focus, before
    final anchorY = offsetY + focalY / zoom;
    return ChartViewport(
      zoom: newZoom,
      offsetX: anchorX - focalX / newZoom, // keep it under focus, after
      offsetY: anchorY - focalY / newZoom,
      zoomLimit: zoomLimit,
    )._clamped();
  }

  /// Pan by a normalized delta (fractions of the total range).
  ChartViewport pannedBy(double dx, double dy) => ChartViewport(
    zoom: zoom,
    offsetX: offsetX + dx,
    offsetY: offsetY + dy,
    zoomLimit: zoomLimit,
  )._clamped();

  ChartViewport _clamped() {
    final maxOff = 1.0 - 1.0 / zoom;
    return ChartViewport(
      zoom: zoom,
      offsetX: offsetX.clamp(0.0, maxOff),
      offsetY: offsetY.clamp(0.0, maxOff),
      zoomLimit: zoomLimit,
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

/// What a drag/scale event should do on an interactive chart.
enum ChartDragIntent { pan, scrub, zoomPan, none }

/// Decides the meaning of an in-progress gesture from the active pointer kind,
/// the pointer count, and whether the viewport is zoomed in. Keying off the
/// pointer kind (not the platform) is what lets one-finger touch keep scrubbing
/// while a mouse drag pans. A zoomed viewport flips one-finger touch from
/// scrub to pan ("drag to pan", matching the on-screen zoom hint); scrubbing
/// while zoomed remains available via tap and long-press drag.
ChartDragIntent chartDragIntent({
  required PointerDeviceKind kind,
  required int pointerCount,
  required bool isZoomed,
}) {
  if (pointerCount >= 2) return ChartDragIntent.zoomPan;
  if (kind != PointerDeviceKind.touch) return ChartDragIntent.pan;
  return isZoomed ? ChartDragIntent.pan : ChartDragIntent.scrub;
}
