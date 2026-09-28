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
