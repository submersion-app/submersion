import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/services/move_time.dart';

void main() {
  final now = DateTime(2026, 9, 10, 15, 30, 12);

  test('today with no time chosen is now', () {
    expect(resolveMovedAt(day: DateTime(2026, 9, 10), now: now), now);
  });

  test('an earlier day with no time chosen is local noon', () {
    expect(
      resolveMovedAt(day: DateTime(2026, 9, 3), now: now),
      DateTime(2026, 9, 3, 12),
    );
  });

  test('a chosen time is used on any day, so a backdated move can land '
      'after a same-day one', () {
    expect(
      resolveMovedAt(
        day: DateTime(2026, 9, 9),
        time: (hour: 19, minute: 5),
        now: now,
      ),
      DateTime(2026, 9, 9, 19, 5),
    );
    expect(
      resolveMovedAt(
        day: DateTime(2026, 9, 10),
        time: (hour: 8, minute: 0),
        now: now,
      ),
      DateTime(2026, 9, 10, 8),
    );
  });

  test('a chosen time later today is held at now, never in the future', () {
    expect(
      resolveMovedAt(
        day: DateTime(2026, 9, 10),
        time: (hour: 18, minute: 0),
        now: now,
      ),
      now,
    );
  });

  test('notAfterNow keeps a past time and holds a future one at now', () {
    final past = DateTime(2026, 9, 10, 9);
    expect(notAfterNow(past, now), past);
    expect(notAfterNow(DateTime(2026, 9, 10, 18), now), now);
  });
}
