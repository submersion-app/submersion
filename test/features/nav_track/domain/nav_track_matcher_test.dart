import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/nav_track/domain/nav_track_matcher.dart';

int _sec(int y, int m, int d, int h, int min, [int s = 0]) =>
    DateTime.utc(y, m, d, h, min, s).millisecondsSinceEpoch ~/ 1000;

Dive _dive(String id, DateTime entry, {DateTime? exit, Duration? runtime}) =>
    Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      exitTime: exit,
      runtime: runtime,
    );

void main() {
  group('NavTrackMatcher.candidatesFor', () {
    test('matches a dive whose window fully contains the route', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 30),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 10, 23),
        routeEndSeconds: _sec(2026, 8, 22, 11, 5, 47),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('matches using runtime when no exit time is stored', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        runtime: const Duration(minutes: 90),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 10),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('matches within the 30-minute tolerance on either side', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route starts 20 minutes before the dive's own entry -- within the
      // 30-minute tolerance -- and ends inside the dive.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 9, 40),
        routeEndSeconds: _sec(2026, 8, 22, 10, 30),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('does not match beyond the 30-minute tolerance', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route ends 31 minutes before the dive starts (tolerance-extended
      // dive window starts at 9:30) -- just outside.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 8, 0),
        routeEndSeconds: _sec(2026, 8, 22, 9, 29),
        dives: [dive],
      );
      expect(result, isEmpty);
    });

    test('matches exactly at the edge of the tolerance', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      // Route ends exactly 30 minutes before the dive starts.
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 8, 0),
        routeEndSeconds: _sec(2026, 8, 22, 9, 30),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('returns an empty list when no dive is close in time', () {
      final dive = _dive(
        'd1',
        DateTime.utc(2026, 1, 1, 10, 0),
        exit: DateTime.utc(2026, 1, 1, 11, 0),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [dive],
      );
      expect(result, isEmpty);
    });

    test('orders multiple candidates by overlap, largest first', () {
      final barelyOverlapping = _dive(
        'barely',
        DateTime.utc(2026, 8, 22, 9, 45),
        exit: DateTime.utc(2026, 8, 22, 10, 5),
      );
      final fullyOverlapping = _dive(
        'full',
        DateTime.utc(2026, 8, 22, 10, 0),
        exit: DateTime.utc(2026, 8, 22, 11, 0),
      );
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: [barelyOverlapping, fullyOverlapping],
      );
      expect(result.map((d) => d.id), ['full', 'barely']);
    });

    test('a dive with neither exit time nor runtime still matches at its '
        'own instant', () {
      final dive = _dive('d1', DateTime.utc(2026, 8, 22, 10, 0));
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 9, 50),
        routeEndSeconds: _sec(2026, 8, 22, 10, 10),
        dives: [dive],
      );
      expect(result, [dive]);
    });

    test('returns an empty list for an empty dive list', () {
      final result = NavTrackMatcher.candidatesFor(
        routeStartSeconds: _sec(2026, 8, 22, 10, 0),
        routeEndSeconds: _sec(2026, 8, 22, 11, 0),
        dives: const [],
      );
      expect(result, isEmpty);
    });
  });
}
