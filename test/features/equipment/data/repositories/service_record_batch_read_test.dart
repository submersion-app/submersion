import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/batched_read_expectations.dart';
import '../../../../helpers/export_logbook_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1867: the UDDF and maintenance log exports read every item's
/// service history in one statement instead of one per item.
void main() {
  tearDown(tearDownTestDatabase);

  group('ServiceRecordRepository.getRecordsForEquipmentIds', () {
    batchedReadTests(
      seed: () async => [
        for (final item in await seedExportLogbook(diveCount: 1, itemCount: 3))
          item.id,
      ],
      batched: (ids) =>
          ServiceRecordRepository().getRecordsForEquipmentIds(ids),
      single: (id) => ServiceRecordRepository().getRecordsForEquipment(id),
      holdsNothing: (records) => records.isEmpty,
    );
  });

  // Records on the same day tie on service_date, so without a tie-break
  // their order is the query plan's: idx_service_records_kind yields no kind
  // first, a scan yields insertion order, and SQLite chooses from the
  // statistics ANALYZE leaves at startup. On this small table both reads
  // scan once analyzed, so the kinded record, inserted first, came first.
  test('orders records on the same day by kind on both reads', () async {
    final db = await setUpTestDatabase();
    final equipment = EquipmentRepository();
    final records = ServiceRecordRepository();
    final ids = <String>[];
    for (var i = 0; i < 40; i++) {
      final item = await equipment.createEquipment(
        EquipmentItem(id: 'item-$i', name: 'Item $i', type: EquipmentType.bcd),
      );
      ids.add(item.id);
    }
    final now = DateTime(2026, 1, 1);
    for (final kind in ['kind-annual', null]) {
      await records.createRecord(
        ServiceRecord(
          id: '',
          equipmentId: 'item-0',
          serviceCategory: ServiceCategory.annual,
          serviceKindId: kind,
          serviceDate: DateTime(2025, 6, 1),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.customStatement('ANALYZE');

    final perItem = await records.getRecordsForEquipment('item-0');
    expect(perItem.map((r) => r.serviceKindId), [null, 'kind-annual']);
    final batched = await records.getRecordsForEquipmentIds(ids);
    expect(batched['item-0'], perItem);
  });
}
