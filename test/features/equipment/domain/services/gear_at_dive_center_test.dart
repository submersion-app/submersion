import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/gear_at_dive_center.dart';

void main() {
  EquipmentLocation place(String id, {String? center, bool archived = false}) =>
      EquipmentLocation(
        id: id,
        name: id,
        kind: EquipmentLocationKind.diveCenter,
        diveCenterId: center,
        isArchived: archived,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: id, type: EquipmentType.bcd);

  test('lists items whose current place links to the center, by name', () {
    final reef = place('reef', center: 'c');
    final rows = gearAtDiveCenter(
      'c',
      [item('Zeta'), item('Alpha')],
      {'Zeta': reef, 'Alpha': reef},
    );
    expect([for (final r in rows) r.item.id], ['Alpha', 'Zeta']);
    expect(rows.first.place, reef);
  });

  test('leaves out items at unlinked places and other centers', () {
    final rows = gearAtDiveCenter(
      'c',
      [item('a'), item('b'), item('none')],
      {'a': place('typed'), 'b': place('bay', center: 'other')},
    );
    expect(rows, isEmpty);
  });

  test('includes items at an archived place', () {
    final rows = gearAtDiveCenter(
      'c',
      [item('a')],
      {'a': place('old', center: 'c', archived: true)},
    );
    expect([for (final r in rows) r.item.id], ['a']);
  });
}
