import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/icons/submersion_icons.dart';
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

/// The Tanks card lists a suit inflation bottle with its role and pressures,
/// and none of the breathing gas figures (issue #4243).
const _settings = AppSettings();

const _suit = DiveTank(
  id: 'suit',
  name: 'Argon',
  volume: 0.85,
  startPressure: 200,
  endPressure: 170,
  gasMix: GasMix(o2: 21),
  role: TankRole.suitInflation,
);
const _back = DiveTank(
  id: 'back',
  volume: 11.1,
  startPressure: 200,
  endPressure: 60,
  gasMix: GasMix(o2: 32),
  role: TankRole.backGas,
);

Widget _card(
  List<DiveTank> tanks, {
  List<CylinderSac> rows = const <CylinderSac>[],
}) => testApp(
  overrides: [
    cylinderSacProvider.overrideWith((ref, id) async => rows),
    tankPressuresProvider.overrideWith(
      (ref, id) async => const <String, List<TankPressurePoint>>{},
    ),
    diveDataSourcesProvider.overrideWith(
      (ref, id) async => const <DiveDataSource>[],
    ),
    transmittersProvider.overrideWith((ref) async => const <Transmitter>[]),
  ],
  child: SingleChildScrollView(
    child: CylindersCard(
      dive: Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime(2026, 6, 1, 10),
        maxDepth: 30,
        bottomTime: const Duration(minutes: 45),
        tanks: tanks,
      ),
      units: const UnitFormatter(_settings),
      settings: _settings,
      display: GasConsumptionDisplay.sac,
    ),
  ),
);

void main() {
  testWidgets('the bottle shows its role and pressures, no MOD', (
    tester,
  ) async {
    await tester.pumpWidget(_card(const [_back, _suit]));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tank-role-suit')),
        matching: find.text('Suit Inflation'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(SubmersionIcons.tankPony), findsOneWidget);
    expect(find.text('Argon'), findsOneWidget);
    expect(find.textContaining('170'), findsWidgets);
    // Only the back gas has a MOD and an MND; the other MOD is the card's
    // note of the ppO2 it is taken at.
    expect(find.textContaining('MOD '), findsNWidgets(2));
    expect(find.textContaining('MOD at'), findsOneWidget);
    expect(find.textContaining('MND '), findsOneWidget);
  });

  testWidgets('a dive with only the bottle has no MOD note', (tester) async {
    await tester.pumpWidget(_card(const [_suit]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Argon'), findsOneWidget);
    expect(find.textContaining('MOD'), findsNothing);
  });

  testWidgets(
    'a stale consumption row for the bottle shows no loop use or SAC',
    (tester) async {
      // The card reads the provider's retained value while it reloads, so a
      // tank just changed to Suit Inflation can still have a row from when it
      // was breathed.
      await tester.pumpWidget(
        _card(
          const [_suit],
          rows: const [
            CylinderSac(
              tankId: 'suit',
              gasMix: GasMix(o2: 21),
              role: TankRole.backGas,
              tankVolume: 0.85,
              loopRate: 1.8,
              sacRate: 1.2,
              startPressure: 200,
              endPressure: 170,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tank-loop-use-suit')), findsNothing);
      expect(find.textContaining('SAC'), findsNothing);
      expect(find.textContaining('L/min'), findsNothing);
    },
  );
}
