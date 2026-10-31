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
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.settings = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A desktop-sized chart, as in the screenshots of issue #3055: tall enough
/// that fl_chart lays out ticks finer than a whole degree apart.
Future<void> _pumpChart(
  WidgetTester tester, {
  required List<DiveProfilePoint> profile,
  List<double>? meanDepthCurve,
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(1800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1700,
            height: 900,
            child: DiveProfileChart(
              profile: profile,
              meanDepthCurve: meanDepthCurve,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A dive to 40 m (44 m plot extent) whose mean depth peaks at 22 m, as in
/// issue #3892.
Future<void> _pumpMeanDepthChart(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
}) async {
  await _pumpChart(
    tester,
    profile: List.generate(
      41,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i <= 20 ? i * 2.0 : (40 - i) * 2.0,
      ),
    ),
    meanDepthCurve: List.generate(41, (i) => i * 0.55),
    settings: settings,
  );
  ProviderScope.containerOf(tester.element(find.byType(DiveProfileChart)))
      .read(profileLegendProvider.notifier)
      .setRightAxisMetric(ProfileRightAxisMetric.meanDepth);
  await tester.pumpAndSettle();
}

/// The tick labels fl_chart laid out on [side], each with its y position.
Map<String, double> _axisTicks(WidgetTester tester, AxisSide side) => {
  for (final element in find.byType(SideTitleWidget).evaluate())
    if ((element.widget as SideTitleWidget).meta.axisSide == side)
      ((element.widget as SideTitleWidget).child as Text).data!: tester
          .getCenter(find.byWidget(element.widget))
          .dy,
};

/// Each right-axis tick reads the same depth, on the same grid line, as the
/// left depth axis.
void _expectRightAxisMatchesDepthAxis(WidgetTester tester) {
  final left = _axisTicks(tester, AxisSide.left);
  final right = _axisTicks(tester, AxisSide.right);
  expect(left.length, greaterThan(2));
  expect(right.keys, left.keys);
  for (final MapEntry(key: label, value: y) in right.entries) {
    expect(y, closeTo(left[label]!, 1), reason: 'tick $label');
  }
}

void main() {
  // Issue #3055: the right axis labels the depth grid's ticks with the
  // metric's value there. A 3 C temperature range across a 20 m dive used
  // to print 31, 31, 31, 30, 30 ... at whole degrees.
  testWidgets('right-axis temperature ticks carry distinct labels', (
    tester,
  ) async {
    final profile = List.generate(
      41,
      (i) => DiveProfilePoint(
        timestamp: i * 30,
        depth: i <= 20 ? i * 1.0 : (40 - i) * 1.0,
        temperature: 29.0 + (i % 3),
      ),
    );
    await _pumpChart(tester, profile: profile);

    // The labels fl_chart actually laid out on the right axis, at the tick
    // interval it chose itself (the right axis sets none).
    final labels = [
      for (final title in tester.widgetList<SideTitleWidget>(
        find.byType(SideTitleWidget),
      ))
        if (title.meta.axisSide == AxisSide.right) (title.child as Text).data!,
    ];

    expect(labels.length, greaterThan(3));
    expect(labels.toSet().length, labels.length, reason: '$labels');
  });

  // Issue #3892: the mean-depth line sits at its real depth, but the right
  // axis stretched 0..max * 1.1 across the plot, upside down: 22 m read 12.1
  // and the surface read 24.2.
  group('mean-depth right axis follows the plotted depth scale', () {
    testWidgets('reads the same depths as the left axis', (tester) async {
      await _pumpMeanDepthChart(tester);

      _expectRightAxisMatchesDepthAxis(tester);
      final right = _axisTicks(tester, AxisSide.right);
      expect(right.keys, containsAll(['0', '20', '40']));
      expect(right['0'], lessThan(right['40']!));
    });

    testWidgets('reads the diver\'s depth unit', (tester) async {
      await _pumpMeanDepthChart(
        tester,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );

      _expectRightAxisMatchesDepthAxis(tester);
      expect(_axisTicks(tester, AxisSide.right).keys, contains('100'));
    });

    testWidgets('keeps reading true depths when zoomed', (tester) async {
      await _pumpMeanDepthChart(tester);

      final center = tester.getCenter(find.byType(LineChart).first);
      for (var i = 0; i < 12; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: center,
            scrollDelta: const Offset(0, -100),
          ),
        );
        await tester.pump();
      }

      expect(_axisTicks(tester, AxisSide.left).keys, isNot(contains('0')));
      _expectRightAxisMatchesDepthAxis(tester);
    });
  });
}
