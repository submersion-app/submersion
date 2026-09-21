import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_agreement.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<DiveProfilePoint> _profile(int count) =>
    List.generate(count, (i) => DiveProfilePoint(timestamp: i * 10, depth: 10));

List<int> _allIndices(List<int?> curve) => [
  for (var i = 0; i < curve.length; i++)
    if (curve[i] != null) i,
];

void main() {
  group('buildO2CellMvLines', () {
    test('pairs each returned line with the physical cell it belongs to', () {
      final lines = buildO2CellMvLines(
        const MetricBand(top: 0, span: 10),
        [
          [50, 51, 52],
          [60, 61, 62],
          [70, 71, 72],
        ],
        _profile(3),
        (min: 0, max: 100),
        _allIndices,
      );

      expect(lines.map((l) => l.cell).toList(), [0, 1, 2]);
    });

    test('skips a cell with no data, keeping the remaining cells\' own '
        'indices intact rather than shifting them down', () {
      final lines = buildO2CellMvLines(
        const MetricBand(top: 0, span: 10),
        [
          [50, 51, 52],
          [null, null, null],
          [70, 71, 72],
        ],
        _profile(3),
        (min: 0, max: 100),
        _allIndices,
      );

      expect(lines.map((l) => l.cell).toList(), [0, 2]);
    });
  });

  group('buildO2CellTooltipRows', () {
    test('tags each sensor row with its own cell, not a shared identity', () {
      final rows = buildO2CellTooltipRows(
        0,
        [
          [1.1],
          [1.2],
        ],
        null,
        null,
        lookupAppLocalizations(const Locale('en')),
      );

      final sensorRows = rows
          .where((r) => r.label.startsWith('Sensor'))
          .toList();
      expect(sensorRows, hasLength(2));
      expect(sensorRows[0].metric, const O2CellMetric(0));
      expect(sensorRows[1].metric, const O2CellMetric(1));
      expect(sensorRows[0].metric, isNot(sensorRows[1].metric));
    });
  });
}
