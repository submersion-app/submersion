import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_tick_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const metric = UnitFormatter(AppSettings());
  const psi = UnitFormatter(AppSettings(pressureUnit: PressureUnit.psi));

  String tick(
    ProfileRightAxisMetric m,
    double value, {
    double? step,
    UnitFormatter units = metric,
  }) => formatRightAxisTick(m, value, units, tickStep: step);

  group('formatRightAxisTick', () {
    // Issue #3055: a 3 C temperature range spread over eleven depth-grid
    // ticks printed 31, 31, 31, 30, 30, 30, 30, 29 ... at whole degrees.
    test('gives adjacent temperature ticks distinct labels', () {
      const step = 0.3;
      final labels = [
        for (var i = 0; i < 11; i++)
          tick(ProfileRightAxisMetric.temperature, 31.0 - i * step, step: step),
      ];
      expect(labels.first, '31.0');
      expect(labels[1], '30.7');
      expect(labels.toSet().length, labels.length);
    });

    test('keeps whole numbers when the ticks are a whole unit apart', () {
      expect(tick(ProfileRightAxisMetric.temperature, 30, step: 1), '30');
      expect(tick(ProfileRightAxisMetric.temperature, 30, step: 2.5), '30');
    });

    test('falls back to the metric precision without a usable step', () {
      expect(tick(ProfileRightAxisMetric.temperature, 29.6), '30');
      expect(tick(ProfileRightAxisMetric.temperature, 29.6, step: 0), '30');
      expect(tick(ProfileRightAxisMetric.ppO2, 1.04, step: double.nan), '1.0');
    });

    // Without a step every metric keeps the label the chart printed before
    // adaptive precision: its own unit conversion and decimals.
    test('keeps each metric label as before without a step', () {
      const expected = {
        ProfileRightAxisMetric.temperature: '13',
        ProfileRightAxisMetric.pressure: '13',
        ProfileRightAxisMetric.heartRate: '13',
        ProfileRightAxisMetric.sac: '12.5',
        ProfileRightAxisMetric.ascentRate: '13',
        ProfileRightAxisMetric.ndl: '0',
        ProfileRightAxisMetric.ppO2: '12.5',
        ProfileRightAxisMetric.ppN2: '12.5',
        ProfileRightAxisMetric.ppHe: '12.5',
        ProfileRightAxisMetric.gasDensity: '12.5',
        ProfileRightAxisMetric.gf: '13',
        ProfileRightAxisMetric.surfaceGf: '13',
        ProfileRightAxisMetric.meanDepth: '13',
        ProfileRightAxisMetric.tts: '0',
        ProfileRightAxisMetric.gtr: '0',
        ProfileRightAxisMetric.cns: '13',
        ProfileRightAxisMetric.otu: '13',
        ProfileRightAxisMetric.o2CellMv: '13',
      };
      expect(expected.keys, containsAll(ProfileRightAxisMetric.values));
      for (final MapEntry(key: m, value: label) in expected.entries) {
        expect(tick(m, 12.5), label, reason: '$m');
      }
    });

    test('never shows fewer decimals than the metric used to', () {
      expect(tick(ProfileRightAxisMetric.ppO2, 1.2, step: 0.5), '1.2');
      expect(tick(ProfileRightAxisMetric.sac, 1.5, step: 2), '1.5');
    });

    test('adds decimals for finely spaced ticks', () {
      expect(tick(ProfileRightAxisMetric.ppO2, 1.05, step: 0.05), '1.05');
    });

    test('never labels a tick on the zero line "-0"', () {
      expect(tick(ProfileRightAxisMetric.ndl, -1e-13, step: 120), '0');
      expect(tick(ProfileRightAxisMetric.temperature, -0.04, step: 0.3), '0.0');
    });

    test('uses the active locale decimal separator', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);
      Intl.defaultLocale = 'de';
      expect(tick(ProfileRightAxisMetric.temperature, 30.7, step: 0.3), '30,7');
    });

    test('measures the step in display units', () {
      // 5 bar between ticks is about 72.5 psi, so whole psi suffice.
      expect(
        tick(ProfileRightAxisMetric.pressure, 200, step: 5, units: psi),
        '2901',
      );
      // NDL is stored in seconds and labelled in minutes: 30 s is 0.5 min.
      expect(tick(ProfileRightAxisMetric.ndl, 750, step: 30), '12.5');
      expect(tick(ProfileRightAxisMetric.ndl, 750, step: 120), '13');
    });
  });
}
