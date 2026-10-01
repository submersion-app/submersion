import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/widgets/tank_series_reassign_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: const [
          domain.DiveTank(
            id: 'tA',
            name: 'O2',
            gasMix: domain.GasMix(o2: 100, he: 0),
            order: 0,
            startPressure: 200,
            endPressure: 170,
            transmitterSerial: '111',
            sourceTankIndex: 0,
          ),
          domain.DiveTank(
            id: 'tB',
            name: 'Dil',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 1,
            startPressure: 210,
            endPressure: 120,
            transmitterSerial: '222',
            sourceTankIndex: 1,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 170.0),
      ],
      'tB': [(timestamp: 0, pressure: 210.0)],
    });
  });
  tearDown(tearDownTestDatabase);

  Widget host({String diveId = 'd1'}) => testAppInShell(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: Consumer(
      builder: (context, ref, _) => ElevatedButton(
        onPressed: () async {
          final dive = await diveRepo.getDiveById(diveId);
          final pressures = await tankRepo.getTankPressuresForDive(diveId);
          if (!context.mounted) return;
          await showTankSeriesReassignSheet(
            context,
            ref,
            dive: dive!,
            tankPressures: pressures,
          );
        },
        child: const Text('OPEN'),
      ),
    ),
  );

  testWidgets('lists each series against its tank and swaps two tanks', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure series'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.textContaining('200 bar'), findsOneWidget);
    expect(find.textContaining('2 readings'), findsOneWidget);
    expect(find.textContaining('Transmitter 111'), findsOneWidget);

    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure series reassigned'), findsOneWidget);
    final db = DatabaseService.instance.database;
    final a = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tA'))).getSingle();
    expect(a.transmitterSerial, '222');
    expect(a.sourceTankIndex, 1);
  });

  testWidgets('undo from the snackbar restores the original', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final db = DatabaseService.instance.database;
    final a = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tA'))).getSingle();
    expect(a.transmitterSerial, '111');
  });

  testWidgets(
    'with three tanks, "Move to" sits under the series summary and moves '
    'the series to the picked tank (#2717)',
    (tester) async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd3',
          dateTime: DateTime.utc(2026, 7, 2, 10),
          tanks: const [
            domain.DiveTank(
              id: 't3A',
              name: 'Back gas',
              gasMix: domain.GasMix(o2: 21, he: 0),
              order: 0,
              transmitterSerial: '111',
              sourceTankIndex: 0,
            ),
            domain.DiveTank(
              id: 't3B',
              name: 'Deco',
              gasMix: domain.GasMix(o2: 50, he: 0),
              order: 1,
              transmitterSerial: '222',
              sourceTankIndex: 1,
            ),
            domain.DiveTank(
              id: 't3C',
              name: 'Stage',
              gasMix: domain.GasMix(o2: 32, he: 0),
              order: 2,
              transmitterSerial: '333',
              sourceTankIndex: 2,
            ),
          ],
        ),
      );
      await tankRepo.insertTankPressures('d3', {
        't3A': [
          (timestamp: 0, pressure: 200.0),
          (timestamp: 600, pressure: 150.0),
        ],
      });

      await tester.pumpWidget(host(diveId: 'd3'));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('Swap'), findsNothing);
      final moveTo = find.widgetWithText(TextButton, 'Move to');
      expect(moveTo, findsOneWidget);
      final summary = tester.getRect(find.textContaining('2 readings'));
      expect(tester.getRect(moveTo).top, greaterThanOrEqualTo(summary.bottom));

      await tester.tap(moveTo);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SimpleDialogOption, 'Stage'));
      await tester.pumpAndSettle();

      expect(find.text('Pressure series reassigned'), findsOneWidget);
      final db = DatabaseService.instance.database;
      final moved = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('t3A'))).getSingle();
      expect(moved.transmitterSerial, '333');
      expect(moved.sourceTankIndex, 2);
    },
  );
}
