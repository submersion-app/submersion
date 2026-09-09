import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

EquipmentItem _tank(List<EquipmentAttribute> attrs) => EquipmentItem(
  id: 'g1',
  name: 'AL80',
  type: EquipmentType.tank,
  attributes: attrs,
);

EquipmentAttribute _attr(String key, {String? text, double? num}) =>
    EquipmentAttribute(
      id: 'a-$key',
      equipmentId: 'g1',
      key: key,
      valueText: text,
      valueNum: num,
    );

void main() {
  test('reads volume, working pressure and material from attributes', () {
    final item = _tank([
      _attr(EquipmentAttrKeys.volumeL, num: 11.1),
      _attr(EquipmentAttrKeys.workingPressureBar, num: 207),
      _attr(EquipmentAttrKeys.tankMaterial, text: 'carbon_composite'),
    ]);

    expect(item.volumeL, 11.1);
    expect(item.workingPressureBar, 207);
    expect(item.tankMaterial, TankMaterial.carbonFiber);
  });

  test('missing attributes read as null', () {
    final item = _tank(const []);
    expect(item.volumeL, isNull);
    expect(item.workingPressureBar, isNull);
    expect(item.tankMaterial, isNull);
  });
}
