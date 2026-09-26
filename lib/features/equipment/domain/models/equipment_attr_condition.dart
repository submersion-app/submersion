import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One condition on a curated equipment attribute (issue #1805).
///
/// Shared by the dive list filter, which lowers it to a query on the gear
/// relation (`DiveFilterQuery`, #2365), and the equipment list filter, which
/// evaluates it in memory through [matches]. Both follow the same rules:
///
/// - Only curated rows with [key] count; custom fields never match.
/// - A non-empty [types] requires the item's type to be one of them.
/// - A non-empty [choices] requires `value_text` to be one of them (OR).
/// - [min] and [max] bound `value_num` in canonical metric; a row with no
///   number fails a set bound.
/// - A condition with only a key means "has this attribute".
@immutable
class EquipmentAttrCondition {
  final String key;
  final Set<String> choices;
  final double? min;
  final double? max;
  final Set<EquipmentType> types;

  const EquipmentAttrCondition({
    required this.key,
    this.choices = const {},
    this.min,
    this.max,
    this.types = const {},
  });

  /// The exposure suits the Suit thickness filter covers. Hoods, gloves and
  /// boots carry `thickness_mm` too, but are not suits.
  static const Set<EquipmentType> suitTypes = {
    EquipmentType.wetsuit,
    EquipmentType.drysuit,
  };

  /// The dive filter's Suit thickness condition.
  factory EquipmentAttrCondition.suitThickness({double? min, double? max}) =>
      EquipmentAttrCondition(
        key: EquipmentAttrKeys.thicknessMm,
        min: min,
        max: max,
        types: suitTypes,
      );

  /// Whether this is the condition [EquipmentAttrCondition.suitThickness]
  /// builds, so the dive filter sheet can show it in its own section.
  bool get isSuitThickness =>
      key == EquipmentAttrKeys.thicknessMm &&
      choices.isEmpty &&
      setEquals(types, suitTypes);

  bool matches(EquipmentItem item) {
    if (types.isNotEmpty && !types.contains(item.type)) return false;
    final lo = min;
    final hi = max;
    return item.attributes.any((attr) {
      if (attr.isCustom || attr.key != key) return false;
      if (choices.isNotEmpty && !choices.contains(attr.valueText)) {
        return false;
      }
      final value = attr.valueNum;
      if (lo != null && (value == null || value < lo)) return false;
      if (hi != null && (value == null || value > hi)) return false;
      return true;
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentAttrCondition &&
          other.key == key &&
          setEquals(other.choices, choices) &&
          other.min == min &&
          other.max == max &&
          setEquals(other.types, types);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAllUnordered(choices),
    min,
    max,
    Object.hashAllUnordered(types),
  );

  @override
  String toString() =>
      'EquipmentAttrCondition(key: $key, choices: $choices, min: $min, '
      'max: $max, types: $types)';
}
