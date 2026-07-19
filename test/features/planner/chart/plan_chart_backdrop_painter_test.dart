import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_backdrop_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';

import 'chart_fixtures.dart';

void main() {
  final palette = PlanChartPalette.of(
    ThemeData(colorScheme: const ColorScheme.dark()),
  );
  PlanChartBackdropPainter painter({
    PlanChartGeometry? geometry,
    TextStyle labelStyle = const TextStyle(fontSize: 10),
    TextDirection textDirection = TextDirection.ltr,
  }) => PlanChartBackdropPainter(
    geometry:
        geometry ??
        const PlanChartGeometry(
          size: Size(500, 400),
          maxTimeSeconds: 3100,
          maxDepthMeters: 45,
          depthUnitScale: 1,
        ),
    palette: palette,
    ceiling: decoSeries().ceiling,
    depthUnitScale: 1,
    depthAxisLabel: 'm',
    timeAxisLabel: 'min',
    labelStyle: labelStyle,
    textDirection: textDirection,
  );

  test('paints without throwing on a real canvas', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter().paint(canvas, const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints an empty ceiling without throwing', () {
    final recorder = ui.PictureRecorder();
    final p = PlanChartBackdropPainter(
      geometry: const PlanChartGeometry(
        size: Size(500, 400),
        maxTimeSeconds: 1500,
        maxDepthMeters: 30,
        depthUnitScale: 1,
      ),
      palette: palette,
      ceiling: const [],
      depthUnitScale: 1,
      depthAxisLabel: 'm',
      timeAxisLabel: 'min',
      labelStyle: const TextStyle(fontSize: 10),
      textDirection: TextDirection.ltr,
    );
    p.paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('shouldRepaint only when inputs change', () {
    final a = painter();
    final b = painter();
    expect(a.shouldRepaint(b), isFalse);
    final moved = painter(
      geometry: const PlanChartGeometry(
        size: Size(500, 400),
        maxTimeSeconds: 9999,
        maxDepthMeters: 45,
        depthUnitScale: 1,
      ),
    );
    expect(moved.shouldRepaint(a), isTrue);
  });

  test('shouldRepaint on labelStyle change (typography/theme)', () {
    final a = painter();
    final restyled = painter(labelStyle: const TextStyle(fontSize: 14));
    expect(restyled.shouldRepaint(a), isTrue);
  });

  test('shouldRepaint on textDirection change (LTR <-> RTL)', () {
    final a = painter();
    final rtl = painter(textDirection: TextDirection.rtl);
    expect(rtl.shouldRepaint(a), isTrue);
  });
}
