import 'dart:convert';

import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';

/// How many custom colours a diver's settings remember (issue #4537).
const int rememberedEquipmentColorCap = 8;

/// [code] normalised, or null when it is not a colour code or is one of the
/// palette's quick swatches (never offered twice).
String? _customCode(Object? code) {
  final normal = code is String ? normalizeEquipmentColor(code) : null;
  if (normal == null || equipmentColorPalette.contains(normal)) return null;
  return normal;
}

/// [codes] as custom codes: normalised, palette colours and non-codes
/// dropped, first occurrence kept, at most [cap].
List<String> distinctCustomEquipmentColors(Iterable<Object?> codes, int cap) {
  final seen = <String>{};
  final out = <String>[];
  for (final code in codes) {
    final normal = _customCode(code);
    if (normal == null || !seen.add(normal)) continue;
    out.add(normal);
    if (out.length == cap) break;
  }
  return out;
}

/// The remembered colours stored as [json] (issue #4537), most recent first.
/// Any peer can write the column, so this never throws: null, malformed
/// JSON and anything that is not a list read as none, and only the valid
/// custom codes of a list are kept.
List<String> decodeRecentEquipmentColors(String? json) {
  if (json == null || json.isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  return distinctCustomEquipmentColors(decoded, rememberedEquipmentColorCap);
}

/// [codes] as the column stores them.
String encodeRecentEquipmentColors(List<String> codes) => jsonEncode(codes);

/// [current] with [hex] remembered: first, its earlier copy removed, capped
/// at [rememberedEquipmentColorCap]. A palette colour or an invalid code
/// leaves [current] as it is.
List<String> rememberEquipmentColor(List<String> current, String hex) {
  final code = _customCode(hex);
  if (code == null) return current;
  return distinctCustomEquipmentColors([
    code,
    ...current,
  ], rememberedEquipmentColorCap);
}

/// How many colours the colour sheet's Recent row holds.
const int recentEquipmentColorRowCap = 12;

/// The colour sheet's Recent row (issue #4537): the item's [current] colour
/// when it is off the palette (so opening the sheet never hides it), then
/// the diver's [remembered] colours, then the colours on their [gear].
/// Normalised, each once, palette colours left to the presets, at most
/// [recentEquipmentColorRowCap].
List<String> recentEquipmentColorRow({
  String? current,
  required List<String> remembered,
  required List<String> gear,
}) => distinctCustomEquipmentColors([
  current,
  ...remembered,
  ...gear,
], recentEquipmentColorRowCap);
