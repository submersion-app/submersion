/// Whether a dive should show the "site is at altitude but the dive is not
/// altitude-adjusted" informational note (safety phase 2).
///
/// Threshold of 100 m: below that, atmospheric pressure differs from sea
/// level by well under 1.5% and no agency treats it as altitude diving.
bool needsAltitudeAdjustmentFlag({
  required double? diveAltitude,
  required double? siteAltitude,
}) {
  final diveHasAltitude = diveAltitude != null && diveAltitude > 0;
  if (diveHasAltitude) return false;
  return siteAltitude != null && siteAltitude > 100;
}
