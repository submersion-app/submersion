import 'dart:convert';

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
///
/// [nestParts] (issue #5071) is read by the Equipment page alone: it folds
/// each assembly's parts under the assembly's row. Every other gear surface
/// ignores it.
///
/// Keys this build does not know are kept and written back, so an axis a
/// newer build adds survives this one saving the arrangement.
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

  /// Ascending means A to Z and oldest first, the same as the Equipment
  /// page's own sort, since both are edited through one sheet layout.
  final SortDirection itemSortDirection;

  /// Whether the Equipment page lists each assembly's parts under it rather
  /// than in their own type groups (issue #5071). On unless the diver turned
  /// it off.
  final bool nestParts;

  /// The stored keys this build does not know, written back untouched.
  final Map<String, Object?> _extras;

  const EquipmentArrangement({
    required this.typeOrder,
    this.typeOrderDescending = false,
    required this.groupByType,
    required this.itemSortField,
    required this.itemSortDirection,
    this.nestParts = true,
  }) : _extras = const {};

  const EquipmentArrangement._withExtras({
    required this.typeOrder,
    required this.typeOrderDescending,
    required this.groupByType,
    required this.itemSortField,
    required this.itemSortDirection,
    required this.nestParts,
    required Map<String, Object?> extras,
  }) : _extras = extras;

  static const _knownKeys = {
    'typeOrder',
    'typeOrderDescending',
    'groupByType',
    'itemSortField',
    'itemSortDirection',
    'nestParts',
  };

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
    bool? nestParts,
  }) {
    return EquipmentArrangement._withExtras(
      typeOrder: typeOrder ?? this.typeOrder,
      typeOrderDescending: typeOrderDescending ?? this.typeOrderDescending,
      groupByType: groupByType ?? this.groupByType,
      itemSortField: itemSortField ?? this.itemSortField,
      itemSortDirection: itemSortDirection ?? this.itemSortDirection,
      nestParts: nestParts ?? this.nestParts,
      extras: _extras,
    );
  }

  Map<String, dynamic> toJson() => {
    ..._extras,
    'typeOrder': typeOrder.name,
    'typeOrderDescending': typeOrderDescending,
    'groupByType': groupByType,
    'itemSortField': itemSortField.name,
    'itemSortDirection': itemSortDirection.name,
    'nestParts': nestParts,
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
    final rawNest = json['nestParts'];
    return EquipmentArrangement._withExtras(
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
      nestParts: rawNest is bool ? rawNest : defaults.nestParts,
      extras: Map.unmodifiable({
        for (final entry in json.entries)
          if (!_knownKeys.contains(entry.key)) entry.key: entry.value,
      }),
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
          other.itemSortDirection == itemSortDirection &&
          other.nestParts == nestParts &&
          mapEquals(other._extras, _extras);

  @override
  int get hashCode => Object.hash(
    typeOrder,
    typeOrderDescending,
    groupByType,
    itemSortField,
    itemSortDirection,
    nestParts,
  );

  @override
  String toString() =>
      'EquipmentArrangement(typeOrder: $typeOrder, '
      'typeOrderDescending: $typeOrderDescending, groupByType: $groupByType, '
      'itemSortField: $itemSortField, itemSortDirection: $itemSortDirection, '
      'nestParts: $nestParts)';
}

/// Encodes [arrangement] as the JSON a diver's settings row stores (issue
/// #3748), the same shape the app-wide key held.
String encodeEquipmentArrangement(EquipmentArrangement arrangement) =>
    jsonEncode(arrangement.toJson());

/// Decodes a value written by [encodeEquipmentArrangement]: null for a
/// missing value or anything that is not a JSON object, so the caller falls
/// back rather than throwing. Each axis degrades on its own, as in
/// [EquipmentArrangement.fromJson].
EquipmentArrangement? decodeEquipmentArrangement(String? raw) {
  if (raw == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  return EquipmentArrangement.fromJson(decoded);
}

/// The arrangement a diver sees (issue #3748): their own saved value, else
/// the app-wide one older builds saved, else [EquipmentArrangement.defaults].
///
/// [legacy] is asked only when [saved] holds nothing usable, so a diver with
/// their own arrangement never reads the app-wide value.
EquipmentArrangement pickEquipmentArrangement(
  String? saved,
  EquipmentArrangement? Function() legacy,
) =>
    decodeEquipmentArrangement(saved) ??
    legacy() ??
    EquipmentArrangement.defaults;
