/// Parses a Subsurface `gps` value: two decimal degrees separated by
/// whitespace or a comma, the same pair of separators Subsurface's own
/// `parse_location()` accepts.
///
/// A pair that is short, unparseable, or off the globe yields null rather
/// than a half-set or nonsensical coordinate.
///
/// The `isFinite` check is not redundant with the range check: `double`
/// parses 'NaN', and every comparison against NaN is false, so a range
/// check on its own would wave it straight through.
(double, double)? parseSubsurfaceGps(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split(RegExp(r'[\s,]+'));
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0]);
  final lon = double.tryParse(parts[1]);
  if (lat == null || lon == null) return null;
  if (!lat.isFinite || !lon.isFinite) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return (lat, lon);
}
