import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

void main() {
  const matcher = DivePhotoMatcher();

  // Dive A: 10:00 - 11:00. Extended window 09:30 - 12:00.
  final diveA = DiveBounds(
    diveId: 'A',
    entryTime: DateTime.utc(2026, 7, 1, 10),
    exitTime: DateTime.utc(2026, 7, 1, 11),
  );
  // Dive B: 12:30 - 13:30. Extended window 12:00 - 14:30.
  final diveB = DiveBounds(
    diveId: 'B',
    entryTime: DateTime.utc(2026, 7, 1, 12, 30),
    exitTime: DateTime.utc(2026, 7, 1, 13, 30),
  );

  TimestampMatch match(DateTime t, List<DiveBounds> dives) =>
      matcher.matchTimestamp(takenAt: t, dives: dives);

  test('inside core window of a lone dive is confident', () {
    final result = match(DateTime.utc(2026, 7, 1, 10, 30), [diveA]);
    expect(result.kind, TimestampMatchKind.confident);
    expect(result.diveId, 'A');
  });

  test('post-margin of a lone dive is confident (single extended hit)', () {
    final result = match(DateTime.utc(2026, 7, 1, 11, 45), [diveA]);
    expect(result.kind, TimestampMatchKind.confident);
    expect(result.diveId, 'A');
  });

  test('surface interval covered by two extended windows is ambiguous with '
      'candidates ordered by entry proximity', () {
    // 12:00 sits in A's post-margin (exit 11:00 + 60m) boundary and B's
    // pre-margin (entry 12:30 - 30m) boundary. |12:00-12:30| = 30m beats
    // |12:00-10:00| = 2h, so B is the closer candidate.
    final result = match(DateTime.utc(2026, 7, 1, 12), [diveA, diveB]);
    expect(result.kind, TimestampMatchKind.ambiguous);
    expect(result.candidateDiveIds, ['B', 'A']);
    expect(result.diveId, isNull);
  });

  test('a unique core hit wins over another dive margin overlap', () {
    // Dive C overlaps A's post-margin with its core: C runs 11:30 - 12:30.
    final diveC = DiveBounds(
      diveId: 'C',
      entryTime: DateTime.utc(2026, 7, 1, 11, 30),
      exitTime: DateTime.utc(2026, 7, 1, 12, 30),
    );
    // 11:45 is inside C's core and inside A's extended window.
    final result = match(DateTime.utc(2026, 7, 1, 11, 45), [diveA, diveC]);
    expect(result.kind, TimestampMatchKind.confident);
    expect(result.diveId, 'C');
  });

  test('outside every window is none', () {
    final result = match(DateTime.utc(2026, 7, 1, 8), [diveA, diveB]);
    expect(result.kind, TimestampMatchKind.none);
  });

  test('extended window boundaries are inclusive', () {
    final atStart = match(DateTime.utc(2026, 7, 1, 9, 30), [diveA]);
    expect(atStart.kind, TimestampMatchKind.confident);

    final beforeStart = match(DateTime.utc(2026, 7, 1, 9, 29, 59), [diveA]);
    expect(beforeStart.kind, TimestampMatchKind.none);
  });
}
