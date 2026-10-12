import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

const _tertiary = Color(0xFF7D5260);
const _purpleA200 = Color(0xFFE040FB);

ProfileMetricPalette _palette([
  ProfileMetricColorOverrides o = ProfileMetricColorOverrides.none,
]) => ProfileMetricPalette(overrides: o, temperatureAuto: _tertiary);

void main() {
  test('defaults reproduce today\'s colours', () {
    final p = _palette();
    expect(p.colorOf(ProfileMetric.depth), ProfileMetricColors.depth);
    expect(p.colorOf(ProfileMetric.ppO2), ProfileMetricColors.ppO2);
    expect(p.colorOf(ProfileMetric.temperature), _tertiary);
    expect(p.colorOf(ProfileMetric.pressure), ProfileMetricColors.pressure);
    expect(p.pressureOverride, isNull);
  });

  test('a chosen colour wins, and a chosen pressure is exposed', () {
    final p = _palette(
      ProfileMetricColorOverrides.none
          .withColor(ProfileMetric.ppO2, _purpleA200)
          .withColor(ProfileMetric.pressure, ProfileMetricColors.events),
    );
    expect(p.colorOf(ProfileMetric.ppO2), _purpleA200);
    expect(p.pressureOverride, ProfileMetricColors.events);
    expect(p.colorOf(ProfileMetric.pressure), ProfileMetricColors.events);
  });

  test('renders a clash deduped', () {
    final p = _palette(
      ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _purpleA200.toARGB32(),
        ProfileMetric.ppN2: _purpleA200.toARGB32(),
      }),
    );
    expect(p.colorOf(ProfileMetric.ppO2), isNot(p.colorOf(ProfileMetric.ppN2)));
  });

  test('isSingleTankDive needs at most one tank and one pressure series', () {
    expect(
      ProfileMetricPalette.isSingleTankDive(pressureSeries: 1, tankCount: 1),
      isTrue,
    );
    expect(
      ProfileMetricPalette.isSingleTankDive(pressureSeries: 1, tankCount: 2),
      isFalse,
    );
    expect(
      ProfileMetricPalette.isSingleTankDive(pressureSeries: 2, tankCount: 0),
      isFalse,
    );
  });

  group('rightAxisColor', () {
    test(
      'NDL follows the chart (Yellow 700), not the old Light Green copy',
      () {
        expect(
          _palette().rightAxisColor(ProfileRightAxisMetric.ndl),
          ProfileMetricColors.ndl,
        );
      },
    );

    test('follows a chosen colour', () {
      final p = _palette(
        ProfileMetricColorOverrides.none.withColor(
          ProfileMetric.ppO2,
          _purpleA200,
        ),
      );
      expect(p.rightAxisColor(ProfileRightAxisMetric.ppO2), _purpleA200);
    });

    test('temperature follows the theme; ascent rate and O2 cells keep '
        'their own colours', () {
      final p = _palette();
      expect(p.rightAxisColor(ProfileRightAxisMetric.temperature), _tertiary);
      expect(
        p.rightAxisColor(ProfileRightAxisMetric.ascentRate),
        ProfileRightAxisMetric.ascentRate.color,
      );
      expect(
        p.rightAxisColor(ProfileRightAxisMetric.o2CellMv),
        ProfileRightAxisMetric.o2CellMv.color,
      );
    });
  });
}
