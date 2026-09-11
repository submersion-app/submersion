import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// A child inherits its parent's dives from its install date, or from its
/// creation when no install date is set (the design's attribute catalog).
void main() {
  final created = DateTime.utc(2026, 3, 1);

  test('the install date when one is set', () {
    final installed = DateTime.utc(2026, 1, 1);
    final cell = EquipmentItem(
      id: 'c',
      name: 'c',
      type: EquipmentType.o2Cell,
      createdAt: created,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'c',
          key: EquipmentAttrKeys.installedDate,
          valueNum: installed.millisecondsSinceEpoch.toDouble(),
        ),
      ],
    );
    expect(cell.parentDivesFrom!.isAtSameMomentAs(installed), isTrue);
  });

  test('the creation date when none is set', () {
    // Without it the item would inherit every dive its parent ever made,
    // including those from before it existed.
    final cell = EquipmentItem(
      id: 'c',
      name: 'c',
      type: EquipmentType.o2Cell,
      createdAt: created,
    );
    expect(cell.parentDivesFrom, created);
  });
}
