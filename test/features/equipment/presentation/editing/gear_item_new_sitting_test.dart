import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

import '../../../../helpers/test_database.dart';

/// A clone service whose extras fail at [failing].
class _FailingClone extends EquipmentCloneService {
  _FailingClone(this.failing);

  final Set<CloneExtrasStep> failing;

  @override
  Future<Set<CloneExtrasStep>> copyExtras({
    required String sourceId,
    required String cloneId,
    required EquipmentType cloneType,
    required String? diverId,
  }) async => failing;
}

/// A clone service that keeps the diver each copy of extras was made for.
class _RecordingClone extends EquipmentCloneService {
  final diverIds = <String?>[];

  @override
  Future<Set<CloneExtrasStep>> copyExtras({
    required String sourceId,
    required String cloneId,
    required EquipmentType cloneType,
    required String? diverId,
  }) async {
    diverIds.add(diverId);
    return const {};
  }
}

/// A new gear item's sitting (issue #4527, phase 3, plan 11): its seed, the
/// device lists' and Add part's seeds, and a clone's copy.
void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    equipment = EquipmentRepository();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d1'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        defaultCurrencyProvider.overrideWithValue('EUR'),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> seed() => newGearItemSeed(container.read, id: 'n1');

  test(
    'a seed is a regulator, active, in the default currency, no dot',
    () async {
      final item = await seed();

      expect(item.id, 'n1');
      expect(item.diverId, 'd1');
      expect(item.type, EquipmentType.regulator);
      expect(item.status, EquipmentStatus.active);
      expect(item.purchaseCurrency, 'EUR');
      expect(EditSession(item, isNew: true).isDirty, isFalse);
    },
  );

  test('a type and a serial from the device lists are changes', () async {
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);

    await applyNewGearItemPrefill(
      session,
      request: NewGearItemRequest.fromQuery(const {
        'type': 'transmitter',
        'serial': ' 0042 ',
      }),
      cloneService: EquipmentCloneService(),
    );

    expect(session.working.type, EquipmentType.transmitter);
    expect(session.working.serialNumber, '0042');
    expect(session.changedCardIds, containsAll(['header', 'details']));
  });

  test("a part's host is a change, dropped at Save for a type it cannot "
      'hold', () async {
    final host = await equipment.createEquipment(
      const EquipmentItem(
        id: 'rb',
        diverId: 'd1',
        name: 'Rebreather',
        type: EquipmentType.rebreather,
      ),
    );
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);
    await applyNewGearItemPrefill(
      session,
      request: NewGearItemRequest(parentId: host.id),
      cloneService: EquipmentCloneService(),
    );
    expect(session.working.parentEquipmentId, host.id);

    expect(
      await gearParentToSave(
        equipment,
        type: EquipmentType.o2Cell,
        parentId: host.id,
        diverId: 'd1',
      ),
      host.id,
    );
    expect(
      await gearParentToSave(
        equipment,
        type: EquipmentType.regulator,
        parentId: host.id,
        diverId: 'd1',
      ),
      isNull,
    );
    expect(
      await gearParentToSave(
        equipment,
        type: EquipmentType.o2Cell,
        parentId: 'gone',
        diverId: 'd1',
      ),
      isNull,
    );
  });

  test('a clone is named as a copy, with no serial, and reads null when '
      'gone', () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
        serialNumber: 'T-1',
        notes: 'Blue',
      ),
    );

    final clone = await readGearClone(
      container.read,
      'src',
      copyName: (n) => '$n (copy)',
    );

    expect(clone?.copy.name, 'Steel 12 (copy)');
    expect(clone?.copy.serialNumber, isNull);
    expect(clone?.copy.notes, 'Blue');
    expect(
      await readGearClone(container.read, 'gone', copyName: (n) => n),
      isNull,
    );
  });

  Future<EditSession<EquipmentItem>> cloneSitting(
    EquipmentCloneService cloneService,
  ) async {
    final clone = await readGearClone(
      container.read,
      'src',
      copyName: (n) => '$n (copy)',
    );
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);
    await applyNewGearItemPrefill(
      session,
      clone: clone,
      cloneService: cloneService,
    );
    return session;
  }

  Future<EquipmentItem> create(EditSession<EquipmentItem> session) =>
      GearItemEditSaveService(equipment, GearPhotoRepository()).create(
        item: gearItemToSave(session.stored, session.applyTo(session.stored)),
        changedCardIds: session.changedCardIds,
        alsoWrite: heldWritesForCreate(session),
      );

  test("a clone of a tank keeps one clock of each kind, the clone's, "
      'without a baseline', () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );
    final schedules = ServiceScheduleRepository();
    final sourceKinds = {
      for (final c in await schedules.getSchedulesForEquipment('src'))
        c.serviceKindId,
    };
    expect(sourceKinds, isNotEmpty);

    final created = await create(await cloneSitting(EquipmentCloneService()));

    final clocks = await schedules.getSchedulesForEquipment(created.id);
    expect({for (final c in clocks) c.serviceKindId}, sourceKinds);
    expect(clocks, hasLength(sourceKinds.length));
    expect(clocks.every((c) => c.anchorDate == null), isTrue);
    expect(created.name, 'Steel 12 (copy)');
  });

  test('a failed set membership leaves no item, clock, move or tag', () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );

    await expectLater(
      create(await cloneSitting(_FailingClone({CloneExtrasStep.sets}))),
      throwsStateError,
    );

    expect(await equipment.getEquipmentById('n1'), isNull);
    expect(
      await ServiceScheduleRepository().getSchedulesForEquipment('n1'),
      isEmpty,
    );
  });
  // The page tracks the prefill, so Save waits for it (issue #4527, plan
  // 11): the prefill must not wait on itself.
  test("a tracked clone prefill ends, with the source's own tags", () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      "applies_to_equipment) VALUES ('t1', 'd1', 'Travel', 0, 0, 1)",
    );
    await EquipmentTagRepository().replaceTags('src', const ['t1']);
    final clone = await readGearClone(
      container.read,
      'src',
      copyName: (n) => '$n (copy)',
    );
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);
    gearItemTagsList.load(session);

    session.track(
      applyNewGearItemPrefill(
        session,
        clone: clone,
        cloneService: EquipmentCloneService(),
      ),
    );
    await session.settled().timeout(const Duration(seconds: 2));

    expect([for (final t in gearItemTagsList.current(session)!) t.id], ['t1']);
  });
  test("a clone's place is its held move, shown on Location and written "
      'once', () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );
    final shop = await EquipmentLocationRepository().createLocation(
      diverId: 'd1',
      name: 'Shop',
      kind: EquipmentLocationKind.serviceShop,
    );
    final moves = EquipmentLocationMoveRepository();
    await moves.recordMoves(
      equipmentIds: const ['src'],
      locationId: shop.id,
      movedAt: DateTime(2026),
    );

    final session = await cloneSitting(EquipmentCloneService());

    expect(
      heldGearItemMove(session)?.pick,
      isA<PlacePick>().having((p) => p.location.id, 'place', shop.id),
    );
    final created = await create(session);
    expect(
      [for (final m in await moves.getMovesFor(created.id)) m.locationId],
      [shop.id],
    );
  });

  test("a clone's extras are copied for the diver it is created for, the "
      'seed having none', () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'src',
        diverId: 'd1',
        name: 'Steel 12',
        type: EquipmentType.tank,
      ),
    );
    final clone = await readGearClone(
      container.read,
      'src',
      copyName: (n) => '$n (copy)',
    );
    final recording = _RecordingClone();
    // The diver could not be read as the page opened; Save takes it.
    final session = EditSession(
      const EquipmentItem(id: 'n1', name: '', type: EquipmentType.regulator),
      isNew: true,
    );
    addTearDown(session.dispose);
    await applyNewGearItemPrefill(
      session,
      clone: clone,
      cloneService: recording,
    );

    await GearItemEditSaveService(equipment, GearPhotoRepository()).create(
      item: gearItemToSave(
        session.stored,
        session.applyTo(session.stored),
      ).copyWith(diverId: 'd1'),
      changedCardIds: session.changedCardIds,
      alsoWrite: heldWritesForCreate(session),
    );

    expect(recording.diverIds, ['d1']);
  });
  test('a clock added to a new item, of a kind Save attaches itself, is one '
      "clock with the diver's settings", () async {
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'probe',
        diverId: 'd1',
        name: 'Probe',
        type: EquipmentType.regulator,
      ),
    );
    final schedules = ServiceScheduleRepository();
    final attached = await schedules.getSchedulesForEquipment('probe');
    expect(attached, isNotEmpty);
    final kind = attached.first.serviceKindId;
    final session = EditSession(await seed(), isNew: true);
    addTearDown(session.dispose);
    final at = DateTime(2026);
    gearItemClocksList
      ..loadNone(session)
      ..set(session, [
        ServiceSchedule(
          id: 'held',
          equipmentId: 'n1',
          serviceKindId: kind,
          intervalDays: 99,
          createdAt: at,
          updatedAt: at,
        ),
      ]);

    final created = await create(session);

    final ofKind = [
      for (final c in await schedules.getSchedulesForEquipment(created.id))
        if (c.serviceKindId == kind) c,
    ];
    expect(ofKind, hasLength(1));
    expect(ofKind.single.intervalDays, 99);
  });
}
