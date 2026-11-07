import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4201: an item's last service date is its newest service record's
/// date, however the records were entered. Logging an older record, such as
/// one back-filled from paper, leaves it where it is.
void main() {
  late EquipmentRepository equipment;
  late ServiceRecordRepository records;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    records = ServiceRecordRepository();
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'reg',
        name: 'Regulator',
        type: EquipmentType.regulator,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<ServiceRecord> log(DateTime day) {
    final now = DateTime(2026, 11, 1);
    return records.createRecord(
      ServiceRecord(
        id: '',
        equipmentId: 'reg',
        serviceCategory: ServiceCategory.annual,
        serviceDate: day,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<DateTime?> lastService() async =>
      (await equipment.getEquipmentById('reg'))!.lastServiceDate;

  test('the first record sets the date', () async {
    await log(DateTime(2026, 3, 1));

    expect(await lastService(), DateTime(2026, 3, 1));
  });

  test('a newer record moves the date forward', () async {
    await log(DateTime(2025, 3, 1));
    await log(DateTime(2026, 3, 1));

    expect(await lastService(), DateTime(2026, 3, 1));
  });

  test('an older record leaves the newer date', () async {
    await log(DateTime(2026, 3, 1));
    await log(DateTime(2025, 3, 1));

    expect(await lastService(), DateTime(2026, 3, 1));
  });

  // A record that leaves the date leaves the item alone too, so back-filling
  // old records does not send an unchanged item to every peer.
  test('an older record leaves the item unwritten', () async {
    await log(DateTime(2026, 3, 1));
    final db = DatabaseService.instance.database;
    Future<int> stamp() async => (await (db.select(
      db.equipment,
    )..where((t) => t.id.equals('reg'))).getSingle()).updatedAt;
    final before = await stamp();

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await log(DateTime(2025, 3, 1));

    expect(await stamp(), before);
  });

  test('a delete falls back to the newest record left, then clears', () async {
    final newer = await log(DateTime(2026, 3, 1));
    final older = await log(DateTime(2025, 3, 1));

    await records.deleteRecord(newer.id);
    expect(await lastService(), DateTime(2025, 3, 1));

    await records.deleteRecord(older.id);
    expect(await lastService(), isNull);
  });
}
