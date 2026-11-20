import 'package:flutter_test/flutter_test.dart';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A gear item page's sitting is written as one History entry, and writes
/// only what it changed (issue #4527, phase 3, plan 6).
void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late GearItemEditSaveService service;
  final changeLog = ChangeLogRepository();
  final specKey = EquipmentAttributeCatalog.attributesFor(
    EquipmentType.regulator,
  ).first.key;
  final otherSpecKey = EquipmentAttributeCatalog.attributesFor(
    EquipmentType.regulator,
  )[1].key;

  Future<EquipmentItem> stored() async =>
      (await equipment.getEquipmentById('g1'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({EquipmentItem before, EquipmentItem after})?> save(
    EditSession<EquipmentItem> session, {
    Future<void> Function()? alsoWrite,
  }) => service.save(
    equipmentId: session.stored.id,
    apply: (s) => gearItemToSave(s, session.applyTo(s)),
    changedCardIds: session.changedCardIds,
    alsoWrite: alsoWrite,
    alsoWriteIsAChange: alsoWrite != null,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    equipment = EquipmentRepository();
    service = GearItemEditSaveService(equipment, GearPhotoRepository());
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
    await equipment.createEquipment(
      EquipmentItem(
        id: 'g1',
        diverId: 'd1',
        name: 'Apex',
        type: EquipmentType.regulator,
        brand: 'Apex',
        model: 'XTX',
        serialNumber: 'A1',
        purchaseDate: DateTime(2024, 5, 1),
        purchasePrice: 400,
        purchaseCurrency: 'EUR',
        notes: 'Calm',
        lastServiceDate: DateTime(2025, 1, 1),
        serviceIntervalDays: 365,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'g1',
            key: specKey,
            valueText: 'one',
            valueNum: 1,
          ),
          const EquipmentAttribute(
            id: 'c1',
            equipmentId: 'g1',
            key: 'Hose',
            isCustom: true,
            valueText: 'blue',
          ),
        ],
      ),
    );
    await db.customStatement(
      "INSERT INTO dive_computers (id, diver_id, name, equipment_id, "
      "created_at, updated_at) VALUES ('c1', 'd1', 'Apex', 'g1', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO media (id, equipment_id, file_path, created_at, "
      "updated_at) VALUES ('p1', 'g1', '/p1.jpg', 0, 0)",
    );
    // What setup wrote is not a sitting.
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a brand change as one History entry', () async {
    final session = EditSession(await stored())
      ..set(gearBrandField, 'Scubapro');

    final result = await save(session);

    expect((await stored()).brand, 'Scubapro');
    expect(result!.before.brand, 'Apex');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:equipment:g1:details');
  });

  // One case per column the item's update writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save.
  final census = <String, ({String sql, bool Function(EquipmentItem) kept})>{
    'name': (
      sql: "UPDATE equipment SET name = 'Renamed'",
      kept: (e) => e.name == 'Renamed',
    ),
    'type': (
      sql: "UPDATE equipment SET type = 'bcd'",
      kept: (e) => e.type == EquipmentType.bcd,
    ),
    'brand': (
      sql: "UPDATE equipment SET brand = 'Newer'",
      kept: (e) => e.brand == 'Newer',
    ),
    'model': (
      sql: "UPDATE equipment SET model = 'Newer'",
      kept: (e) => e.model == 'Newer',
    ),
    'serial': (
      sql: "UPDATE equipment SET serial_number = 'B2'",
      kept: (e) => e.serialNumber == 'B2',
    ),
    'status': (
      sql: "UPDATE equipment SET status = 'inService'",
      kept: (e) => e.status == EquipmentStatus.inService,
    ),
    'active flag': (
      sql: 'UPDATE equipment SET is_active = 0',
      kept: (e) => !e.isActive,
    ),
    'purchase date': (
      sql: 'UPDATE equipment SET purchase_date = 5000',
      kept: (e) => e.purchaseDate?.millisecondsSinceEpoch == 5000,
    ),
    'price': (
      sql: 'UPDATE equipment SET purchase_price = 99',
      kept: (e) => e.purchasePrice == 99,
    ),
    'currency': (
      sql: "UPDATE equipment SET purchase_currency = 'GBP'",
      kept: (e) => e.purchaseCurrency == 'GBP',
    ),
    'reminders': (
      sql:
          "UPDATE equipment SET custom_reminder_enabled = 1, "
          "custom_reminder_days = '[3]'",
      kept: (e) =>
          e.customReminderEnabled == true &&
          (e.customReminderDays ?? const []).single == 3,
    ),
    'parent': (
      sql: "UPDATE equipment SET parent_equipment_id = 'g0'",
      kept: (e) => e.parentEquipmentId == 'g0',
    ),
    'last service date': (
      sql: 'UPDATE equipment SET last_service_date = 7000',
      kept: (e) => e.lastServiceDate?.millisecondsSinceEpoch == 7000,
    ),
    'service interval': (
      sql: 'UPDATE equipment SET service_interval_days = 30',
      kept: (e) => e.serviceIntervalDays == 30,
    ),
    'notes': (
      sql: "UPDATE equipment SET notes = 'Newer'",
      kept: (e) => e.notes == 'Newer',
    ),
  };
  for (final MapEntry(key: column, value: change) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      if (column == 'parent') {
        await equipment.createEquipment(
          const EquipmentItem(
            id: 'g0',
            diverId: 'd1',
            name: 'Host',
            type: EquipmentType.rebreather,
          ),
        );
      }
      // The sitting changes a field other than the one changed underneath.
      final notes = column == 'notes';
      final session = EditSession(await stored());
      if (notes) {
        session.set(gearNameField, 'Edited');
      } else {
        session.set(gearNotesField, 'Edited');
      }
      await db.customStatement('${change.sql} WHERE id = ?', ['g1']);

      await save(session);

      final after = await stored();
      expect(change.kept(after), isTrue, reason: column);
      expect(notes ? after.name : after.notes, 'Edited');
    });
  }

  test(
    'an attribute the sitting did not touch keeps its newer value',
    () async {
      final session = EditSession(await stored())
        ..set(
          gearAttributeField(otherSpecKey),
          EquipmentAttribute.curated(
            equipmentId: 'g1',
            key: otherSpecKey,
            valueText: 'two',
            valueNum: 2,
          ),
        );
      await db.customStatement(
        "UPDATE equipment_attributes SET value_text = 'newer' "
        "WHERE equipment_id = 'g1' AND attr_key = ?",
        [specKey],
      );

      await save(session);

      final after = await stored();
      expect(after.attrText(specKey), 'newer');
      expect(after.attrText(otherSpecKey), 'two');
    },
  );

  test('the name is mirrored to the dive computer in the same entry', () async {
    final session = EditSession(await stored())..set(gearNameField, 'Perdix');

    await save(session);

    final row = await db
        .customSelect("SELECT name FROM dive_computers WHERE id = 'c1'")
        .getSingle();
    expect(row.data['name'], 'Perdix');
    expect(await operations(), hasLength(1));
  });

  test('a new cover is set after the held writes', () async {
    final order = <String>[];
    final session = EditSession(await stored())..set(gearCoverField, 'p2');

    await save(
      session,
      alsoWrite: () async {
        order.add('held');
        // The photo the sitting imported, written by a held write.
        await db.customStatement(
          "INSERT INTO media (id, equipment_id, file_path, created_at, "
          "updated_at) VALUES ('p2', 'g1', '/p2.jpg', 0, 0)",
        );
      },
    );

    expect(order, ['held']);
    expect((await stored()).coverMediaId, 'p2');
    expect(await operations(), hasLength(1));
  });

  test('a cover cleared in the sitting is cleared', () async {
    await GearPhotoRepository().setCover('g1', 'p1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final session = EditSession(await stored())..set(gearCoverField, null);

    await save(session);

    expect((await stored()).coverMediaId, isNull);
  });

  test('a type the custom fields survive keeps them', () async {
    final session = EditSession(await stored())
      ..set(gearTypeField, EquipmentType.bcd);

    await save(session);

    final after = await stored();
    expect(after.type, EquipmentType.bcd);
    expect(after.attributes.where((a) => a.isCustom).single.key, 'Hose');
  });

  test('unchanged returns null', () async {
    final session = EditSession(await stored());

    expect(await save(session), isNull);
    expect(await operations(), isEmpty);
  });

  test('an item that has gone throws', () async {
    final session = EditSession(await stored())..set(gearBrandField, 'X');
    await db.customStatement("DELETE FROM dive_computers WHERE id = 'c1'");
    await db.customStatement("DELETE FROM media WHERE id = 'p1'");
    await db.customStatement(
      "DELETE FROM equipment_attributes WHERE equipment_id = 'g1'",
    );
    await db.customStatement("DELETE FROM equipment WHERE id = 'g1'");

    expect(save(session), throwsStateError);
  });

  /// A new gear item's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    EquipmentItem fresh({String id = 'n1'}) => EquipmentItem(
      id: id,
      diverId: 'd1',
      name: 'Backup reg',
      type: EquipmentType.regulator,
    );

    test('creates the item with its id, as one History entry', () async {
      final created = await service.create(
        item: fresh(),
        changedCardIds: const ['header'],
      );

      expect(created.id, 'n1');
      expect((await equipment.getEquipmentById('n1'))?.name, 'Backup reg');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:equipment:n1:header');
    });

    test("the type's clocks are attached in the same entry", () async {
      await service.create(item: fresh(), changedCardIds: const ['header']);

      expect(
        await ServiceScheduleRepository().getSchedulesForEquipment('n1'),
        isNotEmpty,
      );
      expect(await operations(), hasLength(1));
    });

    test('held writes run after the row, in the same entry', () async {
      EquipmentItem? seen;
      await service.create(
        item: fresh(),
        changedCardIds: const ['header'],
        alsoWrite: () async => seen = await equipment.getEquipmentById('n1'),
      );

      expect(seen?.name, 'Backup reg');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          item: fresh(),
          changedCardIds: const ['header'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await equipment.getEquipmentById('n1'), isNull);
      expect(
        await ServiceScheduleRepository().getSchedulesForEquipment('n1'),
        isEmpty,
      );
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          item: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          item: fresh(id: 'g1'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );

      expect((await stored()).name, 'Apex');
      expect(await operations(), isEmpty);
    });
  });
}
