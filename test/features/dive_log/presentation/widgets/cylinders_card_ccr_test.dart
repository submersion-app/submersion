import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/cylinders_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';

import '../../../../helpers/test_app.dart';

/// A CCR dive's rates read as loop use, with SAC and RMV kept for the gas
/// lost after a bailout (issue #4082).
const _tank = DiveTank(
  id: 'tank',
  volume: 1.5,
  startPressure: 174,
  endPressure: 102,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);

Widget _card(
  CylinderSac row, {
  GasConsumptionDisplay display = GasConsumptionDisplay.both,
  AppSettings settings = const AppSettings(),
  List<DiveTank> tanks = const [_tank],
  List<CylinderSac>? rows,
}) {
  return testApp(
    locale: const Locale('en'),
    overrides: [
      cylinderSacProvider.overrideWith((ref, id) async => rows ?? [row]),
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
          diveMode: DiveMode.ccr,
          tanks: tanks,
        ),
        units: UnitFormatter(settings),
        settings: settings,
        display: display,
      ),
    ),
  );
}

CylinderSac _row({double? loopRate, double? sacRate, double? tankVolume}) =>
    CylinderSac(
      tankId: 'tank',
      gasMix: const GasMix(o2: 100),
      role: TankRole.oxygenSupply,
      tankVolume: tankVolume ?? 1.5,
      loopRate: loopRate,
      sacRate: sacRate,
      startPressure: 174,
      endPressure: 102,
    );

void main() {
  group('CylindersCard on a CCR dive', () {
    testWidgets('shows Loop use beside Gas used on an O2 row', (tester) async {
      await tester.pumpWidget(_card(_row(loopRate: 1.8)));
      await tester.pumpAndSettle();

      expect(find.text('Loop use 1.8 L/min'), findsOneWidget);
      expect(find.text('Gas used 108 L'), findsOneWidget);
    });

    testWidgets('each cylinder of the issue dive reads its own figure', (
      tester,
    ) async {
      const left = DiveTank(id: 'left', role: TankRole.sidemountLeft);
      const right = DiveTank(id: 'right', role: TankRole.sidemountRight);
      CylinderSac sac(String id, TankRole role, double? loopRate) =>
          CylinderSac(
            tankId: id,
            gasMix: const GasMix(),
            role: role,
            tankVolume: 7,
            loopRate: loopRate,
            startPressure: 216,
            endPressure: 163,
          );
      await tester.pumpWidget(
        _card(
          _row(),
          tanks: const [left, right, _tank],
          rows: [
            sac('left', TankRole.sidemountLeft, null),
            sac('right', TankRole.sidemountRight, 5.4),
            _row(loopRate: 1.9),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tank-loop-use-left')), findsNothing);
      final right5 = find.byKey(const Key('tank-loop-use-right'));
      expect(tester.widget<Text>(right5).data, 'Loop use 5.4 L/min');
      final o2 = find.byKey(const Key('tank-loop-use-tank'));
      expect(tester.widget<Text>(o2).data, 'Loop use 1.9 L/min');
    });

    testWidgets('rates stay up while the provider reloads', (tester) async {
      final generation = StateProvider<int>((ref) => 0);
      final row = _row(loopRate: 1.8);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            cylinderSacProvider.overrideWith(
              (ref, id) => ref.watch(generation) == 0
                  ? Future.value([row])
                  : Completer<List<CylinderSac>>().future,
            ),
            tankPressuresProvider.overrideWith(
              (ref, id) async => const <String, List<TankPressurePoint>>{},
            ),
            diveDataSourcesProvider.overrideWith(
              (ref, id) async => const <DiveDataSource>[],
            ),
            transmittersProvider.overrideWith(
              (ref) async => const <Transmitter>[],
            ),
          ],
          child: SingleChildScrollView(
            child: CylindersCard(
              dive: Dive(
                id: 'dive-1',
                diveNumber: 1,
                dateTime: DateTime(2026, 6, 1, 10),
                maxDepth: 30,
                diveMode: DiveMode.ccr,
                tanks: const [_tank],
              ),
              units: const UnitFormatter(AppSettings()),
              settings: const AppSettings(),
              display: GasConsumptionDisplay.both,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Loop use 1.8 L/min'), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(CylindersCard)),
      ).read(generation.notifier).state = 1;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Loop use 1.8 L/min'), findsOneWidget);
    });

    testWidgets('source badges stay up while the provider reloads', (
      tester,
    ) async {
      final generation = StateProvider<int>((ref) => 0);
      final now = DateTime(2026, 6, 1, 10);
      DiveDataSource source(String id, {bool isPrimary = false}) =>
          DiveDataSource(
            id: id,
            diveId: 'dive-1',
            computerId: id,
            isPrimary: isPrimary,
            computerModel: id,
            entryTime: now,
            exitTime: now.add(const Duration(minutes: 45)),
            importedAt: now,
            createdAt: now,
          );
      final sources = [source('c1', isPrimary: true), source('c2')];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            cylinderSacProvider.overrideWith(
              (ref, id) async => const <CylinderSac>[],
            ),
            tankPressuresProvider.overrideWith(
              (ref, id) async => const <String, List<TankPressurePoint>>{},
            ),
            diveDataSourcesProvider.overrideWith(
              (ref, id) => ref.watch(generation) == 0
                  ? Future.value(sources)
                  : Completer<List<DiveDataSource>>().future,
            ),
            transmittersProvider.overrideWith(
              (ref) async => const <Transmitter>[],
            ),
          ],
          child: SingleChildScrollView(
            child: CylindersCard(
              dive: Dive(
                id: 'dive-1',
                diveNumber: 1,
                dateTime: now,
                maxDepth: 30,
                diveMode: DiveMode.ccr,
                tanks: const [
                  DiveTank(
                    id: 'tank',
                    computerId: 'c1',
                    role: TankRole.diluent,
                  ),
                ],
              ),
              units: const UnitFormatter(AppSettings()),
              settings: const AppSettings(),
              display: GasConsumptionDisplay.both,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FieldAttributionBadge), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(CylindersCard)),
      ).read(generation.notifier).state = 1;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FieldAttributionBadge), findsOneWidget);
    });

    testWidgets('Loop use shows under every display preference', (
      tester,
    ) async {
      for (final display in GasConsumptionDisplay.values) {
        await tester.pumpWidget(_card(_row(loopRate: 1.8), display: display));
        await tester.pumpAndSettle();

        expect(find.text('Loop use 1.8 L/min'), findsOneWidget);
      }
    });

    testWidgets('a split cylinder shows Loop use and RMV', (tester) async {
      await tester.pumpWidget(
        _card(
          _row(loopRate: 2.3, sacRate: 2, tankVolume: 7),
          display: GasConsumptionDisplay.rmv,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loop use 2.3 L/min'), findsOneWidget);
      expect(find.text('RMV 14.0 L/min'), findsOneWidget);
    });

    testWidgets('no loop gas and no bailout gas shows no rate', (tester) async {
      await tester.pumpWidget(_card(_row()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Loop use'), findsNothing);
      expect(find.textContaining('RMV'), findsNothing);
      expect(find.textContaining('SAC'), findsNothing);
      expect(find.text('Gas used 108 L'), findsOneWidget);
    });

    testWidgets('Loop use follows imperial units', (tester) async {
      const settings = AppSettings(volumeUnit: VolumeUnit.cubicFeet);
      await tester.pumpWidget(_card(_row(loopRate: 1.8), settings: settings));
      await tester.pumpAndSettle();

      final expected = const UnitFormatter(settings).formatRmv(1.8);
      expect(expected, isNot(contains('L/min')));
      expect(find.text('Loop use $expected'), findsOneWidget);
    });
  });
}
