import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../../helpers/mock_providers.dart';

/// Range-statistics handles must sit on the chart's plot rect: at 0:00 the
/// start handle belongs on the depth axis, not left of it (issue #1579).
void main() {
  const chartWidth = 400.0;
  const maxSeconds = 570; // 20 samples, 30 s apart

  final profile = List.generate(
    20,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 10 ? i * 3.0 : (20 - i) * 3.0,
    ),
  );

  const gasSegments = [
    GasUsageSegment(
      startSeconds: 0,
      endSeconds: maxSeconds,
      gasMix: GasMix(o2: 21),
      label: 'Air',
    ),
  ];

  Future<void> pumpChart(
    WidgetTester tester, {
    int startSeconds = 0,
    int endSeconds = maxSeconds,
    bool rangeMode = true,
    bool gasStrip = false,
    void Function(int start, int end)? onRangeChanged,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              // The gas strip is the alignment oracle: it is positioned by
              // the same plot rect as the range handles.
              const AppSettings(defaultShowGasTimeline: true),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: chartWidth,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                gasSegments: gasStrip ? gasSegments : null,
                diveDurationSeconds: gasStrip ? maxSeconds : null,
                rangeSelection: rangeMode
                    ? (
                        startSeconds: startSeconds,
                        endSeconds: endSeconds,
                        maxSeconds: maxSeconds,
                      )
                    : null,
                onRangeChanged: onRangeChanged,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  LineChartData chartData(WidgetTester tester) =>
      tester.widget<LineChart>(find.byType(LineChart).first).data;

  double handleX(WidgetTester tester, Key key) =>
      tester.getCenter(find.byKey(key)).dx;

  /// Mouse-wheel zoom in at the chart center, as in the gesture tests.
  Future<void> wheelZoomIn(WidgetTester tester, {int clicks = 4}) async {
    final center = tester.getCenter(find.byType(LineChart).first);
    for (var i = 0; i < clicks; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pump();
    }
  }

  testWidgets('range mode off renders no handles', (tester) async {
    await pumpChart(tester, rangeMode: false);
    expect(find.byType(RangeSelectionOverlay), findsNothing);
  });

  testWidgets('0:00 lands on the depth axis, not left of the plot area', (
    tester,
  ) async {
    await pumpChart(tester);

    // fl_chart reserves the axis-name band (16, its default axisNameSize)
    // plus the tick gutter for the left axis; the plot rect starts there.
    const plotLeft = 16 + 32.0;
    expect(DiveProfileChart.leftAxisSize(chartWidth), 32);
    expect(
      handleX(tester, RangeSelectionOverlay.startHandleKey),
      closeTo(plotLeft, 0.5),
    );
    // The old placement (tick gutter + 5) sat 11 px inside the axis labels.
    expect(
      handleX(tester, RangeSelectionOverlay.startHandleKey),
      greaterThan(DiveProfileChart.leftAxisSize(chartWidth) + 5),
    );
  });

  testWidgets('handles align with the gas timeline strip, layer to layer', (
    tester,
  ) async {
    await pumpChart(tester, gasStrip: true);

    final strip = tester.getRect(find.byType(GasTimelineStrip));
    expect(
      handleX(tester, RangeSelectionOverlay.startHandleKey),
      closeTo(strip.left, 0.5),
    );
    expect(
      handleX(tester, RangeSelectionOverlay.endHandleKey),
      closeTo(strip.right, 0.5),
    );
  });

  testWidgets('handles track the visible window when the chart is zoomed', (
    tester,
  ) async {
    await pumpChart(tester, gasStrip: true, startSeconds: 240, endSeconds: 330);
    final before = handleX(tester, RangeSelectionOverlay.startHandleKey);

    await wheelZoomIn(tester);
    await tester.pumpAndSettle();

    final data = chartData(tester);
    expect(data.maxX - data.minX, lessThan(maxSeconds), reason: 'zoom applied');

    final strip = tester.getRect(find.byType(GasTimelineStrip));
    final expected =
        strip.left +
        ((240 - data.minX) / (data.maxX - data.minX)) * strip.width;
    expect(
      handleX(tester, RangeSelectionOverlay.startHandleKey),
      closeTo(expected, 0.5),
    );
    expect(
      handleX(tester, RangeSelectionOverlay.startHandleKey),
      isNot(closeTo(before, 1)),
      reason: 'a zoom must move the handle with the trace under it',
    );
  });

  testWidgets('dragging a handle reports seconds without panning the chart', (
    tester,
  ) async {
    final changes = <(int, int)>[];
    await pumpChart(
      tester,
      gasStrip: true,
      startSeconds: 120,
      endSeconds: 450,
      onRangeChanged: (start, end) => changes.add((start, end)),
    );
    final minXBefore = chartData(tester).minX;
    final strip = tester.getRect(find.byType(GasTimelineStrip));

    // A mouse drag on the chart pans it; on a handle it must not.
    await tester.drag(
      find.byKey(RangeSelectionOverlay.startHandleKey),
      Offset(strip.width / 4, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(changes, isNotEmpty);
    expect(changes.last.$1, closeTo(120 + maxSeconds / 4, 2));
    expect(changes.last.$2, 450);
    expect(
      chartData(tester).minX,
      minXBefore,
      reason: 'the chart must not pan',
    );
  });
}
