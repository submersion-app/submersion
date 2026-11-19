import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_app.dart';
import 'dive_card_scope.dart';

/// Issue #4664: an Avelo dive's Cylinders card sums up what the computer
/// recorded (gas remaining, buoyancy, its own RMV, the highest Hydrotank
/// pressure) under the Hydrotank, in the diver's units.
const _hydrotank = DiveTank(
  id: 'hydro',
  volume: 10,
  startPressure: 240,
  endPressure: 90,
  gasMix: GasMix(o2: 21),
  role: TankRole.hydrotank,
);
const _backGas = DiveTank(
  id: 'back',
  volume: 12,
  startPressure: 200,
  endPressure: 60,
  gasMix: GasMix(o2: 21),
);

const _profile = [
  DiveProfilePoint(
    timestamp: 0,
    depth: 0.0,
    aveloBuoyancy: -0.096,
    aveloGasRemaining: 100,
  ),
  DiveProfilePoint(
    timestamp: 10,
    depth: 3.1,
    aveloBuoyancy: -0.320,
    aveloGasRemaining: 97,
  ),
  DiveProfilePoint(
    timestamp: 20,
    depth: 15.0,
    aveloBuoyancy: -0.393,
    aveloGasRemaining: 80,
    computerRmv: 27.91,
  ),
  DiveProfilePoint(
    timestamp: 30,
    depth: 10.0,
    aveloBuoyancy: 1.242,
    aveloGasRemaining: 36,
    computerRmv: 10.68,
  ),
];

const _pressures = {
  'hydro': [
    TankPressurePoint(tankId: 'hydro', timestamp: 0, pressure: 250.0),
    TankPressurePoint(tankId: 'hydro', timestamp: 10, pressure: 241.2),
    TankPressurePoint(tankId: 'hydro', timestamp: 20, pressure: 230.0),
    TankPressurePoint(tankId: 'hydro', timestamp: 30, pressure: 120.0),
  ],
};

Widget _card({
  required AppSettings settings,
  List<DiveTank> tanks = const [_hydrotank],
  List<DiveProfilePoint> profile = _profile,
  Map<String, List<TankPressurePoint>> pressures = _pressures,
}) => testApp(
  overrides: [
    cylinderSacProvider.overrideWith((ref, id) async => const <CylinderSac>[]),
    tankPressuresProvider.overrideWith((ref, id) async => pressures),
    diveDataSourcesProvider.overrideWith(
      (ref, id) async => const <DiveDataSource>[],
    ),
    transmittersProvider.overrideWith((ref) async => const <Transmitter>[]),
  ],
  child: SingleChildScrollView(
    child: onDivePage(
      CylindersCard(
        dive: Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2025, 4, 19, 11, 18),
          maxDepth: 15,
          bottomTime: const Duration(minutes: 40),
          tanks: tanks,
          profile: profile,
        ),
        units: UnitFormatter(settings),
        settings: settings,
        display: GasConsumptionDisplay.sac,
      ),
    ),
  ),
);

String _signed(UnitFormatter units, double kg) =>
    kg > 0 ? '+${units.formatWeight(kg)}' : units.formatWeight(kg);

void main() {
  for (final settings in const [
    AppSettings(),
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  ]) {
    final units = UnitFormatter(settings);
    testWidgets('sums up the Avelo values under the Hydrotank '
        '(${settings.weightUnit.symbol})', (tester) async {
      await tester.pumpWidget(_card(settings: settings));
      await tester.pumpAndSettle();

      final block = find.byKey(const Key('tank-avelo-summary-hydro'));
      expect(block, findsOneWidget);
      Finder inBlock(String text) =>
          find.descendant(of: block, matching: find.text(text));

      expect(inBlock('Avelo'), findsOneWidget);
      expect(inBlock('Gas remaining 97% to 36%'), findsOneWidget);
      expect(
        inBlock(
          'Avelo buoyancy ${_signed(units, -0.393)} to '
          '${_signed(units, 1.242)}, average '
          '${_signed(units, (-0.320 - 0.393 + 1.242) / 3)}',
        ),
        findsOneWidget,
      );
      expect(
        inBlock(
          'RMV (computer) ${units.formatRmv(10.68)} to '
          '${units.formatRmv(27.91)}',
        ),
        findsOneWidget,
      );
      expect(
        inBlock('Max pressure ${units.formatPressure(241.2)}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('leaves out a line with no value', (tester) async {
    await tester.pumpWidget(
      _card(
        settings: const AppSettings(),
        profile: const [
          DiveProfilePoint(timestamp: 10, depth: 5.0, aveloGasRemaining: 90),
          DiveProfilePoint(timestamp: 20, depth: 6.0, aveloGasRemaining: 88),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final block = find.byKey(const Key('tank-avelo-summary-hydro'));
    expect(
      find.descendant(
        of: block,
        matching: find.text('Gas remaining 90% to 88%'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: block, matching: find.textContaining('buoyancy')),
      findsNothing,
    );
    expect(
      find.descendant(of: block, matching: find.textContaining('RMV')),
      findsNothing,
    );
    // The Hydrotank pressures at 10 s and 20 s still give a maximum.
    expect(
      find.descendant(of: block, matching: find.textContaining('Max pressure')),
      findsOneWidget,
    );
  });

  testWidgets('a dive without Avelo data shows no summary', (tester) async {
    await tester.pumpWidget(
      _card(
        settings: const AppSettings(),
        tanks: const [_backGas],
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 10.0),
          DiveProfilePoint(timestamp: 10, depth: 12.0),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Avelo'), findsNothing);
  });

  testWidgets('with no Hydrotank-role tank the summary sits under the first '
      'tank', (tester) async {
    await tester.pumpWidget(
      _card(settings: const AppSettings(), tanks: const [_backGas]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tank-avelo-summary-back')), findsOneWidget);
  });

  // The Hydrotank's figure shows its estimated water (spec section 6).
  testWidgets('the Hydrotank figure names its estimated water', (tester) async {
    await tester.pumpWidget(_card(settings: const AppSettings()));
    await tester.pumpAndSettle();

    final label = find.byKey(const Key('tank-water-label-hydro'));
    expect(label, findsOneWidget);
    final text = tester.widget<Text>(label).data!;
    expect(text, startsWith('Water ~'));
    expect(text, endsWith('(est.)'));
  });

  testWidgets('a Hydrotank without gas remaining keeps the pressure figure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(
        settings: const AppSettings(),
        profile: const [
          DiveProfilePoint(timestamp: 10, depth: 5.0),
          DiveProfilePoint(timestamp: 20, depth: 6.0),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tank-water-label-hydro')), findsNothing);
  });

  testWidgets('under a tank that is no Hydrotank, no max pressure', (
    tester,
  ) async {
    // Final review: that tank's pressure is not the Hydrotank's.
    await tester.pumpWidget(
      _card(
        settings: const AppSettings(),
        tanks: const [_backGas],
        pressures: const {
          'back': [
            TankPressurePoint(tankId: 'back', timestamp: 10, pressure: 200),
            TankPressurePoint(tankId: 'back', timestamp: 30, pressure: 60),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    final block = find.byKey(const Key('tank-avelo-summary-back'));
    expect(block, findsOneWidget);
    expect(
      find.descendant(of: block, matching: find.textContaining('Max pressure')),
      findsNothing,
    );
  });
}
