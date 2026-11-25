import 'package:fl_chart/fl_chart.dart';
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
    expect(captionText(tester, ProfileAxisCaptions.rightKey), 'm');
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
