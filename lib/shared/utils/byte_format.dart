import 'package:submersion/core/utils/byte_format.dart' show byteSizeLabel;

/// Human-readable byte count, matching the thresholds and precision this app
/// already uses elsewhere: bytes verbatim, KB and MB to one decimal, GB to
/// two.
///
/// Unit settings do not apply. The diver's preferences cover seven physical
/// quantities (depth, temperature, pressure, volume, weight, altitude, SAC)
/// plus date and time formatting, and a byte is none of them.
///
/// The number and unit are written the way the active language writes them,
/// through the same `byteSizeLabel` as `core/utils/byte_format.dart`, so every
/// size in the app reads alike (French: `1,5 Mo`).
///
/// A negative size is rendered as zero rather than as a negative quantity:
/// callers pass a stored `contentSizeBytes`, and a nonsensical value there
/// should read as "nothing recorded", not as a negative file.
String formatBytes(int bytes) {
  if (bytes < 0) return byteSizeLabel('0', 'B');
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < kb) return byteSizeLabel('$bytes', 'B');
  if (bytes < mb) return byteSizeLabel((bytes / kb).toStringAsFixed(1), 'KB');
  if (bytes < gb) return byteSizeLabel((bytes / mb).toStringAsFixed(1), 'MB');
  return byteSizeLabel((bytes / gb).toStringAsFixed(2), 'GB');
}
