import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_time_resolver.dart';

void main() {
  // Malta dive: session.startTime is 08:51:10 UTC; the activity message's
  // local_timestamp shows 10:51:10 (UTC+2). The displayed wall-clock must be
  // 10:51:10, stored as a UTC-flagged DateTime (wall-clock-as-UTC convention).
  final utcStart = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final utcAct = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final localAct = DateTime.utc(
    2025,
    10,
    13,
    10,
    51,
    10,
  ).millisecondsSinceEpoch;

  test('applies the activity UTC offset to the session start', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: utcAct,
      localTimestampMs: localAct,
    );
    expect(result, DateTime.utc(2025, 10, 13, 10, 51, 10));
    expect(result.isUtc, isTrue);
  });

  test('falls back to the raw start when no local_timestamp is present', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: null,
      localTimestampMs: null,
    );
    expect(result, DateTime.utc(2025, 10, 13, 8, 51, 10));
  });

  test('normalizes a FIT-epoch-seconds local_timestamp (real-file quirk)', () {
    // fit_tool returns activity.timestamp as Unix ms but activity.localTimestamp
    // as raw FIT-epoch seconds. Dive is 07:19:49 UTC, 09:19:49 local (+2h).
    final utcInstant = DateTime.utc(2025, 9, 8, 7, 19, 49);
    final localFitSeconds =
        DateTime.utc(2025, 9, 8, 9, 19, 49).millisecondsSinceEpoch ~/ 1000 -
        FitConstants.fitEpochToUnixSeconds;

    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcInstant.millisecondsSinceEpoch,
      localStartMs: null,
      utcTimestampMs: utcInstant.millisecondsSinceEpoch,
      localTimestampMs: localFitSeconds,
    );

    expect(result, DateTime.utc(2025, 9, 8, 9, 19, 49));
  });

  test('returns the Unix epoch when no start is provided', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: null,
      localStartMs: null,
      utcTimestampMs: null,
      localTimestampMs: null,
    );
    expect(result, DateTime.utc(1970, 1, 1));
  });
}
