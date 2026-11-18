import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/vertical_distance/vertical_distance_timeline.dart';

DiveVerticalDistance _dive(
  String id,
  double meters, {
  bool estimated = false,
  int startMillis = 0,
}) => DiveVerticalDistance(
  diveId: id,
  startMillis: startMillis,
  meters: meters,
  estimated: estimated,
);

/// The running total and the date lookup behind the readout (issue #4569).
void main() {
  group('VerticalDistanceTimeline', () {
    // Running totals after each dive: 10, 10, 35.5, 40.
    final t = VerticalDistanceTimeline([
      _dive('A', 10),
      _dive('B', 0),
      _dive('C', 25.5, estimated: true),
      _dive('D', 4.5),
    ]);

    test('totals and counts', () {
      expect(t.totalMeters, 40);
      expect(t.countedDives, 3);
      expect(t.estimatedDives, 1);
      expect(t.isEmpty, isFalse);
    });

    test('the first dive whose running total reaches a level', () {
      expect(t.crossingAt(0.5)!.diveId, 'A');
      expect(t.crossingAt(35.5)!.diveId, 'C');
      expect(t.crossingAt(40)!.diveId, 'D');
    });

    test('a level exactly on a dive\'s total belongs to that dive', () {
      expect(t.crossingAt(10)!.diveId, 'A');
    });

    test('a dive that added nothing is never the crossing', () {
      expect(t.crossingAt(10.01)!.diveId, 'C');
    });

    test('no crossing above the total or at zero', () {
      expect(t.crossingAt(40.01), isNull);
      expect(t.crossingAt(0), isNull);
      expect(t.crossingAt(-1), isNull);
    });

    test('an estimated dive with no depth is not counted as estimated', () {
      final z = VerticalDistanceTimeline([
        _dive('A', 0, estimated: true),
        _dive('B', 12),
      ]);
      expect(z.countedDives, 1);
      expect(z.estimatedDives, 0);
    });

    test('the empty timeline', () {
      expect(VerticalDistanceTimeline.empty.isEmpty, isTrue);
      expect(VerticalDistanceTimeline.empty.totalMeters, 0);
      expect(VerticalDistanceTimeline.empty.crossingAt(1), isNull);
      expect(VerticalDistanceTimeline([_dive('A', 0)]).isEmpty, isTrue);
    });

    test('the lookup scales to a long logbook', () {
      final long = VerticalDistanceTimeline([
        for (var i = 0; i < 10000; i++) _dive('d$i', 1),
      ]);
      expect(long.totalMeters, 10000);
      // 7,500.5 m is reached during the 7,501st dive, index 7500.
      expect(long.crossingAt(7500.5)!.diveId, 'd7500');
    });
  });
}
