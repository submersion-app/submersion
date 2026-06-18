import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';

void main() {
  test('no prior experience -> combined equals logged, flags false', () {
    final c = CareerTotals.from(loggedDives: 312, loggedTimeSeconds: 43 * 3600);
    expect(c.combinedDives, 312);
    expect(c.combinedTimeSeconds, 43 * 3600);
    expect(c.hasPriorDives, isFalse);
    expect(c.hasPriorTime, isFalse);
    expect(c.divingSinceResolved, isNull);
  });

  test('adds prior dives and time', () {
    final c = CareerTotals.from(
      loggedDives: 312,
      loggedTimeSeconds: 43 * 3600,
      priorDives: 1200,
      priorTimeSeconds: 1150 * 3600,
    );
    expect(c.combinedDives, 1512);
    expect(c.combinedTimeSeconds, (43 + 1150) * 3600);
    expect(c.hasPriorDives, isTrue);
    expect(c.hasPriorTime, isTrue);
    expect(c.loggedTimeFormatted, '43h 0m');
    expect(c.priorTimeFormatted, '1150h 0m');
    expect(c.combinedTimeFormatted, '1193h 0m');
  });

  test('time breakdown keeps minutes and reconciles with the total', () {
    final c = CareerTotals.from(
      loggedDives: 1,
      loggedTimeSeconds: 90 * 60, // 1h 30m
      priorTimeSeconds: 45 * 60, // 0h 45m
    );
    expect(c.loggedTimeFormatted, '1h 30m');
    expect(c.priorTimeFormatted, '0h 45m'); // not a misleading "0h"
    expect(c.combinedTimeFormatted, '2h 15m'); // 1h30m + 0h45m, reconciles
    expect(c.hasPriorTime, isTrue);
  });

  test('partial: only prior dives', () {
    final c = CareerTotals.from(
      loggedDives: 10,
      loggedTimeSeconds: 3600,
      priorDives: 90,
    );
    expect(c.combinedDives, 100);
    expect(c.hasPriorDives, isTrue);
    expect(c.hasPriorTime, isFalse);
  });

  test('negative/null prior treated as zero', () {
    final c = CareerTotals.from(
      loggedDives: 5,
      loggedTimeSeconds: 0,
      priorDives: -3,
      priorTimeSeconds: null,
    );
    expect(c.combinedDives, 5);
    expect(c.hasPriorDives, isFalse);
  });

  group('divingSinceResolved', () {
    test('entered only -> entered', () {
      final c = CareerTotals.from(
        loggedDives: 0,
        loggedTimeSeconds: 0,
        divingSince: DateTime(1990),
      );
      expect(c.divingSinceResolved, DateTime(1990));
    });

    test('entered later than first logged -> first logged (earlier)', () {
      final c = CareerTotals.from(
        loggedDives: 1,
        loggedTimeSeconds: 0,
        firstLoggedDive: DateTime(1985, 6, 1),
        divingSince: DateTime(1990),
      );
      expect(c.divingSinceResolved, DateTime(1985, 6, 1));
    });

    test('not entered -> null even if logged dives exist', () {
      final c = CareerTotals.from(
        loggedDives: 1,
        loggedTimeSeconds: 0,
        firstLoggedDive: DateTime(2020),
      );
      expect(c.divingSinceResolved, isNull);
    });
  });
}
