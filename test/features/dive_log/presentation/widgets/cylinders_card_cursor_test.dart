import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_app.dart';

// Issue #4291: the Cylinders card follows the profile cursor.

const _air = DiveTank(
  id: 'air',
  volume: 11.1,
  startPressure: 200,
  endPressure: 50,
  gasMix: GasMix(o2: 21),
);
const _stage = DiveTank(
  id: 'stage',
  volume: 5.7,
  startPressure: 200,
  endPressure: 140,
  gasMix: GasMix(o2: 50),
  order: 1,
);

/// A 50 minute dive sampled every 10 seconds, so index 150 is 25:00.
Dive _dive(List<DiveTank> tanks) => Dive(
  id: 'dive-1',
  diveNumber: 1,
  dateTime: DateTime(2026, 6, 1, 10),
  maxDepth: 25,
  avgDepth: 18,
  bottomTime: const Duration(minutes: 50),
  tanks: tanks,
  profile: [
    for (var t = 0; t <= 3000; t += 10)
      DiveProfilePoint(timestamp: t, depth: 20),
  ],
);

/// Air on a transmitter (200 to 50 over the dive, so 125 at 25:00) and the
/// stage's estimate (held at 200 until the switch at 35:00).
const _chartSeries = EstimatedTankPressures(
  {
    'air': [
      TankPressurePoint(tankId: 'air', timestamp: 0, pressure: 200),
      TankPressurePoint(tankId: 'air', timestamp: 3000, pressure: 50),
    ],
    'stage': [
      TankPressurePoint(tankId: 'stage', timestamp: 0, pressure: 200),
      TankPressurePoint(tankId: 'stage', timestamp: 2100, pressure: 200),
      TankPressurePoint(tankId: 'stage', timestamp: 3000, pressure: 140),
    ],
  },
  {'stage'},
);

Widget _card({
  required Dive dive,
  int? cursor,
  EstimatedTankPressures chartSeries = _chartSeries,
  bool estimatesFail = false,
  Map<String, List<TankPressurePoint>> measured = const {},
  AppSettings settings = const AppSettings(),
}) {
  final units = UnitFormatter(settings);
  return testApp(
    overrides: [
      cylinderSacProvider.overrideWith(
        (ref, id) async => const <CylinderSac>[],
      ),
      tankPressuresProvider.overrideWith((ref, id) async => measured),
      diveDataSourcesProvider.overrideWith(
        (ref, id) async => const <DiveDataSource>[],
      ),
      transmittersProvider.overrideWith((ref) async => const <Transmitter>[]),
      estimatedTankPressuresProvider.overrideWith(
        (ref, id) async => estimatesFail
            ? throw StateError('gas switches failed to load')
            : chartSeries,
      ),
      activeSourceProfileProvider.overrideWith((ref, id) => null),
      profileTrackingIndexProvider.overrideWith((ref, id) => cursor),
    ],
    child: SingleChildScrollView(
      child: CylindersCard(
        dive: dive,
        units: units,
        settings: settings,
        display: GasConsumptionDisplay.sac,
      ),
    ),
  );
}

Finder _figureOf(String tankLabel) =>
    find.ancestor(of: find.text(tankLabel), matching: find.byType(TankFigure));

void main() {
  testWidgets('each tank shows its pressure at the cursor', (tester) async {
    await tester.pumpWidget(_card(dive: _dive([_air, _stage]), cursor: 150));
    await tester.pumpAndSettle();

    expect(find.text('Now 125 bar'), findsOneWidget);
    // The stage is on its estimate, and is not breathed yet at 25:00.
    expect(find.text('Now 200 bar (est.)'), findsOneWidget);
    // The whole-dive labels stay.
    expect(find.text('End 50 bar'), findsOneWidget);
    expect(find.text('End 140 bar'), findsOneWidget);
  });

  testWidgets('follows the cursor as it moves and leaves', (tester) async {
    await tester.pumpWidget(_card(dive: _dive([_air]), cursor: 150));
    await tester.pumpAndSettle();
    expect(find.text('Now 125 bar'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CylindersCard)),
    );
    final cursor = container.read(
      profileTrackingIndexProvider('dive-1').notifier,
    );
    // 10:00
    cursor.state = 60;
    await tester.pump();
    expect(find.text('Now 170 bar'), findsOneWidget);

    cursor.state = null;
    await tester.pump();
    expect(find.textContaining('Now'), findsNothing);
  });

  testWidgets('no cursor, no now label', (tester) async {
    await tester.pumpWidget(_card(dive: _dive([_air, _stage])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Now'), findsNothing);
  });

  testWidgets('the figures keep their size as the cursor comes and goes', (
    tester,
  ) async {
    await tester.pumpWidget(_card(dive: _dive([_air, _stage])));
    await tester.pumpAndSettle();
    final idle = [
      tester.getSize(_figureOf('End 50 bar')),
      tester.getSize(_figureOf('End 140 bar')),
    ];

    await tester.pumpWidget(_card(dive: _dive([_air, _stage]), cursor: 150));
    await tester.pumpAndSettle();
    expect(tester.getSize(_figureOf('End 50 bar')), idle[0]);
    expect(tester.getSize(_figureOf('End 140 bar')), idle[1]);
  });

  testWidgets('a tank the chart draws no line for gets no now label', (
    tester,
  ) async {
    // Estimates switched off: only the transmitter's series is drawn.
    await tester.pumpWidget(
      _card(
        dive: _dive([_air, _stage]),
        cursor: 150,
        chartSeries: EstimatedTankPressures({
          'air': _chartSeries.pressures['air']!,
        }, const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now 125 bar'), findsOneWidget);
    expect(find.textContaining('(est.)'), findsNothing);
    expect(find.textContaining('Now'), findsOneWidget);
  });

  testWidgets('a series keyed by an old tank id still follows the cursor', (
    tester,
  ) async {
    // A reparse gave the tank a fresh id; the series kept the old one.
    await tester.pumpWidget(
      _card(
        dive: _dive([_air]),
        cursor: 150,
        chartSeries: EstimatedTankPressures({
          'old-air-id': _chartSeries.pressures['air']!,
        }, const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now 125 bar'), findsOneWidget);
  });

  testWidgets('an old-id transmitter series wins over an estimate', (
    tester,
  ) async {
    // As the chart's provider builds it: the measured series kept the
    // tank's old id, and the tank has start and end pressures to estimate
    // from. The card follows the transmitter, not an estimate.
    final dive = _dive([_air]);
    final chartSeries = synthesizeEstimatedTankPressures(
      existing: {
        'old-air-id': [
          const TankPressurePoint(
            tankId: 'old-air-id',
            timestamp: 0,
            pressure: 200,
          ),
          const TankPressurePoint(
            tankId: 'old-air-id',
            timestamp: 1500,
            pressure: 110,
          ),
          const TankPressurePoint(
            tankId: 'old-air-id',
            timestamp: 3000,
            pressure: 50,
          ),
        ],
      },
      tanks: dive.tanks,
      gasSwitches: const [],
      diveDurationSeconds: 3000,
    );
    await tester.pumpWidget(
      _card(dive: dive, cursor: 150, chartSeries: chartSeries),
    );
    await tester.pumpAndSettle();

    // The estimate would read 125 at 25:00.
    expect(find.text('Now 110 bar'), findsOneWidget);
  });

  testWidgets('follows the measured lines the chart falls back to', (
    tester,
  ) async {
    // The estimates failed to load, so the chart draws the measured series
    // alone; the card follows those same lines.
    await tester.pumpWidget(
      _card(
        dive: _dive([_air, _stage]),
        cursor: 150,
        estimatesFail: true,
        measured: {'air': _chartSeries.pressures['air']!},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Now 125 bar'), findsOneWidget);
    expect(find.textContaining('(est.)'), findsNothing);
  });

  testWidgets('start and end read a series keyed by an old tank id', (
    tester,
  ) async {
    // No stored start or end pressure, and a reparse left the transmitter
    // series under the tank's old id: the figure's Start and End come from
    // the same series its now line follows.
    const bare = DiveTank(
      id: 'air',
      volume: 11.1,
      workingPressure: 232,
      gasMix: GasMix(o2: 21),
    );
    final series = [
      for (final p in _chartSeries.pressures['air']!)
        TankPressurePoint(
          tankId: 'old-air-id',
          timestamp: p.timestamp,
          pressure: p.pressure,
        ),
    ];
    await tester.pumpWidget(
      _card(
        dive: _dive([bare]),
        cursor: 150,
        measured: {'old-air-id': series},
        chartSeries: EstimatedTankPressures({'old-air-id': series}, const {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start 200 bar'), findsOneWidget);
    expect(find.text('End 50 bar'), findsOneWidget);
    expect(find.text('Now 125 bar'), findsOneWidget);
  });

  testWidgets('the pressure follows the diver units', (tester) async {
    const settings = AppSettings(pressureUnit: PressureUnit.psi);
    await tester.pumpWidget(
      _card(dive: _dive([_air]), cursor: 150, settings: settings),
    );
    await tester.pumpAndSettle();

    final psi = const UnitFormatter(settings).formatPressure(125);
    expect(psi, contains('psi'));
    expect(find.text('Now $psi'), findsOneWidget);
  });

  testWidgets('a cursor past the charted profile shows nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_card(dive: _dive([_air]), cursor: 5000));
    await tester.pumpAndSettle();

    expect(find.textContaining('Now'), findsNothing);
  });
}
