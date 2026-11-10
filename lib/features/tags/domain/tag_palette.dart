import 'dart:ui';

import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The three shades the tag palette offers of each hue (issue #4384).
enum TagShade { light, base, dark }

/// One colour of the tag palette. [hue] indexes [TagColors.predefined].
typedef TagPaletteEntry = ({int hue, TagShade shade, String hex});

/// How a tag with no stored colour is drawn: the palette's own Blue, so it
/// matches a swatch the diver can pick rather than a near-miss Material blue.
const String tagDefaultColorHex = '#3B82F6';

/// The light shade of each [TagColors.predefined] hue, in the same order
/// (Tailwind 300; the base colours are its 500 step).
///
/// Kept apart from [TagColors.predefined] on purpose: agency colours pick
/// `predefined[hash % length]`, and the equipment palette and profile swatch
/// names are built on it, so growing that list would recolour and rename them.
const List<String> tagLightShades = [
  '#FCA5A5', // Red
  '#FDBA74', // Orange
  '#FCD34D', // Amber
  '#FDE047', // Yellow
  '#BEF264', // Lime
  '#86EFAC', // Green
  '#6EE7B7', // Emerald
  '#5EEAD4', // Teal
  '#67E8F9', // Cyan
  '#7DD3FC', // Sky
  '#93C5FD', // Blue
  '#A5B4FC', // Indigo
  '#C4B5FD', // Violet
  '#D8B4FE', // Purple
  '#F0ABFC', // Fuchsia
  '#F9A8D4', // Pink
  '#FDA4AF', // Rose
  '#D6D3D1', // Stone
  '#D4D4D8', // Zinc
  '#CBD5E1', // Slate
];

/// The dark shade of each [TagColors.predefined] hue (Tailwind 700).
const List<String> tagDarkShades = [
  '#B91C1C', // Red
  '#C2410C', // Orange
  '#B45309', // Amber
  '#A16207', // Yellow
  '#4D7C0F', // Lime
  '#15803D', // Green
  '#047857', // Emerald
  '#0F766E', // Teal
  '#0E7490', // Cyan
  '#0369A1', // Sky
  '#1D4ED8', // Blue
  '#4338CA', // Indigo
  '#6D28D9', // Violet
  '#7E22CE', // Purple
  '#A21CAF', // Fuchsia
  '#BE185D', // Pink
  '#BE123C', // Rose
  '#44403C', // Stone
  '#3F3F46', // Zinc
  '#334155', // Slate
];

/// Every palette colour: light, base and dark for each hue in turn.
final List<TagPaletteEntry> tagPalette = List.unmodifiable([
  for (var hue = 0; hue < TagColors.predefined.length; hue++) ...[
    (hue: hue, shade: TagShade.light, hex: tagLightShades[hue]),
    (hue: hue, shade: TagShade.base, hex: TagColors.predefined[hue]),
    (hue: hue, shade: TagShade.dark, hex: tagDarkShades[hue]),
  ],
]);

/// [stored] read the lenient way tags always have been, or null when it
/// cannot be read at all.
///
/// Imports store a UDDF `<color>` unchecked, so a tag can hold `FF0000`
/// without its hash, or an eight-digit code. Whatever drew as a colour
/// before keeps drawing as that colour.
Color? parseStoredTagColor(String? stored) {
  if (stored == null || stored.isEmpty) return null;
  try {
    final hex = stored.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  } on FormatException {
    return null;
  }
}

/// The colour a tag storing [stored] is drawn in.
Color drawnTagColor(String? stored) =>
    parseStoredTagColor(stored) ?? TagColors.fromHex(tagDefaultColorHex);

/// [color] as `#RRGGBB` in capitals. Alpha is dropped: a tag colour is
/// always opaque.
String tagHexOf(Color color) {
  String channel(double c) =>
      (c * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'
      .toUpperCase();
}

/// The palette colour a tag storing [stored] is drawn as, or null when it
/// is drawn in a colour off the palette.
///
/// A translucent colour (an imported eight-digit code) is off the palette
/// whatever its RGB: it is drawn see-through, so no opaque swatch is the
/// colour the diver sees. A missing or unreadable value is drawn as the
/// opaque fallback Blue and still matches it.
TagPaletteEntry? tagPaletteEntryFor(String? stored) {
  final drawn = drawnTagColor(stored);
  if (drawn.a < 1) return null;
  final hex = tagHexOf(drawn);
  for (final entry in tagPalette) {
    if (entry.hex == hex) return entry;
  }
  return null;
}

final RegExp _hexInput = RegExp(r'^#?[0-9A-Fa-f]{6}$');

/// A colour code the diver typed, as `#RRGGBB` in capitals, or null when it
/// is not six hex digits (an optional leading `#` and surrounding space are
/// allowed). The pattern is checked before any parse, since `int.parse`
/// would accept a sign.
String? parseTagHexInput(String text) {
  final trimmed = text.trim();
  if (!_hexInput.hasMatch(trimmed)) return null;
  return '#${trimmed.replaceFirst('#', '').toUpperCase()}';
}
