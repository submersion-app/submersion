/// The right axis has to label the scale a metric's lines are drawn on. These
/// tests read the chart the way a diver does: find a drawn line, then read the
/// value the right axis labels at that height.
///
/// Issue #3893: an overlaid computer pools its readings into the temperature
/// scale, and tank pressure kept separate scales for lines, axis and markers.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
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

/// A tank whose every sample reads [pressure] (bar).
List<TankPressurePoint> _tank(String id, double pressure) => [
  for (var t = 0; t <= 1200; t += 60)
    TankPressurePoint(tankId: id, timestamp: t, pressure: pressure),
];

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
  Map<String, List<TankPressurePoint>>? tankPressures,
  List<ProfileMarker>? markers,
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 1700,
            height: 900,
            child: ValueListenableBuilder(
              valueListenable: overlays,
              builder: (context, value, _) => DiveProfileChart(
                profile: profile,
                overlays: value,
                tankPressures: tankPressures,
                markers: markers,
                showPressureThresholdMarkers: markers != null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data.lineBarsData;

/// The multi-point lines that never change height. The fixtures hold every
/// temperature and tank pressure constant, and nothing else is flat.
List<LineChartBarData> _flatLines(WidgetTester tester) => [
  for (final bar in _bars(tester))
    if (bar.spots.length > 1 &&
        bar.spots.every((s) => s.y == bar.spots.first.y))
      bar,
];

/// The Y of the one temperature line of the given style: the active source's
/// is solid and an overlay's is dashed.
double _flatLineY(WidgetTester tester, {required bool dashed}) => _flatLines(
  tester,
).where((bar) => (bar.dashArray != null) == dashed).single.spots.first.y;

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

  group('tank pressure', () {
    final tankPressures = {'a': _tank('a', 200), 'b': _tank('b', 180)};
    const settings = AppSettings(
      defaultRightAxisMetric: ProfileRightAxisMetric.pressure,
      defaultShowPressure: true,
      showPressureThresholdMarkers: true,
    );

    /// The tank lines' heights, the lower pressure (further down) first.
    List<double> tankLineYs(WidgetTester tester) =>
        [for (final bar in _flatLines(tester)) bar.spots.first.y]..sort();

    testWidgets('both tanks read true against the right axis', (tester) async {
      await _pumpChart(
        tester,
        profile: _profile(null),
        overlays: overlays,
        settings: settings,
        tankPressures: tankPressures,
      );

      final ys = tankLineYs(tester);
      expect(ys, hasLength(2));
      expect(_axisReadingAt(tester, ys.last), closeTo(200, 0.5));
      expect(_axisReadingAt(tester, ys.first), closeTo(180, 0.5));
    });

    testWidgets('a channel with no pressure change falls back to another '
        'metric', (tester) async {
      await _pumpChart(
        tester,
        profile: _profile(20),
        overlays: overlays,
        settings: settings,
        tankPressures: {'a': _tank('a', 0)},
      );

      expect(find.text('Temp (°C)'), findsOneWidget);
    });

    testWidgets('a threshold marker sits on the line at its own pressure', (
      tester,
    ) async {
      await _pumpChart(
        tester,
        profile: _profile(null),
        overlays: overlays,
        settings: settings,
        tankPressures: tankPressures,
        markers: const [
          ProfileMarker(
            timestamp: 600,
            depth: 10,
            type: ProfileMarkerType.pressureHalf,
            tankId: 'a',
            value: 200,
          ),
        ],
      );

      final markerY = _bars(tester)
          .where((bar) => bar.spots.length == 1 && bar.spots.first.x == 600)
          .single
          .spots
          .first
          .y;
      expect(markerY, closeTo(tankLineYs(tester).last, 0.01));
    });
  });
}
