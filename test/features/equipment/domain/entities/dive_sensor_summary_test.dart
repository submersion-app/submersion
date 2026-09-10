import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

void main() {
  group('CellMetrics json', () {
    const metrics = CellMetrics(
      slot: 2,
      samples: 1840,
      gainMvPerBar: 51.3,
      p95DivergenceBar: 0.04,
      highPpO2Samples: 612,
      lowAtHighFraction: 0.0,
      divergenceRanges: [
        DivergenceRange(startSeconds: 1260, endSeconds: 1410, peakBar: 0.14),
      ],
    );

    test('round-trips through the stored column shape', () {
      final json = encodeCellMetrics([metrics]);
      expect(
        json,
        '[{"slot":2,"samples":1840,"gainMvPerBar":51.3,"p95DivergenceBar":0.04,'
        '"highPpO2Samples":612,"lowAtHighFraction":0.0,'
        '"divergenceRanges":[[1260,1410,0.14]]}]',
      );
      expect(decodeCellMetrics(json), [metrics]);
    });

    test('nullable fields survive as null', () {
      const gainOnly = CellMetrics(slot: 1, samples: 10, gainMvPerBar: 48.0);
      expect(decodeCellMetrics(encodeCellMetrics([gainOnly])), [gainOnly]);
      expect(gainOnly.p95DivergenceBar, isNull);
      expect(gainOnly.lowAtHighFraction, isNull);
      expect(gainOnly.divergenceRanges, isEmpty);
    });

    test('tolerates the column default and malformed text', () {
      expect(decodeCellMetrics('[]'), isEmpty);
      expect(decodeCellMetrics(''), isEmpty);
      expect(decodeCellMetrics('not json'), isEmpty);
      expect(decodeCellMetrics('{"slot":1}'), isEmpty);
    });
  });

  group('TransmitterGap json', () {
    const gap = TransmitterGap(
      tankId: 't1',
      transmitterSerial: '180777',
      computerId: 'c1',
      cadenceSeconds: 10,
      gapSeconds: 130,
      gapCount: 3,
      longestGapSeconds: 80,
      diveSeconds: 3480,
    );

    test('round-trips and exposes the gap fraction', () {
      expect(decodeTransmitterGaps(encodeTransmitterGaps([gap])), [gap]);
      expect(gap.gapFraction, closeTo(130 / 3480, 1e-9));
    });

    test('a zero-length dive has a zero fraction, never a division error', () {
      const empty = TransmitterGap(
        tankId: 't1',
        cadenceSeconds: 10,
        gapSeconds: 0,
        gapCount: 0,
        longestGapSeconds: 0,
        diveSeconds: 0,
      );
      expect(empty.gapFraction, 0);
      expect(decodeTransmitterGaps(encodeTransmitterGaps([empty])), [empty]);
    });

    test('tolerates the column default and malformed text', () {
      expect(decodeTransmitterGaps('[]'), isEmpty);
      expect(decodeTransmitterGaps('garbage'), isEmpty);
    });
  });

  test('DiveSensorSummary is a value object', () {
    final a = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 5,
      computedAt: DateTime.utc(2026, 9, 9),
      minTemperature: 4.0,
      maxDepth: 41.2,
      scrubberConsumedMinutes: 95,
    );
    final b = DiveSensorSummary(
      diveId: 'd1',
      engineVersion: 1,
      sourceUpdatedAt: 5,
      computedAt: DateTime.utc(2026, 9, 9),
      minTemperature: 4.0,
      maxDepth: 41.2,
      scrubberConsumedMinutes: 95,
    );
    expect(a, b);
    expect(a.cellMetrics, isEmpty);
    expect(a.transmitterGaps, isEmpty);
  });

  group('lenient decoding', () {
    // A newer peer or a corrupt row must yield null or a default, never a
    // TypeError: these decoders are documented as lenient and run on the
    // sync path, where a throw takes the whole batch down.
    test('CellMetrics survives a wrong type on a counted field', () {
      final metrics = CellMetrics.fromJson({
        'slot': 1,
        'samples': 10,
        'highPpO2Samples': 'lots',
        'gainMvPerBar': 'plenty',
      });
      expect(metrics, isNotNull);
      expect(metrics!.slot, 1);
      expect(metrics.highPpO2Samples, 0);
      expect(metrics.gainMvPerBar, isNull);
    });

    test('TransmitterGap survives wrong types on its fields', () {
      final gap = TransmitterGap.fromJson({
        'tankId': 't1',
        'cadenceSeconds': 10,
        'transmitterSerial': 42,
        'computerId': {'nested': true},
        'gapSeconds': 'none',
        'gapCount': 'none',
        'longestGapSeconds': 'none',
        'diveSeconds': 'none',
      });
      expect(gap, isNotNull);
      expect(gap!.tankId, 't1');
      expect(gap.transmitterSerial, isNull);
      expect(gap.computerId, isNull);
      expect(gap.gapSeconds, 0);
      expect(gap.diveSeconds, 0);
    });
  });
}
