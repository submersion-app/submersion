import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/effect_size.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

import 'observation_fixtures.dart';

void main() {
  final inputs = ObservationInputs(now: now);

  test('windows are calendar years back from now', () {
    expect(inputs.recentStart, DateTime.utc(2025, 10, 5, 12));
    expect(inputs.previousStart, DateTime.utc(2024, 10, 5, 12));
    expect(inputs.recentWindowStart, DateTime.utc(2026, 7, 7, 12));
  });

  test('membership excludes the future and is half-open', () {
    expect(inputs.inRecentYear(daysAgo(1)), isTrue);
    expect(inputs.inRecentYear(now.add(const Duration(days: 1))), isFalse);
    expect(inputs.inRecentYear(inputs.recentStart), isFalse);
    expect(inputs.inPreviousYear(inputs.recentStart), isTrue);
    expect(inputs.isRecent(daysAgo(89)), isTrue);
    expect(inputs.isRecent(daysAgo(91)), isFalse);
    expect(inputs.isRecent(now.add(const Duration(hours: 1))), isFalse);
  });

  test('recency score is 1 now and 0 at the window edge', () {
    expect(inputs.recencyScore(now), closeTo(1, 1e-9));
    expect(inputs.recencyScore(daysAgo(90)), closeTo(0, 1e-9));
  });

  group('effectSize', () {
    test('null below two samples per side', () {
      expect(effectSize([1], [1, 2]), isNull);
    });
    test('pooled standard deviation', () {
      // Means 2 and 4, each sample variance 1, pooled sd 1, so d = 2.
      expect(effectSize([1, 2, 3], [3, 4, 5]), closeTo(2, 1e-9));
    });
    test('zero spread: infinite unless equal', () {
      expect(effectSize([2, 2], [3, 3]), double.infinity);
      expect(effectSize([2, 2], [2, 2]), 0);
    });
    test('meanOf', () => expect(meanOf([1, 2, 3, 6]), 3));
  });

  group('copyWith', () {
    test('ObservationDive replaces only what it is given', () {
      final d = dive('d1', daysAgo(3), maxDepthM: 20, country: 'Egypt');
      final deeper = d.copyWith(maxDepthM: 30);
      expect(deeper.maxDepthM, 30);
      expect(deeper.country, 'Egypt');
      expect(deeper.id, 'd1');
      expect(d.copyWith(), d);
    });

    test('ObservationInputs replaces only what it is given', () {
      final base = ObservationInputs(now: now, priorDives: 40);
      final moved = base.copyWith(now: daysAgo(1), recentAscentRate: 11);
      expect(moved.now, daysAgo(1));
      expect(moved.recentAscentRate, 11);
      expect(moved.priorDives, 40);
      expect(base.copyWith(), base);
    });
  });
}
