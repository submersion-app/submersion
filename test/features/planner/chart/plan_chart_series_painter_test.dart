import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_series_painter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_stop_tags.dart';

import 'chart_fixtures.dart';

void main() {
  final palette = PlanChartPalette.of(
    ThemeData(colorScheme: const ColorScheme.dark()),
  );
  const geometry = PlanChartGeometry(
    size: Size(500, 400),
    maxTimeSeconds: 3100,
    maxDepthMeters: 45,
    depthUnitScale: 1,
  );

  String metres(double m) => '${m.round()}m';

  PlanChartSeriesPainter painter({
    bool withGhost = false,
    List<PlanStopTag>? stopTags,
    TextStyle labelStyle = const TextStyle(fontSize: 10),
    TextStyle tagStyle = const TextStyle(fontSize: 9),
    TextDirection textDirection = TextDirection.ltr,
  }) => PlanChartSeriesPainter(
    geometry: geometry,
    palette: palette,
    series: decoSeries(),
    ghost: withGhost ? ndlSeries() : null,
    stopTags:
        stopTags ?? planStopTags(series: decoSeries(), formatDepth: metres),
    meanDepthLabel: 'mean 32m',
    labelStyle: labelStyle,
    tagStyle: tagStyle,
    textDirection: textDirection,
  );

  test('paints deco plan with ghost, tags, and flags without throwing', () {
    final recorder = ui.PictureRecorder();
    painter(withGhost: true).paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints a dense 15-stop schedule without throwing', () {
    final dense = denseDecoSeries();
    final p = PlanChartSeriesPainter(
      geometry: PlanChartGeometry(
        size: const Size(500, 400),
        maxTimeSeconds: dense.maxTimeSeconds,
        maxDepthMeters: dense.maxDepth,
        depthUnitScale: 1,
      ),
      palette: palette,
      series: dense,
      ghost: null,
      stopTags: planStopTags(series: dense, formatDepth: metres),
      meanDepthLabel: 'mean 40m',
      labelStyle: const TextStyle(fontSize: 10),
      tagStyle: const TextStyle(fontSize: 9),
      textDirection: TextDirection.ltr,
    );
    final recorder = ui.PictureRecorder();
    p.paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('paints preview tags with change pills and new stops', () {
    final series = decoSeries();
    final first = series.stopLabels.first;
    final tags = [
      PlanStopTag(marker: first, label: "21m 1'", isNew: true),
      for (final m in series.stopLabels.skip(1))
        PlanStopTag(marker: m, label: "${m.depth.round()}m", change: '+3'),
    ];
    final recorder = ui.PictureRecorder();
    painter(
      withGhost: true,
      stopTags: tags,
    ).paint(Canvas(recorder), const Size(500, 400));
    expect(recorder.endRecording(), isNotNull);
  });

  test('the change pill follows its tag in reading order', () {
    const box = Rect.fromLTWH(100, 50, 60, 16);
    final ltr = stopTagPillRects(
      box: box,
      mainWidth: 37,
      changeWidth: 20,
      gap: 3,
      textDirection: TextDirection.ltr,
    );
    expect(ltr.main, const Rect.fromLTWH(100, 50, 37, 16));
    expect(ltr.change, const Rect.fromLTWH(140, 50, 20, 16));

    final rtl = stopTagPillRects(
      box: box,
      mainWidth: 37,
      changeWidth: 20,
      gap: 3,
      textDirection: TextDirection.rtl,
    );
    expect(rtl.change, const Rect.fromLTWH(100, 50, 20, 16));
    expect(rtl.main, const Rect.fromLTWH(123, 50, 37, 16));

    final plain = stopTagPillRects(
      box: box,
      mainWidth: 37,
      changeWidth: null,
      gap: 3,
      textDirection: TextDirection.rtl,
    );
    expect(plain.main, const Rect.fromLTWH(100, 50, 37, 16));
    expect(plain.change, isNull);
  });

  test('shouldRepaint when a tag gains a change', () {
    final series = decoSeries();
    final changed = [
      for (final m in series.stopLabels)
        PlanStopTag(marker: m, label: 'x', change: '+1'),
    ];
    final plain = [
      for (final m in series.stopLabels) PlanStopTag(marker: m, label: 'x'),
    ];
    expect(
      painter(stopTags: changed).shouldRepaint(painter(stopTags: plain)),
      isTrue,
    );
  });

  test('shouldRepaint when the ghost appears', () {
    expect(painter(withGhost: true).shouldRepaint(painter()), isTrue);
    expect(painter().shouldRepaint(painter()), isFalse);
  });

  test('shouldRepaint on labelStyle / tagStyle change (typography/theme)', () {
    expect(
      painter(
        labelStyle: const TextStyle(fontSize: 14),
      ).shouldRepaint(painter()),
      isTrue,
    );
    expect(
      painter(tagStyle: const TextStyle(fontSize: 12)).shouldRepaint(painter()),
      isTrue,
    );
  });

  test('shouldRepaint on textDirection change (LTR <-> RTL)', () {
    expect(
      painter(textDirection: TextDirection.rtl).shouldRepaint(painter()),
      isTrue,
    );
  });
}
