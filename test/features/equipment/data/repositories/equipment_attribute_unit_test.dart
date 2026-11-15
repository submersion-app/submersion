import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// An equipment number's own unit (issue #4534) is saved with its row.
void main() {
  late EquipmentRepository repository;
  late String gaugeId;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
    gaugeId = (await repository.createEquipment(
      const EquipmentItem(id: '', name: 'SPG', type: EquipmentType.instrument),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  EquipmentAttribute range({double? bar, String? unit}) =>
      EquipmentAttribute.curated(
        equipmentId: gaugeId,
        key: 'gauge_max_pressure_bar',
        valueNum: bar,
        valueUnit: unit,
      );

  Future<EquipmentAttribute?> readRange() async =>
      (await repository.getAttributesForEquipment(
        gaugeId,
      )).where((a) => a.key == 'gauge_max_pressure_bar').firstOrNull;

  test('a unit is saved and read back with its value', () async {
    await repository.saveAttributes(gaugeId, [range(bar: 275.79, unit: 'psi')]);

    final saved = await readRange();
    expect(saved?.valueNum, 275.79);
    expect(saved?.valueUnit, 'psi');
  });

  test('a unit picked before any value is kept', () async {
    await repository.saveAttributes(gaugeId, [range(unit: 'psi')]);

    final saved = await readRange();
    expect(saved, isNotNull);
    expect(saved!.valueNum, isNull);
    expect(saved.valueUnit, 'psi');
  });

  test('changing only the unit is a change', () async {
    await repository.saveAttributes(gaugeId, [range(bar: 300, unit: 'bar')]);
    await repository.saveAttributes(gaugeId, [range(bar: 300, unit: 'psi')]);

    expect((await readRange())?.valueUnit, 'psi');
  });

  test('clearing the unit follows the diver again', () async {
    await repository.saveAttributes(gaugeId, [range(bar: 300, unit: 'psi')]);
    await repository.saveAttributes(gaugeId, [range(bar: 300)]);

    expect((await readRange())?.valueUnit, isNull);
  });

  test('a cylinder volume above the repair line is saved as litres', () async {
    final tankId = (await repository.createEquipment(
      const EquipmentItem(id: '', name: 'Bank', type: EquipmentType.tank),
    )).id;
    await repository.saveAttributes(tankId, [
      EquipmentAttribute.curated(
        equipmentId: tankId,
        key: EquipmentAttrKeys.volumeL,
        valueNum: 100,
      ),
    ]);

    final saved = (await repository.getAttributesForEquipment(tankId)).single;
    expect(saved.valueNum, 100);
    expect(saved.valueUnit, 'liters');
  });
}
