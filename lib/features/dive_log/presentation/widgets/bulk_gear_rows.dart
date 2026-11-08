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
  final items = <BulkMembershipItem>[];
  final headings = <String, EquipmentType>{};
  for (final group in arrangeEquipment(
    gear,
    arrangement,
    typeLabel: typeLabel,
  )) {
    final type = group.type;
    if (type != null && group.items.isNotEmpty) {
      headings[group.items.first.id] = type;
    }
    for (final item in group.items) {
      items.add(
        BulkMembershipItem(
          id: item.id,
          label: item.name,
          icon: equipmentTypeIcon(item.type),
        ),
      );
    }
  }
  return BulkGearRows(items: items, headings: headings);
}
