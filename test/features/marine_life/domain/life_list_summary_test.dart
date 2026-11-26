import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/marine_life/domain/life_list_summary.dart';

import 'species_test_entries.dart';

void main() {
  final now = DateTime(2026, 11, 25);

  test('counts new this calendar year only', () {
    final summary = summarizeLifeList([
      seenEntry('a', first: DateTime.utc(2026, 1, 1)),
      seenEntry('b', first: DateTime.utc(2026, 7, 4)),
      seenEntry('c', first: DateTime.utc(2025, 12, 31, 23)),
    ], now: now);
    expect(summary.total, 3);
    expect(summary.newThisYear, 2);
  });

  test('growth is cumulative by first-seen date with ties merged', () {
    final summary = summarizeLifeList([
      seenEntry('b', first: DateTime.utc(2025, 5, 2, 15)),
      seenEntry('a', first: DateTime.utc(2025, 5, 2, 9)),
      seenEntry('c', first: DateTime.utc(2026, 1, 1)),
    ], now: now);
    expect(summary.growth.map((p) => p.cumulative), [2, 3]);
    expect(summary.growth.first.date, DateTime.utc(2025, 5, 2));
  });

  test('empty list gives zeros and no points', () {
    final summary = summarizeLifeList(const [], now: now);
    expect(summary.total, 0);
    expect(summary.newThisYear, 0);
    expect(summary.growth, isEmpty);
  });
}
