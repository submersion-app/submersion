import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_axis_captions.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.settings = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
);

List<DiveProfilePoint> _profile({bool temperature = true}) => List.generate(
  41,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i <= 20 ? i * 1.5 : (40 - i) * 1.5,
    temperature: temperature ? 24 - i * 0.05 : null,
  ),
);

/// The rotated axis titles gave way to unit captions above the tick columns,
/// so the plot gets the width the titles' 16 px strips took (issue #5013).
void main() {
  Future<void> pumpChart(
    WidgetTester tester, {
    double width = 400,
    AppSettings settings = const AppSettings(),
    bool temperature = true,
    ProfileRightAxisMetric? rightAxis = ProfileRightAxisMetric.temperature,
    TextDirection textDirection = TextDirection.ltr,
    void Function(int seconds, double? depth)? onAnnotationPlaced,
  }) async {
    tester.view.physicalSize = Size(width + 100, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(settings),
          ),
        ],
        child: MaterialApp(
          // The captions and tick labels asserted here are the English ones.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Directionality(
                  textDirection: textDirection,
                  child: DiveProfileChart(
                    profile: _profile(temperature: temperature),
                    meanDepthCurve: List.generate(41, (i) => i * 0.4),
                    annotationPlacement: onAnnotationPlaced != null,
                    onAnnotationPlaced: onAnnotationPlaced,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (rightAxis != null) {
      ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart)),
      ).read(profileLegendProvider.notifier).setRightAxisMetric(rightAxis);
      await tester.pumpAndSettle();
    }
  }

  String captionText(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  Text rightTick(WidgetTester tester) => find
      .byType(SideTitleWidget)
      .evaluate()
      .map((e) => e.widget as SideTitleWidget)
      .where((w) => w.meta.axisSide == AxisSide.right)
      .map((w) => w.child)
      .whereType<Text>()
      .first;

  testWidgets('left caption shows the depth unit', (tester) async {
    await pumpChart(tester);
    expect(captionText(tester, ProfileAxisCaptions.leftKey), 'm');
  });

  testWidgets('left caption follows imperial depth', (tester) async {
    await pumpChart(tester, settings: _imperial);
    expect(captionText(tester, ProfileAxisCaptions.leftKey), 'ft');
  });

  testWidgets('right caption shows the right axis unit in its colour', (
    tester,
  ) async {
    await pumpChart(tester);
    expect(captionText(tester, ProfileAxisCaptions.rightKey), '°C');
    final caption = tester.widget<Text>(
      find.byKey(ProfileAxisCaptions.rightKey),
    );
    expect(caption.style?.color, rightTick(tester).style?.color);
  });

  testWidgets('right caption follows the right axis metric', (tester) async {
    await pumpChart(tester);
    ProviderScope.containerOf(tester.element(find.byType(DiveProfileChart)))
        .read(profileLegendProvider.notifier)
        .setRightAxisMetric(ProfileRightAxisMetric.meanDepth);
    await tester.pumpAndSettle();
    expect(captionText(tester, ProfileAxisCaptions.rightKey), 'Mean m');
  });

  testWidgets('right caption follows the right axis as hover switches it', (
    tester,
  ) async {
    // Hovering a tagged line switches the right axis to that line's metric
    // for the hover alone, repainting the plot only (issue #2228 follow-up);
    // the caption has to switch with it. The axis shows temperature; the mean
    // depth line is drawn too, and the pointer sits right on it.
    await pumpChart(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(DiveProfileChart)),
    ).read(profileLegendProvider.notifier).toggleMeanDepth();
    await tester.pumpAndSettle();
    expect(captionText(tester, ProfileAxisCaptions.rightKey), '°C');

    // Half way through the dive the mean depth is 8 m (the depth line is at
    // 30 m), on an axis padded to 33 m. The first move over the plot is
    // fl_chart's enter event; the second hovers.
    final chart = tester.getRect(find.byType(LineChart).first);
    final plotTop = chart.top + 1;
    final plotBottom = chart.bottom - (14 + 22 + 1);
    final y = plotTop + 8 / 33 * (plotBottom - plotTop);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: chart.centerLeft + const Offset(-5, 0));
    addTearDown(mouse.removePointer);
    for (final dy in [-1.0, 0.0]) {
      await mouse.moveTo(Offset(chart.center.dx, y + dy));
      await tester.pump();
    }

    // The axis itself switched to the depth scale mean depth reads on...
    expect(
      find
          .byType(SideTitleWidget)
          .evaluate()
          .map((e) => e.widget as SideTitleWidget)
          .where((w) => w.meta.axisSide == AxisSide.right)
          .map((w) => (w.child as Text).data),
      contains('20'),
    );
    // ...and the caption with it.
    expect(captionText(tester, ProfileAxisCaptions.rightKey), 'Mean m');
  });

  testWidgets('tapping the right caption opens the right axis menu', (
    tester,
  ) async {
    await pumpChart(tester);
    expect(find.byType(PopupMenuItem<ProfileRightAxisMetric?>), findsNothing);
    await tester.tap(find.byKey(ProfileAxisCaptions.rightKey));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<ProfileRightAxisMetric?>), findsWidgets);
  });

  testWidgets('right caption follows imperial temperature', (tester) async {
    await pumpChart(tester, settings: _imperial);
    expect(captionText(tester, ProfileAxisCaptions.rightKey), '°F');
  });

  testWidgets('no right caption without a right axis metric', (tester) async {
    await pumpChart(tester, temperature: false, rightAxis: null);
    expect(find.byKey(ProfileAxisCaptions.leftKey), findsOneWidget);
    expect(find.byKey(ProfileAxisCaptions.rightKey), findsNothing);
  });

  testWidgets('the rotated axis titles are gone', (tester) async {
    await pumpChart(tester);
    expect(find.text('Depth (m)'), findsNothing);
    expect(find.text('Temp (°C)'), findsNothing);
  });

  testWidgets('captions sit over their tick columns', (tester) async {
    await pumpChart(tester);
    final chart = tester.getRect(find.byType(DiveProfileChart));
    final left = tester.getRect(find.byKey(ProfileAxisCaptions.leftKey));
    final right = tester.getRect(find.byKey(ProfileAxisCaptions.rightKey));
    expect(left.left, closeTo(chart.left, 0.5));
    expect(right.right, closeTo(chart.right, 0.5));
    final plot = tester.getRect(find.byType(LineChart).first);
    expect(left.bottom, lessThanOrEqualTo(plot.top));
  });

  testWidgets('captions keep their sides in a right-to-left language', (
    tester,
  ) async {
    // fl_chart never mirrors its axes, so neither may their captions.
    await pumpChart(tester, textDirection: TextDirection.rtl);
    final chart = tester.getRect(find.byType(DiveProfileChart));
    final left = tester.getRect(find.byKey(ProfileAxisCaptions.leftKey));
    final right = tester.getRect(find.byKey(ProfileAxisCaptions.rightKey));
    expect(left.left, closeTo(chart.left, 0.5));
    expect(right.right, closeTo(chart.right, 0.5));
  });

  testWidgets('a tap in the plot beside the narrower gutter still lands', (
    tester,
  ) async {
    // The right gutter is 39 px now, not the old 50: a tap 45 px from the
    // right edge is on the plot and must place, not count as the axis menu.
    final placed = <int>[];
    await pumpChart(
      tester,
      onAnnotationPlaced: (seconds, _) => placed.add(seconds),
    );
    final chart = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(Offset(chart.right - 45, chart.center.dy));
    await tester.pump();
    expect(placed, hasLength(1));
  });

  test('plot insets drop the axis-name strip', () {
    expect(DiveProfileChart.plotLeftInset(400), 33);
    expect(DiveProfileChart.plotRightInset(400, hasRightAxis: true), 39);
    expect(DiveProfileChart.plotLeftInset(300), 29);
    expect(DiveProfileChart.plotRightInset(300, hasRightAxis: true), 33);
  });

  test('narrow charts close the gap beside the tick labels', () {
    // 3-digit feet and 4-digit psi labels fit the narrow gutters only with
    // the smaller gap (the 28 px gutter clipped "100" to "10").
    expect(DiveProfileChart.tickLabelGap(300), 4);
    expect(DiveProfileChart.tickLabelGap(400), 8);
  });

  testWidgets('tick labels use the narrow gap on a narrow chart', (
    tester,
  ) async {
    await pumpChart(tester, width: 320);
    final gaps = {
      for (final w
          in find
              .byType(SideTitleWidget)
              .evaluate()
              .map((e) => e.widget as SideTitleWidget)
              .where(
                (w) =>
                    w.meta.axisSide == AxisSide.left ||
                    w.meta.axisSide == AxisSide.right,
              ))
        w.space,
    };
    expect(gaps, {4.0});
  });

  testWidgets('right axis tap target stays in the gutter', (tester) async {
    await pumpChart(tester);
    final chart = tester.getRect(find.byType(DiveProfileChart));
    final target = tester.getRect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics && w.properties.label == 'Change right axis metric',
      ),
    );
    expect(
      target.width,
      lessThanOrEqualTo(
        DiveProfileChart.plotRightInset(chart.width, hasRightAxis: true),
      ),
    );
  });
}
