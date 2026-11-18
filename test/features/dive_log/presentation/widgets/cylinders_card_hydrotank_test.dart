import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
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

/// The Tanks card lists an Avelo Hydrotank with its role, pressures, MOD and
/// MND, and says why it has no gas used or SAC: its pressure rises with the
/// water pumped in for buoyancy (issue #4657).
const _settings = AppSettings();

const _hydrotank = DiveTank(
  id: 'hydro',
  volume: 10,
  startPressure: 200,
  endPressure: 185,
  gasMix: GasMix(o2: 21),
  role: TankRole.hydrotank,
);
const _pony = DiveTank(
  id: 'pony',
  volume: 3,
  startPressure: 200,
  endPressure: 170,
  gasMix: GasMix(o2: 21),
  role: TankRole.pony,
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
    child: onDivePage(
      CylindersCard(
        dive: Dive(
          id: 'dive-1',
          diveNumber: 1,
          dateTime: DateTime(2026, 11, 17, 9),
          maxDepth: 18,
          bottomTime: const Duration(minutes: 40),
          tanks: tanks,
        ),
        units: const UnitFormatter(_settings),
        settings: _settings,
        display: GasConsumptionDisplay.sac,
      ),
    ),
  ),
);

/// A stale row for the Hydrotank, as the provider can retain from before
/// the tank became one, and the pony's own.
const _rows = [
  CylinderSac(
    tankId: 'hydro',
    gasMix: GasMix(o2: 21),
    role: TankRole.backGas,
    tankVolume: 10,
    sacRate: 0.3,
    startPressure: 200,
    endPressure: 185,
  ),
  CylinderSac(
    tankId: 'pony',
    gasMix: GasMix(o2: 21),
    role: TankRole.pony,
    tankVolume: 3,
    sacRate: 1.2,
    startPressure: 200,
    endPressure: 170,
  ),
];

void main() {
  testWidgets('the Hydrotank shows its role, pressures, MOD and the note', (
    tester,
  ) async {
    await tester.pumpWidget(_card(const [_hydrotank]));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('tank-role-hydro')),
        matching: find.text('Hydrotank'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('185'), findsWidgets);
    expect(find.textContaining('MND '), findsOneWidget);
    expect(
      find.text('Hydrotank pressure does not measure gas used'),
      findsOneWidget,
    );
    // The gauge's pressure drop is no gas used either.
    expect(find.textContaining('Used'), findsNothing);
  });

  testWidgets('no gas used or SAC for the Hydrotank, the pony keeps its own', (
    tester,
  ) async {
    await tester.pumpWidget(_card(const [_hydrotank, _pony], rows: _rows));
    await tester.pumpAndSettle();

    // Only the pony's figures: one gas used line and one SAC.
    expect(find.textContaining('Gas used'), findsOneWidget);
    expect(find.textContaining('SAC'), findsOneWidget);
    expect(
      find.text('Hydrotank pressure does not measure gas used'),
      findsOneWidget,
    );
  });

  testWidgets('a pony has no Hydrotank note', (tester) async {
    await tester.pumpWidget(_card(const [_pony]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hydrotank'), findsNothing);
  });
}
