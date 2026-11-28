import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ascent_rate_axis_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Ascent rate on the right axis (issue #5069): the axis labels the bars'
/// own scale, zero at mid-plot, ascents above and descents below.

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A 30 m dive: down in a minute, then a steady 9 m/min ascent to 3 m and a
/// short stop. Temperature peaks at 3 min, so at the hover point its line
/// sits at the top of the plot and the depth line is the nearest one.
List<DiveProfilePoint> _deepProfile() => [
  for (var t = 0; t <= 420; t += 10)
    DiveProfilePoint(
      timestamp: t,
      depth: t <= 60 ? t / 2.0 : (30 - 9 * (t - 60) / 60).clamp(3.0, 30.0),
      temperature: 25 - (t - 180).abs() / 30,
    ),
];

/// A 6 m reef dive whose rates never reach the critical threshold.
List<DiveProfilePoint> _gentleProfile() => [
  for (var t = 0; t <= 1800; t += 30)
    DiveProfilePoint(
      timestamp: t,
      depth: t <= 300 ? t / 50.0 : (t >= 1500 ? (1800 - t) / 50.0 : 6.0),
    ),
];

List<AscentRatePoint> _rates(List<DiveProfilePoint> profile) =>
    const AscentRateCalculator().calculateProfileRates(
      profile.map((p) => p.depth).toList(),
      profile.map((p) => p.timestamp).toList(),
    );

Future<void> _pump(
  WidgetTester tester,
  List<DiveProfilePoint> profile, {
  AppSettings settings = const AppSettings(defaultShowAscentRateLine: true),
}) async {
  tester.view.physicalSize = const Size(1200, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            height: 600,
            child: DiveProfileChart(
              profile: profile,
              ascentRates: _rates(profile),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ProfileLegend _legend(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DiveProfileChart)),
).read(profileLegendProvider.notifier);

/// The right axis's tick labels, by label, with each one's vertical centre.
Map<String, double> _rightTicks(WidgetTester tester) => {
  for (final element in find.byType(SideTitleWidget).evaluate())
    if ((element.widget as SideTitleWidget).meta.axisSide == AxisSide.right)
      ((element.widget as SideTitleWidget).child as Text).data!: tester
          .getCenter(find.byWidget(element.widget))
          .dy,
};

/// The ascent-rate axis labels, by label, with each one's vertical centre.
/// They are an overlay at fixed plot fractions, not fl_chart side titles.
Map<String, double> _rateLabels(WidgetTester tester) => {
  for (final element
      in find
          .descendant(
            of: find.byType(AscentRateAxisLabels),
            matching: find.byType(Text),
          )
          .evaluate())
    (element.widget as Text).data!: tester
        .getCenter(find.byWidget(element.widget))
        .dy,
};

double _parse(String label) => double.parse(label.replaceAll('+', ''));

/// Zooms both axes in about the plot centre. At 1x the bars' scale and a
/// depth-band mapping coincide, so the scale tests zoom in first, where only
/// a plot-fraction axis still matches the bars.
Future<void> _zoomIn(WidgetTester tester) async {
  final center = tester.getCenter(find.byType(LineChart).first);
  for (var i = 0; i < 8; i++) {
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -100)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The plot's vertical centre, from the left axis's top and bottom ticks.
double _plotMidY(WidgetTester tester) {
  final ys = [
    for (final element in find.byType(SideTitleWidget).evaluate())
      if ((element.widget as SideTitleWidget).meta.axisSide == AxisSide.left)
        tester.getCenter(find.byWidget(element.widget)).dy,
  ]..sort();
  return (ys.first + ys.last) / 2;
}

void main() {
  testWidgets('the axis menu offers Ascent Rate when the dive has rates', (
    tester,
  ) async {
    await _pump(tester, _deepProfile());
    final topRight = tester.getTopRight(find.byType(LineChart).first);
    await tester.tapAt(topRight + const Offset(-20, 80));
    await tester.pumpAndSettle();

    expect(find.text('Ascent Rate'), findsWidgets);
  });

  testWidgets('the ascent-rate axis reads 0 at mid-plot, + above, - below', (
    tester,
  ) async {
    await _pump(tester, _deepProfile());
    _legend(tester).setRightAxisMetric(ProfileRightAxisMetric.ascentRate);
    await tester.pumpAndSettle();

    final ticks = _rateLabels(tester);
    expect(ticks.keys, contains('0'));
    final mid = _plotMidY(tester);
    expect(ticks['0'], closeTo(mid, 2));
    for (final MapEntry(key: label, value: y) in ticks.entries) {
      if (y < mid - 2) expect(label, startsWith('+'), reason: label);
      if (y > mid + 2) expect(label, startsWith('-'), reason: label);
    }
  });

  testWidgets('after a both-axes zoom and a depth pan, 0 stays on the bars '
      'baseline', (tester) async {
    await _pump(tester, _deepProfile());
    _legend(tester).setRightAxisMetric(ProfileRightAxisMetric.ascentRate);
    await tester.pumpAndSettle();
    final unzoomed = _rateLabels(tester);
    await _zoomIn(tester);
    final drag = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await drag.down(tester.getCenter(find.byType(LineChart).first));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(0, 23));
      await tester.pump();
    }
    await drag.up();
    await tester.pumpAndSettle();

    // The same five labels in the same places as at 1x: the scale is the
    // bars', fixed to the plot, whatever depth window is showing.
    final labels = _rateLabels(tester);
    expect(labels.keys, unzoomed.keys);
    for (final MapEntry(key: label, value: y) in labels.entries) {
      expect(y, closeTo(unzoomed[label]!, 0.5), reason: label);
    }
  });

  testWidgets('zoomed in, gentle dive labels still use the floor span', (
    tester,
  ) async {
    await _pump(tester, _gentleProfile());
    _legend(tester).setRightAxisMetric(ProfileRightAxisMetric.ascentRate);
    await tester.pumpAndSettle();
    await _zoomIn(tester);

    final values = _rateLabels(tester).keys.map(_parse).toList();
    for (final v in values) {
      expect(v.isFinite, isTrue);
    }
    const floor = AscentRateCalculator.defaultCriticalThreshold * 1.25;
    expect(values.reduce((a, b) => a > b ? a : b), closeTo(floor, 0.5));
    expect(values.reduce((a, b) => a < b ? a : b), closeTo(-floor, 0.5));
  });

  testWidgets('zoomed in, labels in feet per minute for an imperial diver', (
    tester,
  ) async {
    await _pump(
      tester,
      _gentleProfile(),
      settings: const AppSettings(
        defaultShowAscentRateLine: true,
        depthUnit: DepthUnit.feet,
      ),
    );
    _legend(tester).setRightAxisMetric(ProfileRightAxisMetric.ascentRate);
    await tester.pumpAndSettle();
    await _zoomIn(tester);

    final top = _rateLabels(
      tester,
    ).keys.map(_parse).reduce((a, b) => a > b ? a : b);
    const floorFeet =
        AscentRateCalculator.defaultCriticalThreshold * 1.25 * 3.28084;
    expect(top, closeTo(floorFeet, 1));
  });

  group('hovering the ascent-rate bars', () {
    Future<TestGesture> hoverOverAscentBar(WidgetTester tester) async {
      // At 3 min the diver is ascending at 9 m/min: a tall bar rises from
      // mid-plot. Hover a little above the middle, on that bar.
      final chart = tester.getRect(find.byType(LineChart).first);
      final mid = _plotMidY(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      // Two moves, as a real pointer sends: the chart reads the cursor from
      // the previous event when it resolves the touch.
      final target = Offset(chart.left + chart.width * 0.43, mid - 40);
      await mouse.moveTo(target - const Offset(4, 0));
      await tester.pump();
      await mouse.moveTo(target);
      await tester.pumpAndSettle();
      return mouse;
    }

    testWidgets('switches the axis to ascent rate', (tester) async {
      await _pump(tester, _deepProfile());
      expect(find.textContaining('°C'), findsWidgets);

      await hoverOverAscentBar(tester);

      expect(_rateLabels(tester).keys, contains('0'));
      expect(
        _rateLabels(tester).keys.where((k) => k.startsWith('+')),
        isNotEmpty,
      );
    });

    testWidgets('does not bring back an axis the diver hid', (tester) async {
      await _pump(tester, _deepProfile());
      _legend(tester).hideRightAxis();
      await tester.pumpAndSettle();

      await hoverOverAscentBar(tester);

      expect(_rightTicks(tester), isEmpty);
      expect(_rateLabels(tester), isEmpty);
    });
  });
}
