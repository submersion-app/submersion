import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';

/// Resolves a dive's local wall-clock start, stored as a UTC-flagged DateTime
/// (the app's "wall-clock-as-UTC" convention: the displayed time must equal the
/// local time at the dive site regardless of the importing device's timezone).
///
/// FIT `record`/`session` timestamps are UTC. The `activity` message carries
/// both `timestamp` (UTC) and `local_timestamp`; their difference is the dive's
/// UTC offset, which we add to the UTC start to recover the local wall-clock.
///
/// fit_tool returns most timestamps already as Unix ms, but some (notably
/// `activity.localTimestamp`) come back as raw FIT-epoch seconds, so every
/// input is normalized to Unix ms before the offset is computed.
class FitTimeResolver {
  const FitTimeResolver._();

  static DateTime wallClockStart({
    required int? utcStartMs,
    required int? localStartMs,
    required int? utcTimestampMs,
    required int? localTimestampMs,
  }) {
    final rawStart = utcStartMs ?? localStartMs;
    final startMs = rawStart == null ? 0 : _toUnixMs(rawStart);
    var offsetMs = 0;
    if (utcTimestampMs != null && localTimestampMs != null) {
      offsetMs = _toUnixMs(localTimestampMs) - _toUnixMs(utcTimestampMs);
    }
    final wall = DateTime.fromMillisecondsSinceEpoch(
      startMs + offsetMs,
      isUtc: true,
    );
    // Truncate to whole seconds and keep the UTC flag.
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }

  /// Normalizes a fit_tool timestamp to Unix ms. Values at or below the uint32
  /// max are raw FIT-epoch seconds; larger values are already Unix ms.
  static int _toUnixMs(int ts) =>
      ts > 4294967295 ? ts : (ts + FitConstants.fitEpochToUnixSeconds) * 1000;
}
