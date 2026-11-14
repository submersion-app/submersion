import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    hide CylinderConfigItem, EquipmentSet, Trip;
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

/// Adding a set to a trip through the gear tab's Add sheet also slots the
/// cylinders the set carries and lists its lead on the trip's checklist
/// (issue #4525). The data function under it has its own test; this drives
/// the sheet, the checklist question and the message.
void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 1);

  setUp(() async {
    db = await setUpTestDatabase();
    // The trip row itself is not needed: the tab takes the entity.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Tester',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
            isDefault: const Value(true),
          ),
        );
    await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: 'reg',
        diverId: 'd1',
        name: 'Apeks XTX50',
        type: EquipmentType.regulator,
      ),
      notify: false,
    );
    final preset = await WeightPresetRepository().createPreset(
      diverId: 'd1',
      displayName: 'Belt',
      entries: const [
        (weightType: WeightType.belt, amountKg: 4.0, notes: '', label: ''),
      ],
    );
    final configs = CylinderConfigRepository();
    final al80 = await configs.createConfig(diverId: 'd1', name: 'AL80');
    await configs.saveItems(al80, [
      CylinderConfigItem(
        id: '',
        configId: al80,
        tankRole: TankRole.backGas,
        volumeL: 11.1,
        workingPressureBar: 207,
        o2Percent: 32,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 'rig',
        diverId: 'd1',
        name: 'Reef rig',
        equipmentIds: const ['reg'],
        weightPresetIds: [preset.id],
        cylinderConfigIds: [al80],
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> addSet(WidgetTester tester, {String named = 'Reef rig'}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final today = DateTime.now();
    final trip = Trip(
      id: 'trip1',
      name: 'Bonaire',
      startDate: DateTime(today.year, today.month, today.day + 10),
      endDate: DateTime(today.year, today.month, today.day + 15),
      createdAt: today,
      updatedAt: today,
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(body: TripGearTab(trip: trip)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(named).last);
    await tester.pumpAndSettle();
  }

  Future<List<String>> leadItems({String? checklistId}) async {
    final items = checklistId == null
        ? await TripChecklistRepository().getAllItemsForTrip('trip1')
        : await TripChecklistRepository().getByChecklistId(checklistId);
    return [for (final item in items) item.title];
  }

  testWidgets('slots the set\'s cylinder and lists its lead on the trip\'s '
      'only checklist', (tester) async {
    await TripChecklistsRepository().createChecklist(
      tripId: 'trip1',
      name: 'Dive gear',
    );
    await addSet(tester);

    final slots = await TripCylinderRepository().getCylindersForTrip('trip1');
    expect(slots.single.label, 'EAN32');
    expect(slots.single.volume, closeTo(11.1, 1e-9));
    // In the diver's weight unit, kilograms by default.
    expect(await leadItems(), ['Lead: 4.0 kg']);
    // The regulator, the cylinder slot and the lead item.
    expect(find.text('Packed 3 items from Reef rig'), findsOneWidget);
  });

  // The lead is the one thing this set puts on the trip, so the message
  // must not say everything was already packed.
  testWidgets('a set with only lead reports the lead item it added', (
    tester,
  ) async {
    final presets = await WeightPresetRepository().getPresets(diverId: 'd1');
    await EquipmentSetRepository().createSet(
      EquipmentSet(
        id: 'lead',
        diverId: 'd1',
        name: 'Lead only',
        weightPresetIds: [presets.single.id],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await TripChecklistsRepository().createChecklist(
      tripId: 'trip1',
      name: 'Dive gear',
    );
    await addSet(tester, named: 'Lead only');

    expect(await leadItems(), ['Lead: 4.0 kg']);
    expect(find.text('Packed 1 item from Lead only'), findsOneWidget);
  });

  testWidgets('with several checklists it asks which one takes the lead', (
    tester,
  ) async {
    final checklists = TripChecklistsRepository();
    await checklists.createChecklist(tripId: 'trip1', name: 'Clothing');
    final gear = await checklists.createChecklist(
      tripId: 'trip1',
      name: 'Dive gear',
    );
    await addSet(tester);

    expect(find.text('Add the lead to which checklist?'), findsOneWidget);
    await tester.tap(find.byKey(Key('trip-lead-checklist-${gear.id}')));
    await tester.pumpAndSettle();
    expect(await leadItems(checklistId: gear.id), ['Lead: 4.0 kg']);
    expect(await leadItems(), hasLength(1));
  });

  testWidgets('with no checklist the message says the lead was left off', (
    tester,
  ) async {
    await addSet(tester);

    expect(await leadItems(), isEmpty);
    expect(
      find.textContaining('Lead was not added: this trip has no checklist.'),
      findsOneWidget,
    );
    // The cylinder is still slotted.
    expect(
      await TripCylinderRepository().getCylindersForTrip('trip1'),
      hasLength(1),
    );
  });
}
