import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// An item's colour is stored as `#RRGGBB` in the `color` attribute's
/// `valueText` (issue #2326). Values reach it from the colour sheet, CSV
/// import, and sync, so every reader goes through this one check.
final RegExp _colorCode = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// [value] trimmed and uppercased when it is a `#RRGGBB` code, else null.
/// The pattern is checked before any parse, because `int.tryParse` accepts
/// a sign and would turn `#-00001` into a colour.
String? normalizeEquipmentColor(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || !_colorCode.hasMatch(trimmed)) return null;
  return trimmed.toUpperCase();
}

/// [attributes] as an item of [type] holds them (issue #2520).
///
/// A type without a colour (an O2 cell, a battery, Other) has no field for
/// one, so a curated colour that reached it (from a CSV file, say) is the
/// diver's own custom field named "color" instead: shown as one and kept by
/// the edit form's save, which drops curated keys the type does not have.
/// It moves after the diver's custom fields with an empty id, so the save
/// gives it a custom field's id. A custom field of the same name already on
/// the item wins, as the form's de-duplication would decide.
List<EquipmentAttribute> keepStrayColorAsCustom(
  EquipmentType type,
  List<EquipmentAttribute> attributes,
) {
  if (EquipmentAttributeCatalog.hasColor(type)) return attributes;
  final stray = attributes
      .where((a) => !a.isCustom && a.key == EquipmentAttrKeys.color)
      .firstOrNull;
  if (stray == null) return attributes;
  final custom = attributes.where((a) => a.isCustom);
  final rest = [
    for (final a in attributes)
      if (a != stray) a,
  ];
  if (custom.any((a) => a.key.trim() == stray.key)) return rest;
  final nextOrder = custom.fold(
    0,
    (next, a) => a.sortOrder >= next ? a.sortOrder + 1 : next,
  );
  return [
    ...rest,
    stray.copyWith(id: '', isCustom: true, sortOrder: nextOrder),
  ];
}
