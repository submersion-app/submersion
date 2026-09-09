import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';

/// How a gear list is grouped and ordered.
///
/// Three independent axes, because #1486 asks for the order of the types and
/// the order inside each type grouping to be chosen separately:
///
/// - [typeOrder] is the primary key. It orders the group headers when
///   [groupByType] is set, and orders the flat list when it is not.
/// - [groupByType] decides only whether headers render.
/// - [itemSortField] and [itemSortDirection] order items inside a group, or
///   the whole list when [typeOrder] is [EquipmentTypeOrder.none].
///
/// Splitting [typeOrder] from [groupByType] is what lets #1576's flat
/// head-to-toe list and #1486's grouped view share one model.
@immutable
class EquipmentArrangement {
  final EquipmentTypeOrder typeOrder;

  /// Reverses [typeOrder], which is how #1486's "toe to head" and #1576's
  /// "ascending and descending by Head to Toe" are expressed. Independent of
  /// [itemSortDirection] so reversing the headings does not also reverse the
  /// gear inside them.
  final bool typeOrderDescending;

  final bool groupByType;
  final EquipmentItemSortField itemSortField;

  /// Ascending means A to Z and oldest first.
  ///
  /// Note this diverges from `applyEquipmentSorting` on the Equipment page,
  /// which inverts direction for text fields so that "descending" reads as
  /// A to Z. That inversion is surprising and is not repeated here.
  final SortDirection itemSortDirection;

  const EquipmentArrangement({
    required this.typeOrder,
    this.typeOrderDescending = false,
    required this.groupByType,
    required this.itemSortField,
    required this.itemSortDirection,
  });

  /// Group by type, types alphabetical by localized name, items A to Z.
  ///
  /// Alphabetical rather than head-to-toe because it is the order that never
  /// surprises a diver hunting for one specific regulator, and because it is
  /// correct in every locale without a curated table.
  static const EquipmentArrangement defaults = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.alphabetical,
    typeOrderDescending: false,
    groupByType: true,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.ascending,
  );

  EquipmentArrangement copyWith({
    EquipmentTypeOrder? typeOrder,
    bool? typeOrderDescending,
    bool? groupByType,
    EquipmentItemSortField? itemSortField,
    SortDirection? itemSortDirection,
  }) {
    return EquipmentArrangement(
      typeOrder: typeOrder ?? this.typeOrder,
      typeOrderDescending: typeOrderDescending ?? this.typeOrderDescending,
      groupByType: groupByType ?? this.groupByType,
      itemSortField: itemSortField ?? this.itemSortField,
      itemSortDirection: itemSortDirection ?? this.itemSortDirection,
    );
  }

  Map<String, dynamic> toJson() => {
    'typeOrder': typeOrder.name,
    'typeOrderDescending': typeOrderDescending,
    'groupByType': groupByType,
    'itemSortField': itemSortField.name,
    'itemSortDirection': itemSortDirection.name,
  };

  /// Decodes a stored blob, falling back per axis.
  ///
  /// Every axis degrades independently so a value written by a newer build
  /// costs the diver that one axis rather than their whole arrangement.
  factory EquipmentArrangement.fromJson(Map<String, dynamic> json) {
    T decode<T extends Enum>(String key, List<T> values, T fallback) {
      final raw = json[key];
      if (raw is! String) return fallback;
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    final rawGroup = json['groupByType'];
    final rawTypeDesc = json['typeOrderDescending'];
    return EquipmentArrangement(
      typeOrder: decode(
        'typeOrder',
        EquipmentTypeOrder.values,
        defaults.typeOrder,
      ),
      typeOrderDescending: rawTypeDesc is bool
          ? rawTypeDesc
          : defaults.typeOrderDescending,
      groupByType: rawGroup is bool ? rawGroup : defaults.groupByType,
      itemSortField: decode(
        'itemSortField',
        EquipmentItemSortField.values,
        defaults.itemSortField,
      ),
      itemSortDirection: decode(
        'itemSortDirection',
        SortDirection.values,
        defaults.itemSortDirection,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentArrangement &&
          other.typeOrder == typeOrder &&
          other.typeOrderDescending == typeOrderDescending &&
          other.groupByType == groupByType &&
          other.itemSortField == itemSortField &&
          other.itemSortDirection == itemSortDirection;

  @override
  int get hashCode => Object.hash(
    typeOrder,
    typeOrderDescending,
    groupByType,
    itemSortField,
    itemSortDirection,
  );

  @override
  String toString() =>
      'EquipmentArrangement(typeOrder: $typeOrder, '
      'typeOrderDescending: $typeOrderDescending, groupByType: $groupByType, '
      'itemSortField: $itemSortField, itemSortDirection: $itemSortDirection)';
}
