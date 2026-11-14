import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide CylinderConfigItem;
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/equipment/domain/entities/set_bundle.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/services/trip_set_bundle.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

/// Adding a set to a trip slots the cylinders it carries and lists its
/// lead on the trip's checklist (issue #4525).
void main() {
  late AppDatabase db;
  late TripCylinderRepository cylinders;
  late TripChecklistsRepository checklists;
  late TripChecklistRepository items;
  final now = DateTime.utc(2026, 11, 1);

  CylinderConfigItem cylinder(
    String id, {
    String? label,
    double volume = 11.1,
    double o2 = 32,
  }) => CylinderConfigItem(
    id: id,
    configId: 'cfg',
    label: label,
    tankRole: TankRole.backGas,
    volumeL: volume,
    workingPressureBar: 207,
    tankMaterial: TankMaterial.aluminum,
    o2Percent: o2,
    createdAt: now,
    updatedAt: now,
  );

  SetBundle bundle({
    List<CylinderConfigItem> cylinders = const [],
    bool lead = true,
  }) => SetBundle(
    setId: 's',
    cylinders: cylinders,
    weights: lead
        ? const [
            (weightType: WeightType.belt, amountKg: 5.44, notes: '', label: ''),
          ]
        : const [],
  );

  Future<TripSetBundleResult> apply(
    SetBundle b, {
    Future<String?> Function(List<TripChecklist>)? pick,
  }) => applySetBundleToTrip(
    bundle: b,
    tripId: 'trip1',
    leadTitle: 'Lead: 12.0 lbs',
    cylinders: cylinders,
    checklists: checklists,
    items: items,
    pickChecklist: pick ?? (_) async => fail('nothing to choose between'),
    now: now,
  );

  Future<List<String>> itemTitles() async => [
    for (final i in await items.getAllItemsForTrip('trip1')) i.title,
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    cylinders = TripCylinderRepository();
    checklists = TripChecklistsRepository();
    items = TripChecklistRepository();
  });
  tearDown(tearDownTestDatabase);

  group('tripCylinderDraftsFromBundle', () {
    TripCylinder slot({
      String? equipmentId,
      String label = 'EAN32',
      double volume = 11.1,
    }) => TripCylinder(
      id: 'x',
      tripId: 'trip1',
      equipmentId: equipmentId,
      label: label,
      volume: volume,
      workingPressure: 207,
      material: TankMaterial.aluminum,
      createdAt: now,
      updatedAt: now,
    );

    test('a draft carries the label, size, pressure and material, and no '
        'gear link', () {
      final draft = tripCylinderDraftsFromBundle(
        bundle(cylinders: [cylinder('a', label: 'Left')]),
        tripId: 'trip1',
        existing: const [],
        now: now,
      ).single;
      expect(draft.equipmentId, isNull);
      expect(draft.label, 'Left');
      expect(draft.volume, 11.1);
      expect(draft.workingPressure, 207);
      expect(draft.material, TankMaterial.aluminum);
    });

    test('an unlabelled cylinder is named by its mix', () {
      final draft = tripCylinderDraftsFromBundle(
        bundle(cylinders: [cylinder('a')]),
        tripId: 'trip1',
        existing: const [],
        now: now,
      ).single;
      expect(draft.label, 'EAN32');
    });

    test('cylinders already slotted are left out one for one', () {
      final drafts = tripCylinderDraftsFromBundle(
        bundle(cylinders: [cylinder('a'), cylinder('b')]),
        tripId: 'trip1',
        existing: [slot()],
        now: now,
      );
      expect(drafts, hasLength(1));
    });

    test('a slot that is one of the diver\'s own tanks does not count as '
        'the set\'s cylinder', () {
      final drafts = tripCylinderDraftsFromBundle(
        bundle(cylinders: [cylinder('a')]),
        tripId: 'trip1',
        existing: [slot(equipmentId: 'tank-1')],
        now: now,
      );
      expect(drafts, hasLength(1));
    });
  });

  test('slots the cylinders and adds the lead to the only checklist', () async {
    await checklists.createChecklist(tripId: 'trip1', name: 'Dive gear');
    final result = await apply(
      bundle(cylinders: [cylinder('a'), cylinder('b', o2: 50, volume: 5.7)]),
    );
    expect(result.slotted, 2);
    expect(result.lead, TripLeadOutcome.added);
    expect(await cylinders.getCylindersForTrip('trip1'), hasLength(2));
    expect(await itemTitles(), ['Lead: 12.0 lbs']);
  });

  test('with no checklist the lead is skipped and says so', () async {
    final result = await apply(bundle(cylinders: [cylinder('a')]));
    expect(result.slotted, 1);
    expect(result.lead, TripLeadOutcome.noChecklist);
    expect(await itemTitles(), isEmpty);
  });

  test('with several checklists the diver picks one', () async {
    await checklists.createChecklist(tripId: 'trip1', name: 'Clothing');
    final gear = await checklists.createChecklist(
      tripId: 'trip1',
      name: 'Dive gear',
    );
    final result = await apply(bundle(), pick: (all) async => gear.id);
    expect(result.lead, TripLeadOutcome.added);
    final added = await items.getByChecklistId(gear.id);
    expect(added.single.title, 'Lead: 12.0 lbs');
  });

  test('backing out of the choice adds no lead', () async {
    await checklists.createChecklist(tripId: 'trip1', name: 'Clothing');
    await checklists.createChecklist(tripId: 'trip1', name: 'Dive gear');
    final result = await apply(bundle(), pick: (_) async => null);
    expect(result.lead, TripLeadOutcome.none);
    expect(await itemTitles(), isEmpty);
  });

  test('adding the same set again adds nothing', () async {
    await checklists.createChecklist(tripId: 'trip1', name: 'Dive gear');
    final b = bundle(cylinders: [cylinder('a')]);
    await apply(b);
    final again = await apply(b);
    expect(again.slotted, 0);
    expect(again.lead, TripLeadOutcome.alreadyListed);
    expect(await cylinders.getCylindersForTrip('trip1'), hasLength(1));
    expect(await itemTitles(), hasLength(1));
  });

  test('a set with no lead leaves the checklists alone', () async {
    await checklists.createChecklist(tripId: 'trip1', name: 'Dive gear');
    final result = await apply(bundle(cylinders: [cylinder('a')], lead: false));
    expect(result.lead, TripLeadOutcome.none);
    expect(await itemTitles(), isEmpty);
  });
}
