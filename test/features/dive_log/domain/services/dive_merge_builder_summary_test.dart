import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';

/// Summary values that describe the whole dive (issue #4136). A Combine took
/// each from the first segment that had one, so the combined dive reported
/// the first segment's temperature and loop oxygen range alone.
Dive _segment(String id, DateTime entry, {int runtimeMin = 30}) => Dive(
  id: id,
  diverId: 'diver1',
  dateTime: entry,
  entryTime: entry,
  runtime: Duration(minutes: runtimeMin),
);

void main() {
  const builder = DiveMergeBuilder();
  final firstEntry = DateTime.utc(2021, 8, 1, 13, 47);
  final secondEntry = DateTime.utc(2021, 8, 1, 14, 30);

  group('build - whole-dive summaries (#4136)', () {
    test('water temperature is the coldest segment\'s minimum', () {
      final a = _segment('a', firstEntry).copyWith(waterTemp: 16);
      final b = _segment('b', secondEntry).copyWith(waterTemp: 8);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.waterTemp, 8);
    });

    test('water temperature skips a segment that has none', () {
      final a = _segment('a', firstEntry);
      final b = _segment('b', secondEntry).copyWith(waterTemp: 12);
      expect(builder.build([a, b]).mergedDive.waterTemp, 12);
      expect(
        builder
            .build([_segment('a', firstEntry), _segment('b', secondEntry)])
            .mergedDive
            .waterTemp,
        isNull,
      );
    });

    test('loop O2 minimum and maximum span every segment', () {
      final a = _segment(
        'a',
        firstEntry,
      ).copyWith(loopO2Min: 1.1, loopO2Max: 1.3);
      final b = _segment(
        'b',
        secondEntry,
      ).copyWith(loopO2Min: 0.9, loopO2Max: 1.4);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.loopO2Min, 0.9);
      expect(merged.loopO2Max, 1.4);
    });

    test('loop O2 average is weighted by each segment\'s runtime', () {
      final a = _segment(
        'a',
        firstEntry,
        runtimeMin: 10,
      ).copyWith(loopO2Avg: 1.0);
      final b = _segment(
        'b',
        secondEntry,
        runtimeMin: 30,
      ).copyWith(loopO2Avg: 1.2);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.loopO2Avg, closeTo(1.15, 1e-9));
    });

    test('a planned segment\'s values never become the logged dive\'s', () {
      final a = _segment('a', firstEntry).copyWith(waterTemp: 14);
      final b = _segment(
        'b',
        secondEntry,
      ).copyWith(waterTemp: 10, loopO2Max: 1.6, isPlanned: true);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.waterTemp, 14);
      expect(merged.loopO2Max, isNull);
    });

    test('loop O2 average falls back to the only value when unweighted', () {
      final a = _segment(
        'a',
        firstEntry,
        runtimeMin: 0,
      ).copyWith(loopO2Avg: 1.05);
      final b = _segment('b', secondEntry, runtimeMin: 0);
      expect(builder.build([a, b]).mergedDive.loopO2Avg, 1.05);
    });
  });
}
