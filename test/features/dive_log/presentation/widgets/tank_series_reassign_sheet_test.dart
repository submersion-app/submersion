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

  Widget host({
    String diveId = 'd1',
    Future<void> Function(String a, String b)? onExchange,
    domain.Dive Function(domain.Dive stored)? shape,
  }) => testAppInShell(
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
            dive: shape == null ? dive! : shape(dive!),
            tankPressures: pressures,
            onExchange: onExchange ?? (a, b) async {},
          );
        },
        child: const Text('OPEN'),
      ),
    ),
  );

  testWidgets('lists each series against its tank', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Pressure series'), findsOneWidget);
    expect(find.text('O2'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
    expect(find.textContaining('200 bar'), findsOneWidget);
    expect(find.textContaining('2 readings'), findsOneWidget);
    expect(find.textContaining('Transmitter 111'), findsOneWidget);

    expect(find.text('Swap'), findsOneWidget);
  });

  testWidgets('handed an exchange, the sheet asks it and writes nothing', (
    tester,
  ) async {
    final asked = <(String, String)>[];
    await tester.pumpWidget(
      host(onExchange: (a, b) async => asked.add((a, b))),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    expect(asked, [('tA', 'tB')]);
    expect(find.text('Pressure series reassigned'), findsNothing);
    final db = DatabaseService.instance.database;
    final a = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tA'))).getSingle();
    expect(a.transmitterSerial, '111');
  });

  testWidgets(
    'with three tanks, "Move to" sits under the series summary and asks to '
    'move the series to the picked tank (#2717)',
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

      final asked = <(String, String)>[];
      await tester.pumpWidget(
        host(diveId: 'd3', onExchange: (a, b) async => asked.add((a, b))),
      );
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

      expect(asked, [('t3A', 't3C')]);
    },
  );

  testWidgets('handed an exchange, "Move to" offers the cylinders the sheet '
      'was given, not the dive as stored', (tester) async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd4',
        dateTime: DateTime.utc(2026, 7, 3, 10),
        tanks: const [
          domain.DiveTank(id: 't4A', name: 'Back gas', order: 0),
          domain.DiveTank(id: 't4B', name: 'Deco', order: 1),
          domain.DiveTank(id: 't4C', name: 'Stage', order: 2),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d4', {
      't4A': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 150.0),
      ],
    });
    final asked = <(String, String)>[];

    await tester.pumpWidget(
      host(
        diveId: 'd4',
        onExchange: (a, b) async => asked.add((a, b)),
        // The sitting removed the stage.
        shape: (d) => d.copyWith(
          tanks: [
            for (final t in d.tanks)
              if (t.id != 't4C') t,
          ],
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Move to'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SimpleDialogOption, 'Stage'), findsNothing);
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'Deco'));
    await tester.pumpAndSettle();
    expect(asked, [('t4A', 't4B')]);
  });
}
