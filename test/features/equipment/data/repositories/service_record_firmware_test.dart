import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/test_database.dart';

/// Firmware updates in the service history (issue #5104): the record keeps
/// the version it installed, and a firmware update is not a service, so it
/// never moves the item's last service date.
void main() {
  late EquipmentRepository equipment;
  late ServiceRecordRepository records;
  final t0 = DateTime(2026, 11, 1);

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    records = ServiceRecordRepository();
    await equipment.createEquipment(
      const EquipmentItem(
        id: 'perdix',
        name: 'Perdix 2',
        type: EquipmentType.computer,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  ServiceRecord record(
    ServiceCategory category,
    DateTime day, {
    String? firmwareVersion,
  }) => ServiceRecord(
    id: '',
    equipmentId: 'perdix',
    serviceCategory: category,
    serviceDate: day,
    firmwareVersion: firmwareVersion,
    createdAt: t0,
    updatedAt: t0,
  );

  test('a firmware record keeps the version it installed', () async {
    final created = await records.createRecord(
      record(
        ServiceCategory.firmwareUpdate,
        DateTime(2026, 10, 1),
        firmwareVersion: 'V95',
      ),
    );

    final read = await records.getRecordById(created.id);
    expect(read!.serviceCategory, ServiceCategory.firmwareUpdate);
    expect(read.firmwareVersion, 'V95');

    await records.updateRecord(read.copyWith(firmwareVersion: 'V96'));
    expect((await records.getRecordById(created.id))!.firmwareVersion, 'V96');
  });

  test('copyWith can clear the version', () {
    final r = record(
      ServiceCategory.firmwareUpdate,
      t0,
      firmwareVersion: 'V95',
    );
    expect(r.copyWith(firmwareVersion: null).firmwareVersion, isNull);
    expect(r.copyWith(notes: 'x').firmwareVersion, 'V95');
  });

  test('a firmware record leaves the last service date alone', () async {
    await records.createRecord(
      record(ServiceCategory.annual, DateTime(2026, 3, 1)),
    );
    await records.createRecord(
      record(
        ServiceCategory.firmwareUpdate,
        DateTime(2026, 10, 1),
        firmwareVersion: 'V95',
      ),
    );

    final item = await equipment.getEquipmentById('perdix');
    expect(item!.lastServiceDate, DateTime(2026, 3, 1));
  });

  test('a category this build does not know reads as Other', () async {
    final created = await records.createRecord(
      record(ServiceCategory.annual, DateTime(2026, 3, 1)),
    );
    await DatabaseService.instance.database.customStatement(
      "UPDATE service_records SET service_category = 'futureThing' "
      'WHERE id = ?',
      [created.id],
    );

    final read = await records.getRecordById(created.id);
    expect(read!.serviceCategory, ServiceCategory.other);
  });
}
