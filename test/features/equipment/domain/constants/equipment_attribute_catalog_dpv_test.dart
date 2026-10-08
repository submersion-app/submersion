import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('DPV carries the two tow factors as plain numbers', () {
    final keys = EquipmentAttributeCatalog.attributesFor(
      EquipmentType.dpv,
    ).map((d) => d.key).toList();
    expect(keys, containsAll(['tow_speed_factor', 'tow_burn_factor']));
    for (final key in ['tow_speed_factor', 'tow_burn_factor']) {
      final def = EquipmentAttributeCatalog.defFor(key)!;
      expect(def.kind, AttributeKind.number, reason: key);
      expect(def.dimension, AttributeDimension.none, reason: key);
    }
  });

  test('the stable keys name the stored attribute keys', () {
    expect(EquipmentAttrKeys.dpvSpeedMps, 'speed_mps');
    expect(EquipmentAttrKeys.dpvBurnTimeH, 'burn_time_h');
    expect(EquipmentAttrKeys.dpvBatteryCapacityWh, 'battery_capacity_wh');
    expect(EquipmentAttrKeys.towSpeedFactor, 'tow_speed_factor');
    expect(EquipmentAttrKeys.towBurnFactor, 'tow_burn_factor');
  });

  test('typed getters read the curated rows and are null when absent', () {
    final item = EquipmentItem(
      id: 'dpv-1',
      name: 'Blacktip',
      type: EquipmentType.dpv,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'speed_mps',
          valueNum: 0.9,
        ),
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'burn_time_h',
          valueNum: 1.5,
        ),
        EquipmentAttribute.curated(
          equipmentId: 'dpv-1',
          key: 'tow_burn_factor',
          valueNum: 1.8,
        ),
      ],
    );
    expect(item.dpvSpeedMps, 0.9);
    expect(item.dpvBurnTimeHours, 1.5);
    expect(item.dpvTowBurnFactor, 1.8);
    expect(item.dpvBatteryCapacityWh, isNull);
    expect(item.dpvTowSpeedFactor, isNull);
  });
}
