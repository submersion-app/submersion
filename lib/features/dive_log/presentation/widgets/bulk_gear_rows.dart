import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// The bulk dive editor's gear rows, in the diver's gear arrangement.
@immutable
class BulkGearRows {
  const BulkGearRows({required this.items, required this.headings});

  /// One row per item, in display order.
  final List<BulkMembershipItem> items;

  /// The type heading that starts each group, keyed by the id of the group's
  /// first row. Empty when the arrangement does not group by type.
  final Map<String, EquipmentType> headings;
}

/// Orders [gear] for the bulk editor the way the single-dive gear list orders
/// a dive's gear (#2274): through the diver's [arrangement], which every gear
/// surface shares. Before this the bulk list was alphabetical only, with
/// newly added gear appended at the bottom.
///
/// [typeLabel] resolves a type to the string the reader sees, so an
/// alphabetical type order sorts by the localized names.
BulkGearRows arrangeBulkGearRows(
  List<EquipmentItem> gear,
  EquipmentArrangement arrangement, {
  required String Function(EquipmentType) typeLabel,
}) {
  final groups = arrangeEquipment(gear, arrangement, typeLabel: typeLabel);
  return BulkGearRows(
    items: [
      for (final group in groups)
        for (final item in group.items)
          BulkMembershipItem(
            id: item.id,
            label: item.name,
            icon: equipmentTypeIcon(item.type),
          ),
    ],
    headings: {
      for (final group in groups)
        if (group.type case final type? when group.items.isNotEmpty)
          group.items.first.id: type,
    },
  );
}

/// [gear] with each of [added] it does not already list, by id. Where the
/// new items go in the list does not matter: the editor renders it through
/// the arrangement, so they take their sorted place, not the bottom.
List<EquipmentItem> withBulkGear(
  List<EquipmentItem> gear,
  Iterable<EquipmentItem> added,
) => {
  for (final item in added) item.id: item,
  // Listed after the additions so an item already listed keeps its entry.
  for (final item in gear) item.id: item,
}.values.toList();
