import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Issue #1999: switching "Pressure" off in Settings > Default visible metrics
// had no effect on transmitter dives. Every tank's trace was drawn anyway,
// because each tank's visibility was forced on the first time the chart saw
// it, and the chart never consulted the Pressure default at all.

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _air = DiveTank(id: 'tank-1', gasMix: GasMix(o2: 21), order: 0);
const _ean50 = DiveTank(id: 'tank-2', gasMix: GasMix(o2: 50), order: 1);

List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 3.0 : (20 - i) * 3.0,
  ),
);

Map<String, List<TankPressurePoint>> _pressures() => {
  for (final (id, start) in [('tank-1', 200.0), ('tank-2', 180.0)])
    id: [
      for (var i = 0; i < 20; i++)
        TankPressurePoint(
          tankId: id,
          timestamp: i * 30,
          pressure: start - i * 5,
        ),
    ],
};

GasSwitchWithTank _switchTo(DiveTank tank, int timestamp) => GasSwitchWithTank(
  gasSwitch: GasSwitch(
    id: 'gs-${tank.id}',
    diveId: 'dive-1',
    timestamp: timestamp,
    tankId: tank.id,
    createdAt: DateTime(2026, 1, 1),
  ),
  tankName: tank.id,
  gasMix: tank.gasMix.name,
  o2Fraction: tank.gasMix.o2 / 100,
);

Widget _chart(AppSettings settings, {List<GasSwitchWithTank>? gasSwitches}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _SettingsNotifier(settings)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: _profile(),
            tanks: const [_air, _ean50],
            tankPressures: _pressures(),
            gasSwitches: gasSwitches,
          ),
        ),
      ),
    ),
  );
}

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart).first).data.lineBarsData;

/// Tank pressure traces are the multi-point bars drawn in the tank's gas
/// colour.
int _traceCount(WidgetTester tester, DiveTank tank) => _bars(tester)
    .where(
      (b) =>
          b.color == GasColors.forGasMix(tank.gasMix) &&
          b.spots.length > 1 &&
          b.barWidth > 0,
    )
    .length;

/// Gas-switch markers are the only bars drawn as a single transparent,
/// zero-width spot carrying a dot painter.
int _markerCount(WidgetTester tester) => _bars(tester)
    .where(
      (b) =>
          b.color == Colors.transparent &&
          b.barWidth == 0 &&
          b.spots.length == 1 &&
          b.dotData.show,
    )
    .length;

ProfileLegend _legend(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DiveProfileChart)),
).read(profileLegendProvider.notifier);

void main() {
  group('DiveProfileChart tank pressure default (issue #1999)', () {
    testWidgets('draws every tank trace when the Pressure default is on', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(const AppSettings()));
      await tester.pumpAndSettle();

      expect(_traceCount(tester, _air), 1);
      expect(_traceCount(tester, _ean50), 1);
    });

    testWidgets('draws no tank trace when the Pressure default is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(const AppSettings(defaultShowPressure: false)),
      );
      await tester.pumpAndSettle();

      expect(_traceCount(tester, _air), 0);
      expect(_traceCount(tester, _ean50), 0);
    });

    testWidgets('a tank switched on by hand shows on its own', (tester) async {
      await tester.pumpWidget(
        _chart(const AppSettings(defaultShowPressure: false)),
      );
      await tester.pumpAndSettle();

      _legend(tester).toggleTankPressure('tank-1', visibleByDefault: false);
      await tester.pumpAndSettle();

      expect(_traceCount(tester, _air), 1);
      expect(_traceCount(tester, _ean50), 0);
    });

    testWidgets('the Pressure default leaves gas-switch markers alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          const AppSettings(defaultShowPressure: false),
          gasSwitches: [_switchTo(_air, 60), _switchTo(_ean50, 300)],
        ),
      );
      await tester.pumpAndSettle();

      expect(_traceCount(tester, _air), 0);
      expect(_markerCount(tester), 2);
    });

    testWidgets('drops a stale tank choice once the legend is rebuilt', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(const AppSettings()));
      await tester.pumpAndSettle();

      _legend(tester).toggleTankPressure('tank-1');
      await tester.pumpAndSettle();
      expect(_traceCount(tester, _air), 0);

      // A write to a watched default rebuilds the legend provider, which
      // starts over with no per-tank choices: tank-1 follows the Pressure
      // default (on) again, so the chart must not keep its old choice.
      final settings = ProviderScope.containerOf(
        tester.element(find.byType(DiveProfileChart)),
      ).read(settingsProvider.notifier);
      (settings as _SettingsNotifier).state = settings.state.copyWith(
        defaultShowTemperature: !settings.state.defaultShowTemperature,
      );
      await tester.pumpAndSettle();

      expect(_traceCount(tester, _air), 1);
    });
  });
}
