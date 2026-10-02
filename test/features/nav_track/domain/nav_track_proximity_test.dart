import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_proximity.dart';

import '../../../helpers/nav_track_fixtures.dart';

void main() {
  final entry = DateTime.fromMillisecondsSinceEpoch(
    kTestRouteStartMs,
    isUtc: true,
  );
  const hour = 3600000;

  group('NavTrack.displayName', () {
    test('prefers the name, then the source file, then the id', () {
      expect(testNavTrack('r1', name: 'Wreck tour').displayName, 'Wreck tour');
      expect(testNavTrack('r1').displayName, 'r1.csv');
      final bare = NavTrack(
        id: 'r9',
        source: NavTrackSource.seacraftEnc,
        startTime: 0,
        endTime: 1,
        pointCount: 0,
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      expect(bare.displayName, 'r9');
    });
  });

  group('sortByProximityTo', () {
    test('orders by distance from the entry time, nearest first', () {
      final far = testNavTrack('far', startTime: kTestRouteStartMs + 5 * hour);
      final near = testNavTrack('near', startTime: kTestRouteStartMs - hour);
      final exact = testNavTrack('exact');

      final sorted = sortByProximityTo([far, near, exact], entry);

      expect(sorted.map((r) => r.id), ['exact', 'near', 'far']);
    });

    test('breaks a tie by the earlier recording, then by id', () {
      // Fed in the reverse of tie-break order, so the test fails without it.
      final laterB = testNavTrack('b', startTime: kTestRouteStartMs + hour);
      final laterA = testNavTrack('a', startTime: kTestRouteStartMs + hour);
      final earlier = testNavTrack('z', startTime: kTestRouteStartMs - hour);

      final sorted = sortByProximityTo([laterB, laterA, earlier], entry);

      expect(sorted.map((r) => r.id), ['z', 'a', 'b']);
    });

    test('returns an empty list for no routes', () {
      expect(sortByProximityTo(const [], entry), isEmpty);
    });

    test('never reorders the list it was given', () {
      final input = [
        testNavTrack('far', startTime: kTestRouteStartMs + hour),
        testNavTrack('exact'),
      ];

      sortByProximityTo(input, entry);

      expect(input.map((r) => r.id), ['far', 'exact']);
    });
  });
}
