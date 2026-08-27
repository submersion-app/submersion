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
