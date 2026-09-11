import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// A child inherits its parent's dives from its install date, or from its
/// creation when no install date is set (the design's attribute catalog).
///
/// Dives store wall-clock time as UTC (`dive_date_time`), while the install
/// date is a local calendar day (the date picker stores local midnight) and
/// the creation time a local instant. The anchor is re-expressed in the
/// dive frame; comparing raw instants shifted the boundary by the device's
/// UTC offset. These tests run in the machine's own zone, so off UTC they
/// catch the shift.
void main() {
  final created = DateTime.utc(2026, 3, 1);

  EquipmentItem cellInstalledAt(DateTime stored) => EquipmentItem(
    id: 'c',
    name: 'c',
    type: EquipmentType.o2Cell,
    createdAt: created,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'c',
        key: EquipmentAttrKeys.installedDate,
        valueNum: stored.millisecondsSinceEpoch.toDouble(),
      ),
    ],
  );

  test('the install date, as its calendar day in the dive frame', () {
    // What the date picker stores: local midnight of the chosen day.
    expect(
      cellInstalledAt(DateTime(2026, 1, 15)).parentDivesFrom,
      DateTime.utc(2026, 1, 15),
    );
  });

  test('an install date stored as a local instant keeps its local day', () {
    // What replacing a child stores: the moment of the replacement.
    expect(
      cellInstalledAt(DateTime(2026, 1, 15, 22, 30)).parentDivesFrom,
      DateTime.utc(2026, 1, 15),
    );
  });

  test('a local creation time is read as its wall clock', () {
    final cell = EquipmentItem(
      id: 'c',
      name: 'c',
      type: EquipmentType.o2Cell,
      createdAt: DateTime(2026, 3, 1, 9, 45),
    );
    expect(cell.parentDivesFrom, DateTime.utc(2026, 3, 1, 9, 45));
  });

  test('the install date when one is set', () {
    final installed = DateTime(2026, 1, 1);
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
    expect(
      cell.parentDivesFrom,
      DateTime.utc(installed.year, installed.month, installed.day),
    );
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
