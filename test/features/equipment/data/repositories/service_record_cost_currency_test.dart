import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/test_database.dart';

/// Exercises the raw GROUP BY in getTotalServiceCostByCurrency against a real
/// database -- the widget tests above it only ever see a stubbed provider.
void main() {
  late ServiceRecordRepository records;
  late EquipmentRepository equipment;
  late String equipmentId;

  setUp(() async {
    await setUpTestDatabase();
    records = ServiceRecordRepository();
    equipment = EquipmentRepository();
    final item = await equipment.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Primary Reg',
        type: EquipmentType.regulator,
      ),
    );
    equipmentId = item.id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> addRecord({double? cost, String currency = 'USD'}) async {
    final now = DateTime.now();
    await records.createRecord(
      ServiceRecord(
        id: '',
        equipmentId: equipmentId,
        serviceCategory: ServiceCategory.annual,
        serviceDate: now,
        cost: cost,
        currency: currency,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('no records yields no totals', () async {
    expect(await records.getTotalServiceCostByCurrency(equipmentId), isEmpty);
  });

  test('records sharing a currency sum into one entry', () async {
    await addRecord(cost: 100, currency: 'EUR');
    await addRecord(cost: 25.5, currency: 'EUR');

    expect(await records.getTotalServiceCostByCurrency(equipmentId), {
      'EUR': 125.5,
    });
  });

  test('different currencies stay in separate entries', () async {
    await addRecord(cost: 100, currency: 'EUR');
    await addRecord(cost: 900, currency: 'USD');

    final totals = await records.getTotalServiceCostByCurrency(equipmentId);
    expect(totals, {'EUR': 100.0, 'USD': 900.0});
    // The bug this replaced: one combined 1000 under a single symbol.
    expect(totals.values.length, 2);
  });

  test('records with no cost are excluded entirely', () async {
    await addRecord(cost: null, currency: 'EUR');
    await addRecord(cost: 40, currency: 'USD');

    expect(await records.getTotalServiceCostByCurrency(equipmentId), {
      'USD': 40.0,
    });
  });

  test('the totals are scoped to the requested equipment', () async {
    await addRecord(cost: 100, currency: 'EUR');
    final other = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Octo', type: EquipmentType.regulator),
    );
    final now = DateTime.now();
    await records.createRecord(
      ServiceRecord(
        id: '',
        equipmentId: other.id,
        serviceCategory: ServiceCategory.annual,
        serviceDate: now,
        cost: 500,
        currency: 'EUR',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(await records.getTotalServiceCostByCurrency(equipmentId), {
      'EUR': 100.0,
    });
    expect(await records.getTotalServiceCostByCurrency(other.id), {
      'EUR': 500.0,
    });
  });
}
