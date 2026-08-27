import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

Trip _trip({required DateTime start, required DateTime end}) => Trip(
  id: 't1',
  name: 'Test',
  startDate: start,
  endDate: end,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('Trip.isUpcoming', () {
    test('trip ending in the future is upcoming', () {
      final t = _trip(
        start: today.add(const Duration(days: 10)),
        end: today.add(const Duration(days: 17)),
      );
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending today is still upcoming (date-only comparison)', () {
      // End set to 00:00 today: must count as upcoming even though the
      // instant is in the past — comparison is by calendar date.
      final t = _trip(
        start: today.subtract(const Duration(days: 5)),
        end: today,
      );
      expect(t.isUpcoming, isTrue);
    });

    test('trip ending yesterday is not upcoming', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 7)),
        end: today.subtract(const Duration(days: 1)),
      );
      expect(t.isUpcoming, isFalse);
      expect(t.isInProgress, isFalse);
    });
  });

  group('Trip.isInProgress and daysUntilStart', () {
    test('trip started but not ended is in progress', () {
      final t = _trip(
        start: today.subtract(const Duration(days: 2)),
        end: today.add(const Duration(days: 3)),
      );
      expect(t.isInProgress, isTrue);
      expect(t.isUpcoming, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('trip starting today is in progress with zero days until start', () {
      final t = _trip(start: today, end: today.add(const Duration(days: 5)));
      expect(t.isInProgress, isTrue);
      expect(t.daysUntilStart, 0);
    });

    test('daysUntilStart counts calendar days for a future trip', () {
      final t = _trip(
        start: today.add(const Duration(days: 24)),
        end: today.add(const Duration(days: 31)),
      );
      expect(t.daysUntilStart, 24);
      expect(t.isInProgress, isFalse);
    });
  });
}
