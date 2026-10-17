// Pure helpers for trackpad two-finger-scroll zooming, shared by the maps and
// the dive profile chart so sign and sensitivity live in one tested place.

/// Converts a trackpad two-finger vertical scroll delta (logical pixels) into an
/// additive zoom-level delta.
///
/// Scroll up returns a negative delta (zoom out) and scroll down returns a
/// positive delta (zoom in). Map consumers add the result to `camera.zoom`; the
/// dive profile chart applies `pow(2, delta)` as a multiplicative factor.
double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01}) {
  return scrollDy * sensitivity;
}

/// Whether a trackpad pan-zoom gesture's cumulative [scale] marks it as a
/// pinch rather than a two-finger scroll.
///
/// A pinch's pan must not be read as a scroll. Windows reports a touchpad
/// pinch through DirectManipulation, whose transform zooms about the fingers,
/// so the gesture also carries a pan of `centroid * (1 - scale)`. Scrolled at
/// [trackpadScrollZoomDelta]'s rate, that pan outweighs the pinch and zooms the
/// wrong way (issue #3300). [tolerance] absorbs scale jitter during a scroll;
/// it is kept small because a pinch's pan still scrolls until it is crossed.
bool isTrackpadPinch(double scale, {double tolerance = 0.01}) {
  return (scale - 1).abs() > tolerance;
}
