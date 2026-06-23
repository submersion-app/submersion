import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';

DiveSummary summary(String id, [DateTime? dt]) =>
    DiveSummary(id: id, dateTime: dt ?? DateTime(2026, 1, 1), sortTimestamp: 0);

void main() {
  test('rangeIds returns inclusive span regardless of direction', () {
    final dives = ['a', 'b', 'c', 'd'].map(summary).toList();
    expect(rangeIds(dives, 1, 3), ['b', 'c', 'd']);
    expect(rangeIds(dives, 3, 1), ['b', 'c', 'd']); // reversed
    expect(rangeIds(dives, 2, 2), ['c']); // single
  });

  test('inDateRange includes dives on the boundary days', () {
    final r = DateTimeRange(
      start: DateTime(2026, 6, 1),
      end: DateTime(2026, 6, 3),
    );
    expect(inDateRange(summary('a', DateTime(2026, 6, 1, 8)), r), isTrue);
    expect(inDateRange(summary('b', DateTime(2026, 6, 3, 23)), r), isTrue);
    expect(inDateRange(summary('c', DateTime(2026, 5, 31)), r), isFalse);
  });
}
