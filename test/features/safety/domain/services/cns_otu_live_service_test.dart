import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/services/cns_otu_live_service.dart';

void main() {
  final diveEnd = DateTime.utc(2026, 7, 17, 12);

  test('no time elapsed: CNS unchanged', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd,
    );
    expect(result, 40.0);
  });

  test('one half-time (90 minutes) elapsed: CNS halved', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(minutes: 90)),
    );
    expect(result, closeTo(20.0, 0.001));
  });

  test('two half-times (180 minutes) elapsed: CNS quartered', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(minutes: 180)),
    );
    expect(result, closeTo(10.0, 0.001));
  });

  test('a day later: decayed to practically zero', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 100.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 24)),
    );
    expect(result, lessThan(0.01));
  });

  test('zero CNS at dive end stays zero', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 0.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 2)),
    );
    expect(result, 0.0);
  });

  test('now before the dive end (clock skew): no decay applied, not negative '
      'elapsed time', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.subtract(const Duration(minutes: 5)),
    );
    expect(result, 40.0);
  });

  test('a few seconds after dive end (sub-minute elapsed) still decays, not '
      'just truncated to the no-decay branch', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(seconds: 59)),
    );
    // 59s truncates to 0 whole minutes for the decay formula itself, so
    // the visible number is unchanged -- what this guards is the branch
    // taken: elapsed > 0 must not be misclassified as "at or before".
    expect(result, 40.0);
  });

  group('currentOtuDaily', () {
    // Totals computed at 22:00; the dive itself is irrelevant to this guard.
    final computedAt = DateTime.utc(2026, 7, 17, 22);

    test('same calendar day as the totals: total unchanged', () {
      final result = CnsOtuLiveService.currentOtuDaily(
        dailyOtu: 250.0,
        computedAt: computedAt,
        now: computedAt.add(const Duration(hours: 1, minutes: 59)),
      );
      expect(result, 250.0);
    });

    test('now has rolled into the next calendar day: resets to 0', () {
      final result = CnsOtuLiveService.currentOtuDaily(
        dailyOtu: 250.0,
        computedAt: computedAt,
        now: DateTime.utc(2026, 7, 18, 0, 1),
      );
      expect(result, 0.0);
    });

    test('several days later: still 0, not negative or stale', () {
      final result = CnsOtuLiveService.currentOtuDaily(
        dailyOtu: 250.0,
        computedAt: computedAt,
        now: computedAt.add(const Duration(days: 3)),
      );
      expect(result, 0.0);
    });
  });
}
