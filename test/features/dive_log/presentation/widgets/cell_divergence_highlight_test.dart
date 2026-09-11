import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cell_divergence_highlight.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  test('null or empty summaries map to no ranges', () {
    expect(cellDivergenceHighlightRanges(null, scheme), isEmpty);
    expect(
      cellDivergenceHighlightRanges(
        DiveSensorSummary(
          diveId: 'd',
          engineVersion: 1,
          sourceUpdatedAt: 1,
          computedAt: DateTime.utc(2026),
        ),
        scheme,
      ),
      isEmpty,
    );
  });

  test('every slot range becomes a highlight, sorted by start', () {
    final ranges = cellDivergenceHighlightRanges(
      DiveSensorSummary(
        diveId: 'd',
        engineVersion: 1,
        sourceUpdatedAt: 1,
        computedAt: DateTime.utc(2026),
        cellMetrics: const [
          CellMetrics(
            slot: 2,
            samples: 10,
            divergenceRanges: [
              DivergenceRange(startSeconds: 600, endSeconds: 700, peakBar: 0.2),
            ],
          ),
          CellMetrics(
            slot: 1,
            samples: 10,
            divergenceRanges: [
              DivergenceRange(
                startSeconds: 100,
                endSeconds: 200,
                peakBar: 0.15,
              ),
              DivergenceRange(
                startSeconds: 900,
                endSeconds: 950,
                peakBar: 0.11,
              ),
            ],
          ),
        ],
      ),
      scheme,
    );
    expect(ranges.map((r) => r.startTimestamp), [100, 600, 900]);
    expect(ranges.map((r) => r.endTimestamp), [200, 700, 950]);
    expect(ranges.every((r) => r.color == scheme.error), isTrue);
  });
}
