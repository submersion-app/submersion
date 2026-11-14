import 'package:flutter/painting.dart';

/// [color] as `#RRGGBB` in capitals. Alpha is dropped: the custom colour
/// dialog picks opaque colours only (issues #4384 and #4537).
String colorHexOf(Color color) {
  String channel(double c) =>
      (c * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'
      .toUpperCase();
}

/// The opaque colour a `#RRGGBB` [code] names. [code] must already be a
/// valid code (from [parseColorHexInput] or a normaliser).
Color colorFromHex(String code) =>
    Color(int.parse(code.substring(1), radix: 16) | 0xFF000000);

final RegExp _hexInput = RegExp(r'^#?[0-9A-Fa-f]{6}$');

/// A colour code the diver typed, as `#RRGGBB` in capitals, or null when it
/// is not six hex digits (an optional leading `#` and surrounding space are
/// allowed). The pattern is checked before any parse, since `int.parse`
/// would accept a sign.
String? parseColorHexInput(String text) {
  final trimmed = text.trim();
  if (!_hexInput.hasMatch(trimmed)) return null;
  return '#${trimmed.replaceFirst('#', '').toUpperCase()}';
}
