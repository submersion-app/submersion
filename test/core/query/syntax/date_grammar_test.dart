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

  test('garbage and impossible dates are null', () {
    expect(parseDateText('sometime', now: now), isNull);
    expect(parseDateText('2025-02-30', now: now), isNull);
  });
}
