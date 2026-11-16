import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_buoyancy_line.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

void main() {
  group('buoyancyAxisRange', () {
    test('range includes zero and pads ten percent', () {
      final range = buoyancyAxisRange([-3.0, -1.0, 2.0])!;
      expect(range.min, closeTo(-3.5, 1e-9));
      expect(range.max, closeTo(2.5, 1e-9));
    });

    test('always heavy keeps zero in range', () {
      final range = buoyancyAxisRange([-3.0, -2.0])!;
      expect(range.max, greaterThanOrEqualTo(0));
      expect(range.min, lessThan(-3.0));
    });

    test('minimum span is one kilogram', () {
      final range = buoyancyAxisRange([0.1, 0.2])!;
      expect(range.max - range.min, greaterThanOrEqualTo(1.0));
      expect(range.min, lessThan(0));
      expect(range.max, greaterThan(0.2));
    });

    test('fewer than two values gives null', () {
      expect(buoyancyAxisRange([null, 1.0]), isNull);
      expect(buoyancyAxisRange(const []), isNull);
    });

    test('non-finite values are ignored', () {
      final range = buoyancyAxisRange([double.nan, -1.0, 1.0])!;
      expect(range.min.isFinite && range.max.isFinite, isTrue);
    });
  });

  group('buoyancySignRuns', () {
    test('one crossing gives two runs sharing an interpolated zero', () {
      final runs = buoyancySignRuns([-1.0, 1.0], [0, 10]);
      expect(runs, hasLength(2));
      expect(runs[0].buoyant, isFalse);
      expect(runs[0].points.first, (t: 0.0, kg: -1.0));
      expect(runs[0].points.last, (t: 5.0, kg: 0.0));
      expect(runs[1].buoyant, isTrue);
      expect(runs[1].points.first, (t: 5.0, kg: 0.0));
      expect(runs[1].points.last, (t: 10.0, kg: 1.0));
    });

    test('exact zero does not split', () {
      final runs = buoyancySignRuns([-1.0, 0.0, -1.0], [0, 10, 20]);
      expect(runs, hasLength(1));
      expect(runs.single.buoyant, isFalse);
      expect(runs.single.points, hasLength(3));
    });

    test('a run that starts at zero takes the side it moves to', () {
      final runs = buoyancySignRuns([0.0, 1.0, 2.0], [0, 10, 20]);
      expect(runs, hasLength(1));
      expect(runs.single.buoyant, isTrue);
    });

    test('null leaves a gap', () {
      final runs = buoyancySignRuns(
        [-1.0, -1.5, null, -1.0, -2.0],
        [0, 10, 20, 30, 40],
      );
      expect(runs, hasLength(2));
      expect(runs.every((r) => !r.buoyant), isTrue);
      expect(runs[0].points.last.t, 10.0);
      expect(runs[1].points.first.t, 30.0);
    });

    test('several crossings alternate sides', () {
      final runs = buoyancySignRuns([-1.0, 1.0, -1.0, 1.0], [0, 10, 20, 30]);
      expect([for (final r in runs) r.buoyant], [false, true, false, true]);
    });
  });

  group('buildBuoyancyLines', () {
    const band = MetricBand(top: 0, span: 30);
    const range = (min: -2.0, max: 2.0);

    test('bars use the run colours and carry no fill', () {
      final runs = buoyancySignRuns([-1.0, 1.0], [0, 10]);
      final bars = buildBuoyancyLines(
        runs: runs,
        band: band,
        range: range,
        buoyant: Colors.green,
        heavy: Colors.orange,
      );
      expect(bars, hasLength(2));
      expect(bars[0].color, Colors.orange);
      expect(bars[1].color, Colors.green);
      for (final bar in bars) {
        expect(bar.belowBarData.show, isFalse);
        expect(bar.aboveBarData.show, isFalse);
        expect(bar.dotData.show, isFalse);
      }
    });

    test('values map through the band, buoyant above zero', () {
      final runs = buoyancySignRuns([-2.0, 2.0], [0, 10]);
      final bars = buildBuoyancyLines(
        runs: runs,
        band: band,
        range: range,
        buoyant: Colors.green,
        heavy: Colors.orange,
      );
      // max (+2) at the band top, min (-2) at its bottom; the chart's depth
      // axis is negated.
      expect(bars[0].spots.first.y, closeTo(-30, 1e-9));
      expect(bars[1].spots.last.y, closeTo(0, 1e-9));
      // The shared crossing sits at mid-band.
      expect(bars[0].spots.last.y, closeTo(-15, 1e-9));
      expect(bars[1].spots.first.y, closeTo(-15, 1e-9));
    });
  });

  test('neutral rule is a dashed line at zero across the window', () {
    final rule = buildNeutralRule(
      band: const MetricBand(top: 0, span: 30),
      range: (min: -2.0, max: 2.0),
      minX: 0,
      maxX: 100,
      color: Colors.grey,
    );
    expect(rule.spots.map((s) => s.x), [0, 100]);
    expect(rule.spots.every((s) => (s.y + 15).abs() < 1e-9), isTrue);
    expect(rule.dashArray, isNotNull);
    expect(rule.barWidth, lessThanOrEqualTo(1));
  });

  group('colours', () {
    const buoyant = ProfileMetricColors.buoyancyBuoyant;
    const heavy = ProfileMetricColors.buoyancyHeavy;

    test('differ from depth blue and from each other', () {
      expect(buoyant, isNot(AppColors.chartDepth));
      expect(heavy, isNot(AppColors.chartDepth));
      expect(buoyant, isNot(heavy));
    });

    test('heavy stays clear of the tank pressure orange', () {
      // The two lines are often on together; a heavy line in an orange hue
      // reads as a second pressure trace.
      final heavyHue = HSVColor.fromColor(heavy).hue;
      final pressureHue = HSVColor.fromColor(ProfileMetricColors.pressure).hue;
      final apart = (heavyHue - pressureHue).abs();
      expect(apart > 180 ? 360 - apart : apart, greaterThan(45));
    });

    test('reach 3:1 against every theme surface, light and dark', () {
      for (final preset in AppThemeRegistry.presets) {
        for (final theme in [preset.lightTheme, preset.darkTheme]) {
          final surface = theme.colorScheme.surface;
          expect(
            contrastRatio(buoyant, surface),
            greaterThanOrEqualTo(3.0),
            reason: '${preset.id} buoyant on $surface',
          );
          expect(
            contrastRatio(heavy, surface),
            greaterThanOrEqualTo(3.0),
            reason: '${preset.id} heavy on $surface',
          );
        }
      }
    });
  });

  group('keepBuoyancyGaps', () {
    test('keeps a gap the decimation dropped', () {
      // A bucket of -1, gap, +1 keeps only its min and max; without the gap
      // index the line would bridge the missing data.
      final curve = <double?>[-1, null, 1];
      expect(keepBuoyancyGaps([0, 2], curve), [0, 1, 2]);
    });

    test('adds one index per gap, in order, without duplicates', () {
      final curve = <double?>[1, null, null, 2, 3, null, 4];
      expect(keepBuoyancyGaps([0, 1, 3, 6], curve), [0, 1, 3, 5, 6]);
    });

    test('a non-finite value is a gap too', () {
      final curve = <double?>[-1, double.nan, 1];
      expect(keepBuoyancyGaps([0, 2], curve), [0, 1, 2]);
    });

    test('never adds an index past the drawn profile', () {
      final curve = <double?>[1, 2, 3, null];
      expect(keepBuoyancyGaps([0, 2], curve, length: 3), [0, 2]);
    });

    test('no gaps leaves the picked indices alone', () {
      expect(keepBuoyancyGaps([0, 3], <double?>[1, 2, 3, 4]), [0, 3]);
    });
  });
}
