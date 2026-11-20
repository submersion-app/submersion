import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
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
}
