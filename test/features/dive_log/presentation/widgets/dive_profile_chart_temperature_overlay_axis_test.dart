/// Issue #3893: an overlaid computer pools its readings into the temperature
/// scale the lines are drawn on, so the right axis has to label that same
/// scale. These tests read the chart the way a diver does: find a drawn line,
/// then read the value the right axis labels at that height.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A dive whose every sample reads [temperature] (celsius), or none at all.
List<DiveProfilePoint> _profile(double? temperature) => List.generate(
  41,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i <= 20 ? i * 1.0 : (40 - i) * 1.0,
    temperature: temperature,
  ),
);

ChartSourceOverlay _overlay(double temperature) => ChartSourceOverlay(
  sourceId: 'secondary',
  name: 'Secondary',
  color: Colors.purple,
  computerId: 'computer-b',
  points: _profile(temperature),
);

/// Pumps a desktop-sized chart, tall enough for several right-axis ticks.
///
/// [profile] stays one list instance for the chart's lifetime and [overlays]
/// drives every rebuild, as on the dive page, where toggling an overlay leaves
/// the active source's points untouched.
Future<void> _pumpChart(
  WidgetTester tester, {
  required List<DiveProfilePoint> profile,
  required ValueNotifier<List<ChartSourceOverlay>?> overlays,
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
            child: ValueListenableBuilder(
              valueListenable: overlays,
              builder: (context, value, _) =>
                  DiveProfileChart(profile: profile, overlays: value),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The Y of the one flat line of the given style. The fixtures hold every
/// temperature constant, so the only flat multi-point lines are temperature
/// lines: the active source's is solid and an overlay's is dashed.
double _flatLineY(WidgetTester tester, {required bool dashed}) {
  final bars = tester
      .widget<LineChart>(find.byType(LineChart).first)
      .data
      .lineBarsData;
  return bars
      .where(
        (bar) =>
            bar.spots.length > 1 &&
            bar.spots.every((s) => s.y == bar.spots.first.y) &&
            (bar.dashArray != null) == dashed,
      )
      .single
      .spots
      .first
      .y;
}

/// The right-axis ticks fl_chart laid out, as (axis Y, labelled value). A
/// tick's meta gives its pixel position down the axis, not its axis value.
List<({double y, double value})> _rightTicks(WidgetTester tester) => [
  for (final title in tester.widgetList<SideTitleWidget>(
    find.byType(SideTitleWidget),
  ))
    if (title.meta.axisSide == AxisSide.right)
      (
        y:
            title.meta.max -
            title.meta.axisPosition /
                title.meta.parentAxisSize *
                (title.meta.max - title.meta.min),
        value: double.parse((title.child as Text).data!),
      ),
];

/// The value the right axis labels at axis height [y], interpolated between
/// its two outermost ticks, as a diver reads a line against the scale.
double _axisReadingAt(WidgetTester tester, double y) {
  final ticks = _rightTicks(tester)..sort((a, b) => a.y.compareTo(b.y));
  expect(ticks.length, greaterThan(1), reason: 'no scale to read against');
  final (low, high) = (ticks.first, ticks.last);
  return low.value + (y - low.y) * (high.value - low.value) / (high.y - low.y);
}

void main() {
  late ValueNotifier<List<ChartSourceOverlay>?> overlays;

  setUp(() => overlays = ValueNotifier(null));
  tearDown(() => overlays.dispose());

  testWidgets('both computers read true against a range the overlay widened', (
    tester,
  ) async {
    overlays.value = [_overlay(30)];
    await _pumpChart(tester, profile: _profile(20), overlays: overlays);

    final active = _flatLineY(tester, dashed: false);
    final overlay = _flatLineY(tester, dashed: true);
    expect(_axisReadingAt(tester, active), closeTo(20, 0.1));
    expect(_axisReadingAt(tester, overlay), closeTo(30, 0.1));
  });

  testWidgets('the active line and the axis rescale together as the overlay '
      'is shown and hidden', (tester) async {
    await _pumpChart(tester, profile: _profile(20), overlays: overlays);

    double activeReading() =>
        _axisReadingAt(tester, _flatLineY(tester, dashed: false));

    expect(activeReading(), closeTo(20, 0.1));

    overlays.value = [_overlay(30)];
    await tester.pumpAndSettle();
    expect(activeReading(), closeTo(20, 0.1));
    expect(
      _axisReadingAt(tester, _flatLineY(tester, dashed: true)),
      closeTo(30, 0.1),
    );

    overlays.value = null;
    await tester.pumpAndSettle();
    expect(activeReading(), closeTo(20, 0.1));
  });

  testWidgets('the pooled range follows the diver\'s temperature unit', (
    tester,
  ) async {
    overlays.value = [_overlay(30)];
    await _pumpChart(
      tester,
      profile: _profile(20),
      overlays: overlays,
      settings: const AppSettings(temperatureUnit: TemperatureUnit.fahrenheit),
    );

    expect(
      _axisReadingAt(tester, _flatLineY(tester, dashed: false)),
      closeTo(68, 0.2),
    );
    expect(
      _axisReadingAt(tester, _flatLineY(tester, dashed: true)),
      closeTo(86, 0.2),
    );
  });

  testWidgets('an overlay is enough to put temperature on the right axis', (
    tester,
  ) async {
    overlays.value = [_overlay(30)];
    await _pumpChart(tester, profile: _profile(null), overlays: overlays);

    expect(find.text('Temp (°C)'), findsOneWidget);
    expect(
      _axisReadingAt(tester, _flatLineY(tester, dashed: true)),
      closeTo(30, 0.1),
    );
  });
}
