import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> _lab(Color c) {
  final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double _deltaE(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('has 26 distinct swatches, more than there are metrics', () {
    final argb = profileMetricSwatches.map((c) => c.toARGB32()).toSet();
    expect(argb, hasLength(26));
    expect(argb.length, greaterThan(ProfileMetric.values.length));
  });

  test('holds every fixed metric default, so the defaults are one '
      'arrangement of the palette', () {
    final argb = profileMetricSwatches.map((c) => c.toARGB32()).toSet();
    for (final metric in ProfileMetric.values) {
      final d = metric.defaultColor;
      if (d == null) continue;
      expect(argb, contains(d.toARGB32()), reason: metric.name);
    }
  });

  test('no two swatches are closer than CIE76 deltaE 10', () {
    for (var i = 0; i < profileMetricSwatches.length; i++) {
      for (var j = i + 1; j < profileMetricSwatches.length; j++) {
        final a = profileMetricSwatches[i], b = profileMetricSwatches[j];
        expect(
          _deltaE(a, b),
          greaterThanOrEqualTo(10),
          reason:
              '#${a.toARGB32().toRadixString(16)} vs '
              '#${b.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('every swatch reads at least 1.5:1 on light and dark charts', () {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF121212);
    for (final c in profileMetricSwatches) {
      final hex = c.toARGB32().toRadixString(16);
      expect(_contrast(c, light), greaterThanOrEqualTo(1.5), reason: hex);
      expect(_contrast(c, dark), greaterThanOrEqualTo(1.5), reason: hex);
    }
  });

  test('settingsKey names the column the way Drift does', () {
    expect(ProfileMetric.depth.settingsKey, 'profileColorDepth');
    expect(ProfileMetric.ppO2.settingsKey, 'profileColorPpO2');
    expect(ProfileMetric.surfaceGf.settingsKey, 'profileColorSurfaceGf');
  });
}
