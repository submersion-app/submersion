import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_plot_frame.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The chart publishes where its plot sits and what it spans, so the pinned
/// strip can start its condense exactly on the chart's depth line (#4423).
void main() {
  final profile = [
    for (var t = 0; t <= 1800; t += 30)
      DiveProfilePoint(
        timestamp: t,
        depth: t < 120 ? t / 4 : (t > 1680 ? (1800 - t) / 4 : 30),
      ),
  ];

  Future<List<ProfilePlotFrame>> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    ValueNotifier<double>? width,
    ValueNotifier<ChartViewport?>? viewport,
    ValueChanged<ChartViewport>? onViewportChanged,
  }) async {
    final frames = <ProfilePlotFrame>[];
    final w = width ?? ValueNotifier(400.0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(settings),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ValueListenableBuilder<double>(
                valueListenable: w,
                builder: (context, value, _) =>
                    ValueListenableBuilder<ChartViewport?>(
                      valueListenable: viewport ?? ValueNotifier(null),
                      builder: (context, window, _) => SizedBox(
                        width: value,
                        height: 300,
                        child: DiveProfileChart(
                          profile: profile,
                          onPlotFrame: frames.add,
                          viewport: window,
                          onViewportChanged: onViewportChanged,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return frames;
  }

  testWidgets('reports the visible time and depth ranges', (tester) async {
    final frames = await pump(tester);
    expect(frames, isNotEmpty);
    final frame = frames.last;
    expect(frame.minSeconds, lessThanOrEqualTo(0));
    expect(frame.maxSeconds, greaterThanOrEqualTo(1800));
    expect(frame.minDepthMeters, 0);
    expect(frame.maxDepthMeters, inInclusiveRange(30, 40));
  });

  testWidgets('its key marks a box over the plot, inside the chart', (
    tester,
  ) async {
    final frame = (await pump(tester)).last;
    final plot = frame.plotKey.currentContext!.findRenderObject()! as RenderBox;
    final plotRect = plot.localToGlobal(Offset.zero) & plot.size;
    final chartRect = tester.getRect(find.byType(DiveProfileChart));
    expect(chartRect.contains(plotRect.topLeft), isTrue);
    expect(
      chartRect.contains(plotRect.bottomRight - const Offset(1, 1)),
      isTrue,
    );
    expect(plotRect.width, greaterThan(chartRect.width / 2));
    expect(plotRect.height, greaterThan(chartRect.height / 3));
  });

  testWidgets('reports depth in meters whatever the diver\'s unit', (
    tester,
  ) async {
    final frame = (await pump(
      tester,
      settings: const AppSettings(depthUnit: DepthUnit.feet),
    )).last;
    expect(frame.maxDepthMeters, inInclusiveRange(30, 40));
  });

  // A wider chart moves and stretches the plot without changing the ranges;
  // the strip must learn the new plot rect (review I2).
  testWidgets('reports again when the plot moves but its ranges do not', (
    tester,
  ) async {
    final width = ValueNotifier(400.0);
    final frames = await pump(tester, width: width);
    final first = frames.last;
    width.value = 700;
    await tester.pump();
    await tester.pump();
    expect(frames.last, isNot(first));
    expect(frames.last.plotRect.width, greaterThan(first.plotRect.width));
    expect(frames.last.maxSeconds, first.maxSeconds);
  });

  testWidgets('does not report again while nothing changes', (tester) async {
    final frames = await pump(tester);
    final count = frames.length;
    await tester.pump(const Duration(milliseconds: 300));
    expect(frames.length, count);
  });

  testWidgets('the frame says which window the plot was drawn with', (
    tester,
  ) async {
    final frame = (await pump(tester)).last;
    expect(frame.viewport.sameWindowAs(ChartViewport.reset), isTrue);
  });

  // The pinned copy of the card is given its window from outside, so it
  // can zoom out from the full card's as the page scrolls (#4423).
  group('a window given from outside', () {
    testWidgets('is the one the plot shows', (tester) async {
      final full = (await pump(tester)).last;
      final window = ValueNotifier<ChartViewport?>(
        const ChartViewport(zoom: 2, offsetX: 0.25),
      );
      final frames = await pump(tester, viewport: window);
      final zoomed = frames.last;
      final span = full.maxSeconds - full.minSeconds;
      expect(zoomed.minSeconds, closeTo(full.minSeconds + span / 4, 1e-6));
      expect(zoomed.maxSeconds, closeTo(full.minSeconds + span * 3 / 4, 1e-6));
      expect(zoomed.viewport.zoom, 2);

      window.value = ChartViewport.reset;
      await tester.pump();
      await tester.pump();
      expect(frames.last.minSeconds, full.minSeconds);
      expect(frames.last.maxSeconds, full.maxSeconds);
    });
  });

  testWidgets('reports its window when the reader zooms', (tester) async {
    final windows = <ChartViewport>[];
    await pump(tester, onViewportChanged: windows.add);
    expect(windows, isEmpty);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(windows, isNotEmpty);
    expect(windows.last.zoom, greaterThan(1));
  });
}
