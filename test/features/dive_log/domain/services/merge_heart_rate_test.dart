import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/merge_heart_rate.dart';

/// The chart draws the Apple Health record's heart rate when the profile it
/// draws has none of its own (issue #637).
void main() {
  DiveProfilePoint point(int t, {int? heartRate, String? source}) =>
      DiveProfilePoint(
        timestamp: t,
        depth: 10,
        heartRate: heartRate,
        heartRateSource: source,
      );

  test('each point takes the nearest sample within the gap', () {
    final merged = mergeHeartRate(
      entryEpochSeconds: 0,
      [point(0), point(10), point(20)],
      const [
        [0, 80],
        [12, 90],
        [60, 70],
      ],
    );

    expect(merged.map((p) => p.heartRate), [80, 90, 90]);
    expect(merged.map((p) => p.heartRateSource).toSet(), {'appleWatch'});
    expect(merged.map((p) => p.depth).toSet(), {10});
  });

  test('a profile with heart rate of its own is left as it is', () {
    final profile = [
      point(0, heartRate: 70, source: 'diveComputer'),
      point(10),
    ];

    expect(
      identical(
        mergeHeartRate(entryEpochSeconds: 0, profile, const [
          [0, 80],
        ]),
        profile,
      ),
      isTrue,
    );
  });

  test('a point with no sample within the gap stays empty', () {
    final merged = mergeHeartRate(
      entryEpochSeconds: 0,
      [point(0), point(100)],
      const [
        [0, 80],
      ],
    );

    expect(merged.map((p) => p.heartRate), [80, null]);
    expect(merged.last.heartRateSource, isNull);
  });

  test('the same profile and samples give back the same list', () {
    final profile = [point(0), point(10)];
    const samples = [
      [0, 80],
    ];

    expect(
      identical(
        mergeHeartRate(entryEpochSeconds: 0, profile, samples),
        mergeHeartRate(entryEpochSeconds: 0, profile, samples),
      ),
      isTrue,
    );
  });

  test('samples stay at their own time when the dive starts later than '
      'when they were read', () {
    // Read from a tap at 1000 s; the download put the entry at 1060 s.
    final merged = mergeHeartRate(
      entryEpochSeconds: 1060,
      [point(0), point(60)],
      const [
        [1000, 70],
        [1060, 80],
        [1120, 90],
      ],
    );

    expect(merged.map((p) => p.heartRate), [80, 90]);
  });

  test('no samples leaves the profile as it is', () {
    final profile = [point(0)];

    expect(
      identical(
        mergeHeartRate(entryEpochSeconds: 0, profile, const []),
        profile,
      ),
      isTrue,
    );
  });
}
