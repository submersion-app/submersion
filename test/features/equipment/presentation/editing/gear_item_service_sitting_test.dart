import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A gear item's service clocks and service records, held in its page's
/// sitting (issue #4527, phase 3, plan 6).
void main() {
  late EquipmentRepository items;
  late ServiceScheduleRepository schedules;
  late ServiceRecordRepository records;
  final changeLog = ChangeLogRepository();
  final at = DateTime(2026, 1, 1);

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    items = EquipmentRepository();
    schedules = ServiceScheduleRepository();
    records = ServiceRecordRepository();
    await db.customStatement(
      "INSERT INTO service_kinds (id, name, default_interval_days, "
      "created_at, updated_at) VALUES "
      "('k-annual', 'Annual service', 365, 0, 0), "
      "('k-o2', 'O2 clean', 730, 0, 0)",
    );
    await items.createEquipment(
      EquipmentItem(
        id: 'g1',
        name: 'Apex',
        type: EquipmentType.regulator,
        lastServiceDate: DateTime(2025, 1, 1),
      ),
    );
    // The clocks built-in kinds attach to a new regulator are not this
    // test's.
    await db.customStatement('DELETE FROM service_schedules');
    await schedules.createSchedule(
      ServiceSchedule(
        id: 's1',
        equipmentId: 'g1',
        serviceKindId: 'k-annual',
        createdAt: at,
        updatedAt: at,
      ),
    );
    await records.createRecord(
      ServiceRecord(
        id: 'r1',
        equipmentId: 'g1',
        serviceCategory: ServiceCategory.annual,
        serviceKindId: 'k-annual',
        serviceDate: DateTime(2025, 1, 1),
        createdAt: at,
        updatedAt: at,
      ),
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> stored() async => (await items.getEquipmentById('g1'))!;

  Future<EditSession<EquipmentItem>> sitting() async {
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    await gearItemClocksList.load(session);
    await gearItemServiceRecordsList.load(session);
    return session;
  }

  Future<void> save(EditSession<EquipmentItem> session) =>
      GearItemEditSaveService(items, GearPhotoRepository()).save(
        equipmentId: 'g1',
        apply: (s) => gearItemToSave(s, session.applyTo(s)),
        changedCardIds: session.changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  ServiceRecord logged() => ServiceRecord(
    id: '',
    equipmentId: 'g1',
    serviceCategory: ServiceCategory.annual,
    serviceKindId: 'k-annual',
    serviceDate: DateTime(2026, 5, 1),
    createdAt: at,
    updatedAt: at,
  );

  test(
    'a clock added in the sitting is created at Save with its interval',
    () async {
      final session = await sitting();
      holdClock(
        session,
        ServiceSchedule(
          id: '',
          equipmentId: 'g1',
          serviceKindId: 'k-o2',
          intervalDays: 400,
          createdAt: at,
          updatedAt: at,
        ),
      );

      expect(await schedules.getSchedulesForEquipment('g1'), hasLength(1));
      await save(session);

      final after = await schedules.getSchedulesForEquipment('g1');
      expect(after, hasLength(2));
      expect(
        after.singleWhere((s) => s.serviceKindId == 'k-o2').intervalDays,
        400,
      );
    },
  );

  test('pause and resume back to stored write nothing', () async {
    final session = await sitting();
    final clock = gearItemClocksList.current(session)!.single;

    holdClock(session, clock.copyWith(enabled: false));
    expect(session.changedCardIds, {'serviceClocks'});
    holdClock(session, clock.copyWith(enabled: true));

    expect(session.isDirty, isFalse);
  });

  test('a service logged from a clock, then Cancel: no record, last service '
      'date unchanged', () async {
    final session = await sitting();
    holdServiceRecord(session, logged());
    expect(session.changedCardIds, {'serviceHistory'});

    // Cancel: the sitting ends unsaved (disposed at tear-down).

    expect(await records.getRecordsForEquipment('g1'), hasLength(1));
    expect((await stored()).lastServiceDate, DateTime(2025, 1, 1));
  });

  test(
    'the same, then Save: one entry, and the last service date refreshed',
    () async {
      final session = await sitting();
      holdServiceRecord(session, logged());

      await save(session);

      expect(await records.getRecordsForEquipment('g1'), hasLength(2));
      expect((await stored()).lastServiceDate, DateTime(2026, 5, 1));
      await changeLog.settleAll();
      final ops = await DatabaseService.instance.database
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(
        ops.single.data['label'],
        'record_edit:equipment:g1:serviceHistory',
      );
    },
  );

  test('a clock removed and a record edited are one entry, and reverting '
      'restores both', () async {
    final session = await sitting();
    removeHeldClock(session, 's1');
    final record = gearItemServiceRecordsList.current(session)!.single;
    holdServiceRecord(session, record.copyWith(notes: 'New o-rings'));

    await save(session);

    expect(await schedules.getSchedulesForEquipment('g1'), isEmpty);
    expect((await records.getRecordById('r1'))!.notes, 'New o-rings');
    await changeLog.settleAll();
    final ops = await DatabaseService.instance.database
        .customSelect('SELECT id FROM change_log_operations')
        .get();
    expect(ops, hasLength(1));

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single.data['id']! as String),
    );

    expect(await schedules.getSchedulesForEquipment('g1'), hasLength(1));
    expect((await records.getRecordById('r1'))!.notes, '');
  });

  test('a new record goes first with an id of its own', () {
    final rows = serviceRecordsAfterSave([
      logged().copyWith(id: 'old'),
    ], logged());

    expect(rows, hasLength(2));
    expect(rows.first.id, isNot(anyOf('', 'old')));
  });
  test('a clock merged into one of its kind keeps that one baseline only '
      'when it sets none', () {
    final there = ServiceSchedule(
      id: 'auto',
      equipmentId: 'g1',
      serviceKindId: 'k-annual',
      anchorDate: DateTime(2025, 6, 1),
      anchorSetAt: at,
      createdAt: at,
      updatedAt: at,
    );
    final added = ServiceSchedule(
      id: 'held',
      equipmentId: 'g1',
      serviceKindId: 'k-annual',
      intervalDays: 99,
      createdAt: at,
      updatedAt: at,
    );

    final merged = clockMergedInto(there, added);
    final dated = clockMergedInto(
      there,
      added.copyWith(anchorDate: DateTime(2026, 2, 1)),
    );

    expect(merged.id, 'auto');
    expect(merged.intervalDays, 99);
    expect(merged.anchorDate, DateTime(2025, 6, 1));
    expect(dated.anchorDate, DateTime(2026, 2, 1));
  });
}
