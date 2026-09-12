import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Zoomed-in rendering of the profile chart.
///
/// fl_chart only clips at raster time, so it builds a path over every spot it
/// is given. Zoomed in, those paths ran many plot-widths off screen, and the
/// macOS Impeller (MetalSDF) renderer corrupted whole frames while panning.
/// The chart now hands fl_chart only the visible window (see
/// profile_bar_window.dart); these tests pin that down, and pin the touch
/// paths that read fl_chart's spot indices back into the profile.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 600 samples, 5 s apart: a 50-minute dive with a W-shaped profile.
const _sampleSeconds = 5;

List<DiveProfilePoint> _profile() => List.generate(600, (i) {
  final phase = (i % 200) / 200.0;
  return DiveProfilePoint(
    timestamp: i * _sampleSeconds,
    depth: 5 + 25 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2),
    temperature: 20.0 - i * 0.005,
  );
});

Widget _buildChart({void Function(List<TooltipRow>? rows)? onTooltipData}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 500,
          child: DiveProfileChart(
            profile: _profile(),
            tooltipBelow: onTooltipData != null,
            onTooltipData: onTooltipData,
          ),
        ),
      ),
    ),
  );
}

LineChartData _chartData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data;

/// Mouse-wheel zoom anchored at the chart centre: 1.1x per click.
Future<void> _wheelZoomIn(WidgetTester tester, {required int clicks}) async {
  final center = tester.getCenter(find.byType(LineChart).first);
  for (var i = 0; i < clicks; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
    );
    await tester.pump();
  }
}

/// Mouse click-drag pan by [dx] pixels.
Future<void> _dragPan(WidgetTester tester, double dx) async {
  final center = tester.getCenter(find.byType(LineChart).first);
  final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await drag.down(center);
  for (var i = 0; i < 10; i++) {
    await drag.moveBy(Offset(dx / 10, 0));
    await tester.pump();
  }
  await drag.up();
  // A mouse stays attached after the button is released; detach it so a
  // later hover gesture can add the device again.
  await drag.removePointer();
  await tester.pump();
}

/// Hovers the mouse at [position] and returns the external tooltip rows.
Future<List<TooltipRow>?> _hover(
  WidgetTester tester,
  Offset position,
  List<TooltipRow>? Function() rows,
) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: position - const Offset(4, 0));
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(position);
  await tester.pump();
  return rows();
}

int _timeRowSeconds(List<TooltipRow> rows) {
  final parts = rows.first.value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

void _ignoreOverflowErrors() {
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    origOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = origOnError);
}

void main() {
  testWidgets('zoomed in, no series reaches much past the visible window', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    await _wheelZoomIn(tester, clicks: 20); // ~6.7x
    await _dragPan(tester, -150);

    final data = _chartData(tester);
    final width = data.maxX - data.minX;
    expect(width, lessThan(3000 / 5), reason: 'the chart must be zoomed in');

    // Eighth-window snapping widens the window by at most a quarter of a
    // window, plus the two real neighbours kept past each edge.
    final slack = width * 0.25 + 2 * _sampleSeconds;
    for (final bar in data.lineBarsData) {
      final xs = [
        for (final s in bar.spots)
          if (!s.isNull()) s.x,
      ];
      if (xs.length < 2) continue;
      expect(
        xs.first,
        greaterThanOrEqualTo(data.minX - slack),
        reason:
            'a series starting at ${xs.first}s runs far left of the '
            'visible window [${data.minX}, ${data.maxX}]',
      );
      expect(
        xs.last,
        lessThanOrEqualTo(data.maxX + slack),
        reason:
            'a series ending at ${xs.last}s runs far right of the '
            'visible window [${data.minX}, ${data.maxX}]',
      );
    }
  });

  testWidgets('panning keeps the depth fill shading on the same depths', (
    tester,
  ) async {
    // fl_chart stretches the fill gradient from the bar's topmost spot to the
    // chart's minY, so a cut bar needs its gradient remapped; otherwise the
    // shading slides whenever a pan re-cuts the series.
    _ignoreOverflowErrors();
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();
    await _wheelZoomIn(tester, clicks: 20);

    // Data y where the gradient's first colour sits.
    double gradientTopY() {
      final data = _chartData(tester);
      final depth = data.lineBarsData.first;
      final begin =
          (depth.belowBarData.gradient! as LinearGradient).begin as Alignment;
      final top = depth.mostTopSpot.y;
      return top + (begin.y + 1) / 2 * (data.minY - top);
    }

    await _dragPan(tester, -60);
    final before = gradientTopY();
    final cutTopBefore = _chartData(tester).lineBarsData.first.mostTopSpot.y;
    await _dragPan(tester, -200);
    final cutTopAfter = _chartData(tester).lineBarsData.first.mostTopSpot.y;

    expect(
      cutTopAfter,
      isNot(cutTopBefore),
      reason: 'the pan must re-cut the depth series for this to test anything',
    );
    expect(gradientTopY(), closeTo(before, 1e-6));
  });

  testWidgets('unzoomed, every series keeps all of its samples', (
    tester,
  ) async {
    await tester.pumpWidget(_buildChart());
    await tester.pumpAndSettle();

    final depth = _chartData(tester).lineBarsData.first;
    expect(depth.spots.where((s) => !s.isNull()), hasLength(600));
  });

  testWidgets('zoomed in, hovering reads the sample under the cursor', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    List<TooltipRow>? rows;
    await tester.pumpWidget(_buildChart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    await _wheelZoomIn(tester, clicks: 20);
    await _dragPan(tester, -150);

    final data = _chartData(tester);
    final got = await _hover(
      tester,
      tester.getCenter(find.byType(LineChart).first),
      () => rows,
    );

    expect(got, isNotNull);
    final seconds = _timeRowSeconds(got!);
    expect(
      seconds,
      inInclusiveRange(data.minX, data.maxX),
      reason:
          'the readout must describe a sample inside the visible '
          'window, not one offset by the trimmed-off spots',
    );
  });

  testWidgets('a focus marker whose spot index went stale is not drawn', (
    tester,
  ) async {
    _ignoreOverflowErrors();
    List<TooltipRow>? rows;
    await tester.pumpWidget(_buildChart(onTooltipData: (r) => rows = r));
    await tester.pumpAndSettle();

    await _wheelZoomIn(tester, clicks: 20);
    final got = await _hover(
      tester,
      tester.getCenter(find.byType(LineChart).first),
      () => rows,
    );
    expect(got, isNotNull);
    final touchedX = _timeRowSeconds(got!).toDouble();

    final data = _chartData(tester);
    final depth = data.lineBarsData.first;
    final touched = depth.spots.indexWhere((s) => s.x == touchedX);
    expect(touched, isNonNegative);
    final indicator = data.lineTouchData.getTouchedSpotIndicator;

    // fl_chart keeps the touched spot's index across rebuilds. Once the
    // series under it is re-cut (a pan) or re-decimated, that index names a
    // different sample, and drawing it puts the marker at the wrong time.
    expect(indicator(depth, [touched]).single, isNotNull);
    expect(indicator(depth, [touched + 5]).single, isNull);
  });
}
