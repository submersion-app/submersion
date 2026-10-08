import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_drafts.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1);

  TripCylinder slot(int order) => TripCylinder(
    id: 'c$order',
    tripId: 't1',
    sortOrder: order,
    createdAt: now,
    updatedAt: now,
  );

  test('the next sort order follows the highest, gaps included', () {
    expect(nextTripCylinderSortOrder(const []), 0);
    expect(nextTripCylinderSortOrder([slot(0), slot(4)]), 5);
  });

  test('an owned cylinder becomes a linked slot labelled by its mark', () {
    final item = EquipmentItem(
      id: 'e1',
      name: 'Faber 12',
      type: EquipmentType.tank,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: EquipmentAttrKeys.identifier,
          valueText: 'S/N 4411',
        ),
      ],
    );
    final draft = tripCylinderDraftFromEquipment(
      item,
      tripId: 't1',
      sortOrder: 3,
      now: now,
    );
    expect(draft.equipmentId, 'e1');
    expect(draft.label, 'S/N 4411');
    expect(draft.sortOrder, 3);
    expect(draft.tripId, 't1');
  });

  test('with no mark the slot takes the item name', () {
    const item = EquipmentItem(
      id: 'e1',
      name: 'Faber 12',
      type: EquipmentType.tank,
    );
    expect(
      tripCylinderDraftFromEquipment(
        item,
        tripId: 't1',
        sortOrder: 0,
        now: now,
      ).label,
      'Faber 12',
    );
  });
}
