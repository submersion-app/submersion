/// Human-readable byte count, matching the thresholds and precision this app
/// already uses elsewhere: bytes verbatim, KB and MB to one decimal, GB to
/// two.
///
/// Unit settings do not apply. The diver's preferences cover seven physical
/// quantities (depth, temperature, pressure, volume, weight, altitude, SAC)
/// plus date and time formatting, and a byte is none of them.
///
/// The suffixes are intentionally not localized. Every existing size display
/// in this app hardcodes them and no ARB catalog carries a size unit, so
/// introducing one here would leave the app inconsistent with itself for no
/// reader benefit.
///
/// A negative size is rendered as zero rather than as a negative quantity:
/// callers pass a stored `contentSizeBytes`, and a nonsensical value there
/// should read as "nothing recorded", not as a negative file.
String formatBytes(int bytes) {
  if (bytes < 0) return '0 B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}
