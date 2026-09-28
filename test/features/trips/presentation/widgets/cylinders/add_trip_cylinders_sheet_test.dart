import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/add_trip_cylinders_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late String tripId;
  final al80 = TankPresetEntity.fromBuiltIn(TankPresets.byName('al80')!);

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    List<TripCylinder> existing = const [],
    List<EquipmentItem> equipment = const [],
    Future<List<TankPresetEntity>>? presets,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          tankPresetsProvider.overrideWith(
            (ref) => presets ?? Future.value([al80]),
          ),
          activeEquipmentProvider.overrideWith((ref) async => equipment),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAddTripCylindersSheet(
                  context,
                  tripId: tripId,
                  existing: existing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  testWidgets('adds numbered rental slots with the preset specs', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('How many'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final slots = await repo.getCylindersForTrip(tripId);
    expect(slots.map((s) => s.label), ['Truck 1', 'Truck 2', 'Truck 3']);
    expect(slots.first.volume, al80.volumeLiters);
    expect(slots.first.workingPressure, al80.workingPressureBar);
    expect(slots.first.material, al80.material);
    expect(slots.first.presetName, 'al80');
    expect(slots.map((s) => s.sortOrder), [0, 1, 2]);
  });

  testWidgets('numbering continues after the slots already on the trip', (
    tester,
  ) async {
    final now = DateTime.now();
    final first = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        label: 'Truck 1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(tester, existing: [first]);
    await tester.enterText(field('How many'), '2');
    await tester.enterText(field('Label prefix'), 'Car');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final labels = (await repo.getCylindersForTrip(tripId)).map((s) => s.label);
    expect(labels, ['Truck 1', 'Car 2', 'Car 3']);
  });

  testWidgets('refuses a count outside 1 to 20', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(field('How many'), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a number from 1 to 20.'), findsOneWidget);
    expect(await repo.getCylindersForTrip(tripId), isEmpty);
  });

  testWidgets('adds an owned cylinder and hides the ones already added', (
    tester,
  ) async {
    final equipmentRepo = EquipmentRepository();
    final mine = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    );
    final taken = await equipmentRepo.createEquipment(
      const EquipmentItem(id: '', name: 'Old AL80', type: EquipmentType.tank),
    );
    final now = DateTime.now();
    final existing = await repo.createCylinder(
      TripCylinder(
        id: '',
        tripId: tripId,
        equipmentId: taken.id,
        label: 'Old AL80',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpAndOpen(tester, existing: [existing], equipment: [mine, taken]);

    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('owned-${taken.id}')), findsNothing);
    await tester.tap(find.byKey(Key('owned-${mine.id}')));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final slots = await repo.getCylindersForTrip(tripId);
    expect(slots.map((s) => s.label), ['Old AL80', 'My HP100']);
    expect(slots.last.equipmentId, mine.id);
  });

  testWidgets('refuses an owned save with nothing picked', (tester) async {
    final mine = await EquipmentRepository().createEquipment(
      const EquipmentItem(id: '', name: 'My HP100', type: EquipmentType.tank),
    );
    await pumpAndOpen(tester, equipment: [mine]);
    await tester.tap(find.text('From my equipment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one cylinder.'), findsOneWidget);
    expect(await repo.getCylindersForTrip(tripId), isEmpty);
  });

  test('rental labels never repeat one still on the board', () {
    // Truck 2 was deleted: the count is 3 but Truck 4 is taken.
    expect(tripRentalLabels('Truck', 1, ['Truck 1', 'Truck 3', 'Truck 4']), [
      'Truck 5',
    ]);
    expect(tripRentalLabels('Car', 2, ['Truck 1']), ['Car 2', 'Car 3']);
    expect(tripRentalLabels('', 2, ['1', '5']), ['6', '7']);
  });

  testWidgets('saving rentals waits for the presets to load', (tester) async {
    final pending = Completer<List<TankPresetEntity>>();
    await pumpAndOpen(tester, presets: pending.future, settle: false);
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save().onPressed, isNull);

    pending.complete([al80]);
    await tester.pumpAndSettle();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('rentals cannot be saved when the presets fail to load', (
    tester,
  ) async {
    final failing = Completer<List<TankPresetEntity>>();
    await pumpAndOpen(tester, presets: failing.future, settle: false);
    failing.completeError(StateError('presets gone'));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
