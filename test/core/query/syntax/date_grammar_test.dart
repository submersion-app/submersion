import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/syntax/date_grammar.dart';

void main() {
  final now = DateTime(2026, 9, 25);

  test('years, months, days and ranges', () {
    expect(parseDateText('2025', now: now), (
      start: DateTime(2025, 1, 1),
      end: DateTime(2025, 12, 31),
    ));
    expect(parseDateText('2025-02', now: now), (
      start: DateTime(2025, 2, 1),
      end: DateTime(2025, 2, 28),
    ));
    expect(parseDateText('2025-03-14', now: now), (
      start: DateTime(2025, 3, 14),
      end: DateTime(2025, 3, 14),
    ));
    expect(parseDateText('2025-03-01 to 2025-03-10', now: now), (
      start: DateTime(2025, 3, 1),
      end: DateTime(2025, 3, 10),
    ));
  });

  test('relative phrases', () {
    expect(parseDateText('this year', now: now)!.start, DateTime(2026, 1, 1));
    expect(parseDateText('last 90 days', now: now), (
      start: DateTime(2026, 6, 27),
      end: DateTime(2026, 9, 25),
    ));
    expect(parseDateText('since 2024', now: now), (
      start: DateTime(2024, 1, 1),
      end: null,
    ));
  });

  test('last N days and weeks count calendar days, not 24-hour spans', () {
    // 2026-03-08 is a spring-forward day in US zones: a Duration of 24 h
    // from local midnight on the 9th lands at 23:00 on the 7th.
    expect(parseDateText('last 1 days', now: DateTime(2026, 3, 9)), (
      start: DateTime(2026, 3, 8),
      end: DateTime(2026, 3, 9),
    ));
    expect(parseDateText('last 1 weeks', now: DateTime(2026, 3, 15)), (
      start: DateTime(2026, 3, 8),
      end: DateTime(2026, 3, 15),
    ));
  });

  test('last N months and years clamp to the target month', () {
    // March 31 minus one month is February 28, not "February 31" spilling
    // into March 3 and dropping all of February.
    expect(parseDateText('last 1 months', now: DateTime(2026, 3, 31)), (
      start: DateTime(2026, 2, 28),
      end: DateTime(2026, 3, 31),
    ));
    expect(parseDateText('last 2 months', now: DateTime(2026, 5, 31)), (
      start: DateTime(2026, 3, 31),
      end: DateTime(2026, 5, 31),
    ));
    expect(parseDateText('last 1 years', now: DateTime(2028, 2, 29)), (
      start: DateTime(2027, 2, 28),
      end: DateTime(2028, 2, 29),
    ));
  });

  test('an unpadded ISO date is not a date', () {
    expect(parseDateText('2025-3-1', now: now), isNull);
  });

  test('garbage and impossible dates are null', () {
    expect(parseDateText('sometime', now: now), isNull);
    expect(parseDateText('2025-02-30', now: now), isNull);
  });
}
