import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/services/attribute_service_baselines.dart';

/// Issue #3662: the tank form's last visual inspection and last hydro dates
/// are where the VIP and hydro clocks count from.
void main() {
  final hydroDate = DateTime(2026, 10, 1);
  final vipDate = DateTime(2026, 9, 15);

  EquipmentAttribute dateAttr(String key, DateTime date) =>
      EquipmentAttribute.curated(
        equipmentId: 'e1',
        key: key,
        valueNum: date.millisecondsSinceEpoch.toDouble(),
      );

  test('maps each date to the clock it records', () {
    expect(
      attributeServiceBaselines(
        current: [
          dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate),
          dateAttr(EquipmentAttrKeys.lastVisualInspection, vipDate),
        ],
      ),
      {'hydro': hydroDate, 'vip': vipDate},
    );
  });

  test('ignores other attributes and dates left blank', () {
    expect(
      attributeServiceBaselines(
        current: [
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: EquipmentAttrKeys.volumeL,
            valueNum: 11.1,
          ),
        ],
      ),
      isEmpty,
    );
  });

  test('a custom field that happens to share the key sets nothing', () {
    expect(
      attributeServiceBaselines(
        current: [
          EquipmentAttribute(
            id: 'c1',
            equipmentId: 'e1',
            key: EquipmentAttrKeys.lastHydroTest,
            isCustom: true,
            valueNum: hydroDate.millisecondsSinceEpoch.toDouble(),
          ),
        ],
      ),
      isEmpty,
    );
  });

  test('a date unchanged since the last save sets nothing', () {
    final hydro = dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate);
    expect(
      attributeServiceBaselines(current: [hydro], previous: [hydro]),
      isEmpty,
    );
  });

  test('a changed date sets only its own clock', () {
    final vip = dateAttr(EquipmentAttrKeys.lastVisualInspection, vipDate);
    expect(
      attributeServiceBaselines(
        current: [
          dateAttr(EquipmentAttrKeys.lastHydroTest, DateTime(2026, 10, 20)),
          vip,
        ],
        previous: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate), vip],
      ),
      {'hydro': DateTime(2026, 10, 20)},
    );
  });

  test('a cleared date sets nothing', () {
    expect(
      attributeServiceBaselines(
        current: const [],
        previous: [dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate)],
      ),
      isEmpty,
    );
  });

  group('clearedServiceBaselines', () {
    test('names each cleared date with the date it held', () {
      expect(
        clearedServiceBaselines(
          current: const [],
          previous: [
            dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate),
            dateAttr(EquipmentAttrKeys.lastVisualInspection, vipDate),
          ],
        ),
        {'hydro': hydroDate, 'vip': vipDate},
      );
    });

    test('a date kept or changed is not cleared', () {
      expect(
        clearedServiceBaselines(
          current: [
            dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate),
            dateAttr(EquipmentAttrKeys.lastVisualInspection, DateTime(2026)),
          ],
          previous: [
            dateAttr(EquipmentAttrKeys.lastHydroTest, hydroDate),
            dateAttr(EquipmentAttrKeys.lastVisualInspection, vipDate),
          ],
        ),
        isEmpty,
      );
    });

    test('a date that was never there is not cleared', () {
      expect(
        clearedServiceBaselines(current: const [], previous: const []),
        isEmpty,
      );
    });
  });
}
