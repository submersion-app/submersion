/// Utilities for the first-sync date cutoff (see
/// docs/superpowers/specs/2026-08-04-first-sync-date-cutoff-design.md).
///
/// The Shearwater petrel-family fingerprint is the dive start timestamp: a
/// big-endian u32 ticks value that round-trips to Dart through
/// dc_datetime_gmtime and DateTime.utc. Synthesizing a fingerprint from a
/// cutoff date lets the driver's timestamp floor skip older dives without
/// any plugin API changes.
library;

/// Ticks for [t]'s wallclock fields, independent of its isUtc flag.
///
/// Downloaded dive times are reassembled as DateTime.utc from the device's
/// wallclock fields; using the same convention here makes cutoff ticks
/// comparable to device ticks.
int shearwaterWallclockTicks(DateTime t) =>
    DateTime.utc(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
    ).millisecondsSinceEpoch ~/
    1000;

/// Hex fingerprint (8 chars, big-endian u32) for [cutoff].
String synthesizeShearwaterFingerprint(DateTime cutoff) =>
    shearwaterWallclockTicks(cutoff).toRadixString(16).padLeft(8, '0');

/// Whether this vendor/product pair uses the shearwater_petrel backend,
/// whose fingerprint is a timestamp (Predator uses the older backend).
bool supportsTimestampFingerprintFloor({String? vendor, String? product}) {
  if (vendor == null || product == null) return false;
  if (vendor.trim().toLowerCase() != 'shearwater') return false;
  return !product.toLowerCase().contains('predator');
}
