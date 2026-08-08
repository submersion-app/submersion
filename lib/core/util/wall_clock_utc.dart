/// Wall-clock-UTC date utilities.
///
/// Submersion treats dive-computer-style timestamps as wall-clock-UTC: the
/// digits the user sees on their dive computer face are stored verbatim as
/// the components of a `DateTime.utc(...)`. This file centralizes the two
/// flavors of "convert an external timestamp into wall-clock-UTC" used
/// throughout the media import pipeline:
///
/// * [parseExternalDateAsWallClockUtc] — parse an ISO-8601-ish string,
///   honoring an explicit zone designator if present and otherwise
///   reinterpreting offset-less wall-clock components as UTC.
/// * [asWallClockUtc] — reinterpret a local `DateTime`'s components as
///   UTC verbatim, used for filesystem mtimes that arrive in local time
///   but should match wall-clock-UTC dive times.
/// * [fromWallClockUtc] — the inverse, for reading a stored wall-clock-UTC
///   value back into the local `DateTime` the UI works in.
library;

/// Matches a trailing `Z` or `+hh:mm` / `-hh:mm` / `+hhmm` / `-hhmm` offset
/// on an ISO-8601 timestamp. Used to detect "no offset given" so we can
/// reinterpret as UTC rather than shifting from local time.
final RegExp _isoOffset = RegExp(r'(Z|[+\-]\d{2}:?\d{2})$');

/// Parses an ISO-8601-ish date string and returns it as a UTC `DateTime`,
/// applying the codebase's wall-clock-as-UTC convention.
///
/// If [raw] carries a timezone designator (Z or ±HH:MM / ±HHMM), the
/// returned DateTime represents the same absolute moment in UTC
/// (`DateTime.parse(raw).toUtc()`).
///
/// If [raw] lacks a timezone designator, the wall-clock components are
/// REINTERPRETED as UTC — i.e. `"2024-04-12T14:32:00"` returns
/// `DateTime.utc(2024, 4, 12, 14, 32, 0)`. This matches how dive
/// computers store time (no timezone metadata; the digits ARE the dive's
/// wall clock) and how Submersion persists `takenAt` for matching.
///
/// Returns null when the string is unparseable.
DateTime? parseExternalDateAsWallClockUtc(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  if (parsed.isUtc) return parsed;
  if (_isoOffset.hasMatch(raw)) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
  );
}

/// Reinterprets a local `DateTime`'s wall-clock components as UTC.
///
/// Used for filesystem mtimes (`File.lastModifiedSync()` returns local)
/// when we want to treat the digits as wall-clock-UTC for matching.
/// Example: an mtime of `2024-04-12 14:32 EDT` becomes
/// `DateTime.utc(2024, 4, 12, 14, 32, 0)` — NOT shifted by the offset.
DateTime asWallClockUtc(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
  local.hour,
  local.minute,
  local.second,
  local.millisecond,
);

/// Reads a wall-clock-UTC `DateTime` back as a local one with the same
/// digits -- the inverse of [asWallClockUtc].
///
/// Use this when a stored wall-clock-UTC value has to re-enter code that
/// thinks in local time (pickers, formatters, filter bounds). Because both
/// directions copy components rather than shifting by an offset, a value
/// written on one device reads back with the same calendar digits on a
/// device in any other timezone.
///
/// A `DateTime` that is already local is returned unchanged, so callers do
/// not have to track which flavor they are holding.
DateTime fromWallClockUtc(DateTime wallClockUtc) {
  if (!wallClockUtc.isUtc) return wallClockUtc;
  return DateTime(
    wallClockUtc.year,
    wallClockUtc.month,
    wallClockUtc.day,
    wallClockUtc.hour,
    wallClockUtc.minute,
    wallClockUtc.second,
    wallClockUtc.millisecond,
  );
}
