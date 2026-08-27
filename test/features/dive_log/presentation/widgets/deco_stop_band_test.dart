import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const units = UnitFormatter(AppSettings());

  test('produces a step line chart bar filled to the surface', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [0.0, 3.0, 3.0, 0.0],
      timestamps: [0, 10, 20, 30],
      units: units,
    );

    expect(bar.isStepLineChart, isTrue);

    // The shaded region runs from the stop depth UP to the surface. Depths are
    // negated for the inverted axis, so the surface (y = 0) is above the stop
    // (y = -6) and the fill must be an above-bar area. belowBarData cannot
    // express this: fl_chart's painter erases the whole above-line region after
    // drawing a below-bar fill, so a below-bar fill cut off at y = 0 paints and
    // is then wiped, leaving nothing visible.
    expect(bar.aboveBarData.show, isTrue);
    expect(bar.aboveBarData.applyCutOffY, isTrue);
    expect(bar.aboveBarData.cutOffY, 0);
    expect(bar.belowBarData.show, isFalse);
  });

  test('draws no stroke, only the translucent filled region', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [0.0, 3.0, 3.0, 0.0],
      timestamps: [0, 10, 20, 30],
      units: units,
    );

    // The band is a background zone, not a second curve: no outline along its
    // upper edge, and the fill is translucent so the depth track and the
    // ceiling line stay readable through it.
    expect(bar.barWidth, 0.0);
    expect(bar.color, Colors.transparent);
    expect(bar.dotData.show, isFalse);
    expect(bar.aboveBarData.show, isTrue);
    expect(bar.aboveBarData.color!.a, lessThan(1.0));
    expect(bar.aboveBarData.color!.a, greaterThan(0.0));
  });

  test('negates depth for the inverted Y axis', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [6.0, 6.0],
      timestamps: [0, 10],
      units: units,
    );

    expect(bar.spots.first.y, -6.0);
  });

  test('keeps every step transition after decimation', () {
    // Long flat runs must compress, but the samples at 2, 4 and 6 are where
    // the level changes and must survive so the step edges stay vertical.
    final curve = [0.0, 0.0, 3.0, 3.0, 6.0, 6.0, 0.0, 0.0];
    final timestamps = [0, 10, 20, 30, 40, 50, 60, 70];

    final bar = buildDecoStopBand(
      decoStopCurve: curve,
      timestamps: timestamps,
      units: units,
    );

    final xs = bar.spots.map((s) => s.x).toList();
    expect(xs, [0.0, 20.0, 40.0, 60.0, 70.0]);
  });

  test('an all-zero curve produces no visible band', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [0.0, 0.0, 0.0],
      timestamps: [0, 10, 20],
      units: units,
    );

    expect(bar.spots.every((s) => s.y == 0), isTrue);
  });

  test('an empty curve produces no spots', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [],
      timestamps: [],
      units: units,
    );

    expect(bar.spots, isEmpty);
  });

  test('ignores curve entries beyond the timestamp list', () {
    final bar = buildDecoStopBand(
      decoStopCurve: [3.0, 3.0, 6.0],
      timestamps: [0, 10],
      units: units,
    );

    expect(bar.spots.every((s) => s.x <= 10), isTrue);
  });
}
