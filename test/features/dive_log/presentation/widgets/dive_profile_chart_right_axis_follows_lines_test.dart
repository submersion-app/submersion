/// Issue #5012: with the temperature line turned off, the right axis kept the
/// temperature scale, labelling a line that was no longer on the chart. The
/// axis now follows the lines that are drawn.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A 20-minute dive at 24 C throughout.
final _profile = List.generate(
  41,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i <= 20 ? i * 1.0 : (40 - i) * 1.0,
    temperature: 24,
  ),
);

/// One tank draining from 200 to 80 bar.
final _tankPressures = {
  'tank-1': [
    for (var t = 0; t <= 1200; t += 60)
      TankPressurePoint(tankId: 'tank-1', timestamp: t, pressure: 200 - t / 10),
  ],
};

Future<void> _pumpChart(
  WidgetTester tester,
  AppSettings settings, {
  List<List<double?>>? o2SensorCurves,
  List<List<int?>>? o2CellMvCurves,
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
            child: DiveProfileChart(
              profile: _profile,
              tankPressures: _tankPressures,
              o2SensorCurves: o2SensorCurves,
              o2CellMvCurves: o2CellMvCurves,
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

/// How many tick labels the right axis shows.
int _rightTickCount(WidgetTester tester) => tester
    .widgetList<SideTitleWidget>(find.byType(SideTitleWidget))
    .where((t) => t.meta.axisSide == AxisSide.right)
    .length;

final _temperatureAxis = find.text('Temp (°C)');
final _pressureAxis = find.text('Press (bar)');

void main() {
  testWidgets('the temperature line on keeps the temperature axis', (
    tester,
  ) async {
    await _pumpChart(tester, const AppSettings());

    expect(_temperatureAxis, findsOneWidget);
    expect(_pressureAxis, findsNothing);
  });

  testWidgets('the temperature line off moves the axis to pressure', (
    tester,
  ) async {
    await _pumpChart(tester, const AppSettings(defaultShowTemperature: false));

    expect(_temperatureAxis, findsNothing);
    expect(_pressureAxis, findsOneWidget);
  });

  testWidgets('turning temperature off and on again moves the axis back', (
    tester,
  ) async {
    await _pumpChart(tester, const AppSettings());

    _legend(tester).toggleTemperature();
    await tester.pumpAndSettle();
    expect(_temperatureAxis, findsNothing);
    expect(_pressureAxis, findsOneWidget);

    _legend(tester).toggleTemperature();
    await tester.pumpAndSettle();
    expect(_temperatureAxis, findsOneWidget);
    expect(_pressureAxis, findsNothing);
  });

  testWidgets('with only depth drawn there is no right axis', (tester) async {
    await _pumpChart(
      tester,
      const AppSettings(
        defaultShowTemperature: false,
        defaultShowPressure: false,
      ),
    );

    expect(_temperatureAxis, findsNothing);
    expect(_pressureAxis, findsNothing);
    expect(_rightTickCount(tester), 0);
  });

  testWidgets('a hidden tank no longer holds the axis', (tester) async {
    await _pumpChart(tester, const AppSettings(defaultShowTemperature: false));

    _legend(tester).toggleTankPressure('tank-1');
    await tester.pumpAndSettle();

    expect(_pressureAxis, findsNothing);
    expect(_rightTickCount(tester), 0);
  });

  group('O2 cells', () {
    // Two cells, logged both as ppO2 and as raw millivolts.
    final ppO2 = List<List<double?>>.generate(2, (_) => List.filled(41, 1.2));
    final mv = List<List<int?>>.generate(2, (_) => List.filled(41, 45));
    final cellsAxis = find.text('Cells');

    AppSettings cellsOnly(O2CellUnit unit) => AppSettings(
      defaultShowTemperature: false,
      defaultShowPressure: false,
      defaultShowO2CellMv: true,
      o2CellUnit: unit,
      defaultRightAxisMetric: ProfileRightAxisMetric.o2CellMv,
    );

    testWidgets('cells drawn in millivolts hold the millivolt axis', (
      tester,
    ) async {
      await _pumpChart(
        tester,
        cellsOnly(O2CellUnit.millivolts),
        o2SensorCurves: ppO2,
        o2CellMvCurves: mv,
      );

      expect(cellsAxis, findsOneWidget);
    });

    testWidgets('cells drawn in ppO2 leave no millivolt axis', (tester) async {
      // The cells sit on the ppO2 scale then, so a millivolt axis would
      // label no line on the chart.
      await _pumpChart(
        tester,
        cellsOnly(O2CellUnit.ppO2),
        o2SensorCurves: ppO2,
        o2CellMvCurves: mv,
      );

      expect(cellsAxis, findsNothing);
    });
  });
}
