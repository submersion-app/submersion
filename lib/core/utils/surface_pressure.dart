/// Normalizes a surface (atmospheric) pressure that is nominally in bar.
///
/// Atmospheric surface pressure is only ever ~0.5 bar (high altitude) to
/// ~1.06 bar (sea level). Some import/legacy paths have stored millibar/
/// hectopascal values (e.g. 1013) in the bar-typed field. Used verbatim, a
/// value ~1000x too large poisons the decompression model (tissue tensions of
/// hundreds of bar, NDL saturating at its "unlimited" sentinel) and shows
/// absurd figures on the dive detail page.
///
/// So: convert an obvious mbar/hPa value to bar, then reject (return null)
/// anything still physically impossible, so callers fall back to the
/// altitude-derived or standard 1.0 bar surface instead of garbage.
///
/// Because no real surface pressure is ever outside ~0.5-1.1 bar, this only
/// ever touches corrupt data.
double? normalizeSurfacePressureBar(double? raw) {
  if (raw == null) return null;
  var bar = raw;
  if (bar > 100.0) bar /= 1000.0; // millibar / hectopascal -> bar
  if (bar < 0.5 || bar > 1.1) return null; // implausible -> ignore
  return bar;
}
