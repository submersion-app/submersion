import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

Dive dive(
  String id,
  DateTime start, {
  Duration runtime = const Duration(minutes: 50),
  int? number,
}) => Dive(
  id: id,
  diveNumber: number,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(runtime),
);

void main() {
  test('a timestamp inside exactly one window is confident', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9), number: 7);
    final d2 = dive('d2', DateTime(2026, 6, 12, 14));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 20),
      candidateDives: [d1, d2],
    );

    expect(match.kind, TimestampMatchKind.confident);
    expect(match.diveId, 'd1');
  });

  test('a timestamp with no window is none', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 13, 9),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.none);
  });

  test('overlapping windows are ambiguous', () {
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));
    final d2 = dive('d2', DateTime(2026, 6, 12, 9, 30));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 40),
      candidateDives: [d1, d2],
    );

    expect(match.kind, TimestampMatchKind.ambiguous);
    expect(match.candidateDiveIds.toSet(), {'d1', 'd2'});
  });

  test('a dive with no exit time falls back to its runtime', () {
    final d1 = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 6, 12, 9),
      runtime: const Duration(minutes: 50),
    );

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 45),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.confident);
  });

  test('a dive with no times at all gets a 60-minute window', () {
    final d1 = Dive(id: 'd1', dateTime: DateTime(2026, 6, 12, 9));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime(2026, 6, 12, 9, 55),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.confident);
  });

  test('a local timestamp and a local dive compare on wall clock', () {
    // Photo timestamps arrive wall-clock-as-UTC; dive times are local.
    // Both sides are normalized the same way, so a 09:20 photo matches a
    // 09:00 dive regardless of the host's UTC offset.
    final d1 = dive('d1', DateTime(2026, 6, 12, 9));

    final match = DiveLinkMatcher.matchAgainst(
      takenAt: DateTime.utc(2026, 6, 12, 9, 20),
      candidateDives: [d1],
    );

    expect(match.kind, TimestampMatchKind.confident);
  });
}
