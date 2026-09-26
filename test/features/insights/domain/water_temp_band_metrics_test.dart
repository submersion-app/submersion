import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/water_temp_band_metrics.dart';

/// Issue #1873: average SAC and bottom time per water-temperature band, each
/// with the number of dives it is based on.
void main() {
  const edges = [10, 18, 24];
  final date = DateTime.utc(2026, 6, 1);

  TrendDataPoint point(String? diveId, double value) =>
      TrendDataPoint(date: date, value: value, diveId: diveId);

  test('returns no bands when no dive has a water temperature', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {},
      sacPerDive: [point('a', 1.5)],
      bottomTimePerDive: [point('a', 40)],
    );

    expect(result, isEmpty);
  });

  test('returns every band with its edges and dive count', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 0, 'b': 3, 'c': 3},
      sacPerDive: const [],
      bottomTimePerDive: const [],
    );

    expect(result.map((b) => (b.lower, b.upper, b.diveCount)), [
      (null, 10, 1),
      (10, 18, 0),
      (18, 24, 0),
      (24, null, 2),
    ]);
  });

  test('averages SAC per band over the dives that have it', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 1, 'b': 1, 'c': 1},
      sacPerDive: [point('a', 1.0), point('b', 2.0)],
      bottomTimePerDive: const [],
    );

    expect(result[1].diveCount, 3);
    expect(result[1].avgSac, 1.5);
    expect(result[1].sacDiveCount, 2);
  });

  test('averages bottom time per band over the dives that have it', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 2, 'b': 2, 'c': 2},
      sacPerDive: const [],
      bottomTimePerDive: [point('a', 30), point('b', 50)],
    );

    expect(result[2].avgBottomMinutes, 40);
    expect(result[2].bottomTimeDiveCount, 2);
  });

  test('treats a bottom time of zero as missing, not as a 0 min dive', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 0, 'b': 0},
      sacPerDive: const [],
      bottomTimePerDive: [point('a', 45), point('b', 0)],
    );

    expect(result[0].avgBottomMinutes, 45);
    expect(result[0].bottomTimeDiveCount, 1);
  });

  test('leaves an average null when no dive in the band has it', () {
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 0},
      sacPerDive: [point('a', 1.2)],
      bottomTimePerDive: [point('a', 40)],
    );

    // Band 0 has data; the empty bands and the band without data do not.
    expect(result[0].avgSac, 1.2);
    for (final band in result.skip(1)) {
      expect(band.avgSac, isNull);
      expect(band.sacDiveCount, 0);
      expect(band.avgBottomMinutes, isNull);
      expect(band.bottomTimeDiveCount, 0);
    }
  });

  test('ignores a dive the bands do not place', () {
    // 'x' has SAC and bottom time but no water temperature, and a bucketed
    // point has no dive at all: neither can be binned.
    final result = aggregateWaterTempBandMetrics(
      edges: edges,
      bandByDive: const {'a': 0},
      sacPerDive: [point('a', 1.0), point('x', 9.0), point(null, 9.0)],
      bottomTimePerDive: [point('a', 40), point('x', 90), point(null, 90)],
    );

    expect(result[0].avgSac, 1.0);
    expect(result[0].sacDiveCount, 1);
    expect(result[0].avgBottomMinutes, 40);
    expect(result[0].bottomTimeDiveCount, 1);
  });
}
