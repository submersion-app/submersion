import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/time_grammar.dart';

void main() {
  final now = DateTime(2026, 9, 19);

  test('a bare year covers the whole year', () {
    final r = parseTimeText('2023', now: now)!;
    expect(r.start, DateTime(2023, 1, 1));
    expect(r.end, DateTime(2023, 12, 31));
  });

  test('month year and ISO month cover the month', () {
    for (final text in ['May 2023', 'may 2023', '2023-05']) {
      final r = parseTimeText(text, now: now)!;
      expect(r.start, DateTime(2023, 5, 1), reason: text);
      expect(r.end, DateTime(2023, 5, 31), reason: text);
    }
  });

  test('relative periods anchor on now', () {
    expect(parseTimeText('this year', now: now), (
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 12, 31),
    ));
    expect(parseTimeText('last year', now: now), (
      start: DateTime(2025, 1, 1),
      end: DateTime(2025, 12, 31),
    ));
    expect(parseTimeText('this month', now: now), (
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    ));
    expect(parseTimeText('last month', now: now), (
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 31),
    ));
  });

  test('last N units count back from today inclusive', () {
    expect(parseTimeText('last 30 days', now: now), (
      start: DateTime(2026, 8, 20),
      end: DateTime(2026, 9, 19),
    ));
    expect(parseTimeText('past 2 weeks', now: now), (
      start: DateTime(2026, 9, 5),
      end: DateTime(2026, 9, 19),
    ));
    expect(parseTimeText('last 6 months', now: now), (
      start: DateTime(2026, 3, 19),
      end: DateTime(2026, 9, 19),
    ));
    expect(parseTimeText('last 2 years', now: now), (
      start: DateTime(2024, 9, 19),
      end: DateTime(2026, 9, 19),
    ));
  });

  test('since and before are open ended', () {
    expect(parseTimeText('since 2022', now: now), (
      start: DateTime(2022, 1, 1),
      end: null,
    ));
    expect(parseTimeText('since May 2023', now: now), (
      start: DateTime(2023, 5, 1),
      end: null,
    ));
    expect(parseTimeText('before 2022', now: now), (
      start: null,
      end: DateTime(2021, 12, 31),
    ));
  });

  test('ISO dates and ranges', () {
    expect(parseTimeText('2023-05-14', now: now), (
      start: DateTime(2023, 5, 14),
      end: DateTime(2023, 5, 14),
    ));
    expect(parseTimeText('2023-05-01 to 2023-05-14', now: now), (
      start: DateTime(2023, 5, 1),
      end: DateTime(2023, 5, 14),
    ));
  });

  test('anything else is null', () {
    expect(parseTimeText('when the water was warm', now: now), isNull);
    expect(parseTimeText('', now: now), isNull);
    expect(parseTimeText('99999', now: now), isNull);
  });
}
