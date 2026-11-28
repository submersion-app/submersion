import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/last_service_date_repair.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../helpers/test_database.dart';

/// The last service date repair that runs after every inbound sync apply
/// (#4201) never counts a firmware update as a service (issue #5104).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  test(
    'a synced firmware record does not make the item look serviced',
    () async {
      final equipment = EquipmentRepository();
      final records = ServiceRecordRepository();
      await equipment.createEquipment(
        const EquipmentItem(
          id: 'dc',
          name: 'Perdix 2',
          type: EquipmentType.computer,
        ),
      );
      final t = DateTime(2026, 11, 1);
      for (final (category, day) in [
        (ServiceCategory.annual, DateTime(2026, 3, 1)),
        (ServiceCategory.firmwareUpdate, DateTime(2026, 10, 1)),
      ]) {
        await records.createRecord(
          ServiceRecord(
            id: '',
            equipmentId: 'dc',
            serviceCategory: category,
            serviceDate: day,
            firmwareVersion: category == ServiceCategory.firmwareUpdate
                ? 'V95'
                : null,
            createdAt: t,
            updatedAt: t,
          ),
        );
      }
      final db = DatabaseService.instance.database;
      // As a peer below the repair would leave it.
      await db.customStatement(
        "UPDATE equipment SET last_service_date = NULL WHERE id = 'dc'",
      );

      await repairLastServiceDates(db);

      expect(
        (await equipment.getEquipmentById('dc'))!.lastServiceDate,
        DateTime(2026, 3, 1),
      );
    },
  );
}
