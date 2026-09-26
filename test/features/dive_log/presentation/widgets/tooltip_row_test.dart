import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';

const _row = TooltipRow(
  label: 'Temp',
  value: '20 C',
  bulletColor: Colors.orange,
  diamondBullet: true,
  metric: ProfileRightAxisMetric.temperature,
);

void main() {
  group('TooltipRow.copyWith', () {
    test('with no arguments keeps every field', () {
      final copy = _row.copyWith();

      expect(copy.label, _row.label);
      expect(copy.value, _row.value);
      expect(copy.bulletColor, _row.bulletColor);
      expect(copy.diamondBullet, _row.diamondBullet);
      expect(copy.metric, _row.metric);
    });

    test('replaces only the fields it is given', () {
      final copy = _row.copyWith(value: '20 C (interpolated)');

      expect(copy.value, '20 C (interpolated)');
      expect(copy.label, _row.label);
      expect(copy.bulletColor, _row.bulletColor);
      expect(copy.diamondBullet, isTrue);
      expect(copy.metric, ProfileRightAxisMetric.temperature);
    });

    test('replaces every field when all are given', () {
      final copy = _row.copyWith(
        label: 'Depth',
        value: '12 m',
        bulletColor: Colors.blue,
        diamondBullet: false,
        metric: ChartOnlyMetric.depth,
      );

      expect(copy.label, 'Depth');
      expect(copy.value, '12 m');
      expect(copy.bulletColor, Colors.blue);
      expect(copy.diamondBullet, isFalse);
      expect(copy.metric, ChartOnlyMetric.depth);
    });
  });
}
