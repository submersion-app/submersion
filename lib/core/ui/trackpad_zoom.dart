/// Pure helpers for trackpad two-finger-scroll zooming, shared by the maps and
/// the dive profile chart so sign and sensitivity live in one tested place.

/// Converts a trackpad two-finger vertical scroll delta (logical pixels) into an
/// additive zoom-level delta.
///
/// Negative [scrollDy] (scroll up / away from the user) returns a positive delta
/// (zoom in), matching the mouse-wheel convention so wheel and trackpad agree on
/// the same machine. Map consumers add the result to `camera.zoom`; the dive
/// profile chart applies `pow(2, delta)` as a multiplicative factor.
double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01}) {
  return -scrollDy * sensitivity;
}
