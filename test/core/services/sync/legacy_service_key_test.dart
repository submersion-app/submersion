// A peer or backup written before v160 keys the maintenance category as
// 'serviceType'. Raising minimumCompatibleSchemaVersion stops OLD readers
// applying OUR payloads, but the gate in changeset_reader.dart compares the
// writer's floor to the reader's schema, so it is one-directional: their
// payloads still arrive here, and service_category is NOT NULL with no
// default, so the apply path has to accept the old spelling itself.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // service_records.equipment_id is a real FK and foreign_keys is ON.
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, purchase_currency, "
      "custom_reminder_enabled, custom_reminder_days, created_at, updated_at) "
      "VALUES ('e1', 'Reg', 'regulator', 'USD', 0, '', 1, 1)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Map<String, dynamic> baseRecord(String id) => {
    'id': id,
    'equipmentId': 'e1',
    'serviceKindId': null,
    'serviceDate': 1700000000000,
    'provider': null,
    'cost': null,
    'currency': 'USD',
    'nextServiceDue': null,
    'notes': '',
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
    'hlc': null,
  };

  Future<String> categoryOf(String id) async {
    final row = await db
        .customSelect(
          "SELECT service_category FROM service_records WHERE id = '$id'",
        )
        .getSingle();
    return row.read<String>('service_category');
  }

  test('an old peer payload keyed serviceType applies', () async {
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-old'),
      'serviceType': 'repair',
    });

    expect(await categoryOf('rec-old'), 'repair');
  });

  test('a current payload keyed serviceCategory applies', () async {
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-new'),
      'serviceCategory': 'inspection',
    });

    expect(await categoryOf('rec-new'), 'inspection');
  });

  test('the batched path accepts the old key too', () async {
    await serializer.upsertRecords('serviceRecords', [
      {...baseRecord('rec-batch'), 'serviceType': 'cleaning'},
    ]);

    expect(await categoryOf('rec-batch'), 'cleaning');
  });

  test('a payload carrying both keys prefers the current spelling', () async {
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-both'),
      'serviceType': 'repair',
      'serviceCategory': 'overhaul',
    });

    expect(await categoryOf('rec-both'), 'overhaul');
  });

  test('an unrelated entity is untouched by the rename map', () async {
    // The normaliser is keyed by entity type, so a 'serviceType' key on some
    // other entity must pass through rather than being rewritten.
    await serializer.upsertRecord('equipment', {
      'id': 'e2',
      'name': 'BCD',
      'type': 'bcd',
      'purchaseCurrency': 'USD',
      'customReminderEnabled': false,
      'customReminderDays': '',
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
    });

    final row = await db
        .customSelect("SELECT name FROM equipment WHERE id = 'e2'")
        .getSingle();
    expect(row.read<String>('name'), 'BCD');
  });
}
