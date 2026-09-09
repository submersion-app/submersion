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

  Widget host() => testAppInShell(
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: Consumer(
      builder: (context, ref, _) => ElevatedButton(
        onPressed: () async {
          final dive = await diveRepo.getDiveById('d1');
          final pressures = await tankRepo.getTankPressuresForDive('d1');
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
}
